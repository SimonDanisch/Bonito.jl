import { deserialize } from "./Protocol.js";
import { register_on_connection_open, send_error } from "./Connection.js";

const SESSIONS = {};
// global object cache with refcounting
// contains {id: [data, refcount]}
// Right now, should only contain Observables + Assets
const GLOBAL_OBJECT_CACHE = {};

export function lookup_observable(id) {
    const object = GLOBAL_OBJECT_CACHE[id];
    if (!object) {
        send_error(`Could not find ${id} in global cache.`);
    }
    return object[0];
}

function free_object(id) {
    console.log(`freeing ${id}`)
    const object = GLOBAL_OBJECT_CACHE[id];
    if (object) {
        const [data, refcount] = object;
        const new_refcount = refcount - 1;
        if (new_refcount === 0) {
            delete GLOBAL_OBJECT_CACHE[id];
        } else {
            GLOBAL_OBJECT_CACHE[id] = [data, new_refcount];
        }
    } else {
        send_warning(
            `Trying to delete object ${id}, which is not in global session cache.`
        );
    }
    return;
}

function update_session_cache(session_id, new_session_cache) {
    const session_cache = SESSIONS[session_id]
    const cache = deserialize(GLOBAL_OBJECT_CACHE, new_session_cache)
    Object.keys(cache).forEach(key => {
        // object can be nothing, which mean we already have it in GLOBAL_OBJECT_CACHE
        const object = cache[key]
        if (object) {
            const obj = GLOBAL_OBJECT_CACHE[key];
            if (obj) {
                // data already cached, we just need to increment the refcount
                GLOBAL_OBJECT_CACHE[key] = [obj[0], obj[1] + 1];
            } else {
                GLOBAL_OBJECT_CACHE[key] = [object, 1]
            }
        }
        // always keep track of usage in session cache
        session_cache.add(key);
    });
    return cache;
}

export function deserialize_cached(message) {
    const { session_id, session_cache, data } = message;
    const cache = update_session_cache(session_id, session_cache);
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

export function init_session(session_id, on_connection_open) {
    console.log("init session")
    register_on_connection_open(on_connection_open);
    track_deleted_sessions();
    SESSIONS[session_id] = new Set();
    // send_session_ready(session_id);
    const root_node = document.getElementById(session_id);
    if (root_node) {
        root_node.style.visibility = "visible";
    }
}

export function close_session(session_id) {
    const session_cache = SESSIONS[session_id];
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
