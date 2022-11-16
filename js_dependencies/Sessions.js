import { deserialize, Retain } from "./Protocol.js";
import { register_on_connection_open, send_error, send_close_session, send_warning, send_done_loading } from "./Connection.js";

const SESSIONS = {};
// global object cache with refcounting
// contains {id: [data, refcount]}
// Right now, should only contain Observables + Assets
const GLOBAL_OBJECT_CACHE = {};

const FREE_JOBS_QUEUE = []
let ALLOW_FREEING_OBJECTS = true

function while_locking_free(f, id) {
    ALLOW_FREEING_OBJECTS = false
    function cleanup() {
        ALLOW_FREEING_OBJECTS = true
        while (FREE_JOBS_QUEUE.length > 0) {
            const job = FREE_JOBS_QUEUE.pop()
            job()
        }
    }
    const promise = Promise.resolve(f())
    promise.then(x=> {
        cleanup()
    })

}

export function lookup_observable(id) {
    const object = GLOBAL_OBJECT_CACHE[id];
    if (!object) {
        send_error(`Could not find ${id} in global cache.`);
    }
    return object;
}

function is_still_referenced(id) {
    for (const session_id in JSServe.Sessions.SESSIONS) {
        const [tracked_objects, allow_delete] = JSServe.Sessions.SESSIONS[session_id]
        if (allow_delete && tracked_objects.has(id)) {
            // don't free if a session still holds onto it
            return true;
        }
    }
    return false
}

function free_object(id) {
    const data = GLOBAL_OBJECT_CACHE[id];
    if (data) {
        if (data.constructor == Promise) {
            // Promise => Module. We don't free Modules, since they'll be cached by the active page anyways
            return
        }
        if (data instanceof Retain) {
            // Retain is a reserved type to never free an object from a session
            return
        }
        if (!is_still_referenced(id)) {
            // nobody holds on to this id anymore!!
            delete GLOBAL_OBJECT_CACHE[id]
        }
        return;
    } else {
        send_warning(
            `Trying to delete object ${id}, which is not in global session cache.`
        );
    }
    return;
}

function update_session_cache(session_id, new_session_cache) {
    const [tracked_objects, allow_delete] = SESSIONS[session_id]
    const cache = deserialize(GLOBAL_OBJECT_CACHE, new_session_cache)
    for (const key in cache) {
        // always keep track of usage in session cache
        tracked_objects.add(key);
        // object can be nothing, which mean we already have it in GLOBAL_OBJECT_CACHE
        const new_object = cache[key]
        if (new_object == "tracking-only") {
            if (!(key in GLOBAL_OBJECT_CACHE)) {
                throw new Error(`Key ${key} only send for tracking, but not already tracked!!!`)
            }
        } else {
            if (!(key in GLOBAL_OBJECT_CACHE)) {
                GLOBAL_OBJECT_CACHE[key] = new_object
            } else {
                console.warn(`${key} in session cache and send again!!`)
            }
        }
    }
}

export function deserialize_cached(message) {
    const { session_id, session_cache, data } = message;
    update_session_cache(session_id, session_cache);
    return deserialize(GLOBAL_OBJECT_CACHE, data)
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
                    if (x.id in SESSIONS) {
                        const status = SESSIONS[x.id][1]
                        if (status == 'delete') {
                            to_delete.add(x.id);
                        }
                    } else {
                        removal_occured = true;
                    }
                });
            });
            // removal occured from elements not matching the id!
            if (removal_occured) {
                Object.keys(SESSIONS).forEach((id) => {
                    const allow_delete = SESSIONS[id][1]
                    if (allow_delete == 'delete') {
                        if (!document.getElementById(id)) {
                            console.log(`adding session to delete candidates: ${id}`)
                        // the ROOT session may survive without being in the dom anymore
                            to_delete.add(id);
                        }
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

export function init_session(session_id, on_connection_open, session_status) {
    while_locking_free(()=> {
        console.log(`init session: ${session_id}, ${session_status}`)
        track_deleted_sessions();
        const tracked_items = new Set()
        SESSIONS[session_id] = [tracked_items, session_status];
        if (session_status == 'root') {
            return register_on_connection_open(on_connection_open, session_id);
        } else {
            const maybe_promise = on_connection_open()
            const promise = Promise.resolve(maybe_promise)
            return promise.then((x)=> {
                send_done_loading(session_id)
                SESSIONS[session_id] = [tracked_items, 'delete'];
                console.log(`session ${session_id} fully initialized`)
            })
        }
    }, session_id)
}

export function close_session(session_id) {
    const [session_cache, allow_delete] = SESSIONS[session_id];
    const root_node = document.getElementById(session_id);
    if (root_node) {
        root_node.style.display = "none";
        root_node.parentNode.removeChild(root_node);
    }
    if (allow_delete) {
        send_close_session(session_id, allow_delete);
        SESSIONS[session_id] = [session_cache, false]
    }
    return;
}

export function free_session(session_id) {
    function free_session_impl() {
        console.log(`actually freeing session ${session_id}`)
        const [tracked_objects, subsession] = SESSIONS[session_id];
        tracked_objects.forEach(key => {
            free_object(key);
        })
        tracked_objects.clear()
        delete SESSIONS[session_id];
    }
    if (ALLOW_FREEING_OBJECTS) {
        free_session_impl()
    } else {
        FREE_JOBS_QUEUE.push(free_session_impl)
    }
}

export {
    SESSIONS,
    GLOBAL_OBJECT_CACHE
}
