import { deserialize } from "./Protocol.js";
import { process_message, register_init_messages, send_error } from "./Connection.js";

const SESSIONS = {};
// session global cache with refcounting
// contains {id: [data, refcount]}
const GLOBAL_SESSION_CACHE = {};

export function lookup_globally(id) {
    const object = GLOBAL_SESSION_CACHE[id];
    if (!object) {
        send_error(`Could not find ${id} in global cache.`);
    }
    return object[0];
}

window.GLOBAL_SESSION_CACHE = GLOBAL_SESSION_CACHE

export {
    GLOBAL_SESSION_CACHE
}

function free_object(id) {
    console.log(`freeing ${id}`)
    const object = GLOBAL_SESSION_CACHE[id];
    if (object) {
        const [data, refcount] = object;
        const new_refcount = refcount - 1;
        if (new_refcount === 0) {
            delete GLOBAL_SESSION_CACHE[id];
        } else {
            GLOBAL_SESSION_CACHE[id] = [data, new_refcount];
        }
    } else {
        send_warning(
            `Trying to delete object ${id}, which is not in global session cache.`
        );
    }
    return;
}

function update_session_cache(session_id, new_session_cache, message_cache) {
    const { session_cache } = SESSIONS[session_id];
    new_session_cache.forEach(([key, data_unserialized]) => {
        if (data_unserialized != null) {
            // if data is an object, we shouldn't have it in the cache yet, since otherwise we wouldn't sent it again
            const new_data = deserialize(message_cache, data_unserialized);
            GLOBAL_SESSION_CACHE[key] = [new_data, 1];
        } else {
            // data already cached, we just need to increment the refcount
            const obj = GLOBAL_SESSION_CACHE[key];
            if (obj) {
                GLOBAL_SESSION_CACHE[key] = [obj[0], obj[1] + 1];
                // keep track of usage in session cache
                session_cache.push(key);
            } else {
                console.log(`${key} is undefined what??`)
            }
        }
    });
    return;
}

export function deserialize_cached(message) {
    const { session_id, session_cache, data } = message;
    // update_session_cache(session_id, session_cache);
    const cache = deserialize({}, session_cache)
    return deserialize(cache, data)
}

let DELETE_OBSERVER = undefined;

export function track_deleted_sessions() {
    if (!DELETE_OBSERVER) {
        const observer = new MutationObserver(function (mutations) {
            // observe the dom for deleted nodes,
            // and push all found removed session doms to the observable `delete_session`
            let removal_occured = false;
            const to_delete = new Set();
            mutations.forEach((mutation) => {
                mutation.removedNodes.forEach((x) => {
                    if (x.id && x.id in SESSIONS) {
                        to_delete.add(x.id);
                    } else {
                        removal_occured = true;
                    }
                });
            });
            // removal occured from elements not matching the id!
            if (removal_occured) {
                Object.keys(SESSIONS).forEach((id) => {
                    if (!document.getElementById(id)) {
                        to_delete.add(id);
                    }
                });
            }
            to_delete.forEach((id) => {
                close_session(id);
            });
        });

        observer.observe(document, {
            attributes: false,
            childList: true,
            characterData: false,
            subtree: true,
        });
        DELETE_OBSERVER = observer;
    }
}

export function init_session(session_id, on_done_init) {
    console.log("init session")
    register_init_messages(on_done_init);
    track_deleted_sessions();
    SESSIONS[session_id] = { session_cache: new Set() };
    // send_session_ready(session_id);
    const root_node = document.getElementById(session_id);
    console.log("making visiiii")
    if (root_node) {
        root_node.style.visibility = "visible";
    }
}

export function close_session(session_id) {
    const { session_cache } = SESSIONS[session_id];
    const root_node = document.getElementById(session_id);
    if (root_node) {
        root_node.style.display = "none";
        root_node.parentNode.removeChild(root_node);
    }

    while (session_cache.length > 0) {
        free_object(session_cache.pop());
    }
    delete SESSIONS[session_id];
    send_session_close(session_id);
    return;
}
