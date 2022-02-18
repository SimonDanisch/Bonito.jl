import { deserialize } from "./Protocol.js";
import { process_message, send_error } from "./Connection.js";

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

function free_object(id) {
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
    console.log(session_id)
    console.log(SESSIONS);
    const { session_cache } = SESSIONS[session_id];

    Object.keys(new_session_cache).forEach((key) => {
        const data_unserialized = new_session_cache[key];
        if (data_unserialized) {
            // if data is an object, we shouldn't have it in the cache yet, since otherwise we wouldn't sent it again
            const new_data = deserialize(message_cache, data_unserialized);
            GLOBAL_SESSION_CACHE[key] = [new_data, 1];
        } else {
            // data already cached, we just need to increment the refcount
            const [data, refcount] = GLOBAL_SESSION_CACHE[key];
            GLOBAL_SESSION_CACHE[key] = [data, refcount + 1];
            // keep track of usage in session cache
            session_cache.push(key);
        }
    });
    return;
}

export async function deserialize_cached(message) {
    const { session_id, session_cache, message_cache, data } = message;

    update_session_cache(session_id, session_cache, message_cache);

    return deserialize(message_cache, data);
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

export function init_session(session) {
    const { session_id, all_messages } = session;
    console.log(all_messages);
    console.log(session_id);
    track_deleted_sessions();
    SESSIONS[session_id] = { session_cache: new Set() };
    // send_session_ready(session_id);
    // process_message(all_messages);
    const root_node = document.getElementById(session_id);
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
    delete SESSIONS[id];
    send_session_close(session_id);
    return;
}
