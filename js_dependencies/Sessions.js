import { Retain, decode_binary } from "./Protocol.js";
import { FusedMessage, Lock } from "./Connection.js";

import {
    send_close_session,
    send_warning,
    send_done_loading,
    process_message,
} from "./Connection.js";

const SESSIONS = {};
// global object cache with refcounting
// contains {id: [data, refcount]}
// Right now, should only contain Observables + Assets
const GLOBAL_OBJECT_CACHE = {};

// Lock synchronizing the freeing of session objects and initializing of sessions.
// Needed for the case, when e.g. a `session1` just gets initialized async, and another `session2` just gets closed async
// it can happen that session1 brings an object-x, which got already tracked by session2 and therefore is in the GLOBAL_OBJECT_CACHE and in the parent session.
// Because its in the parent session and not yet deleted (note we're just about to close session2), session1 will send only the key to object-x, but not its value.
// So, if session2 gets a chance to free object-x, before session1 is initialized,
// the check for `is_still_referenced(object-x)` will return false so object-x will actually get deleted.
// Even though a moment later after initialization of session1, `is_still_referenced(object-x)` will return true and object won't get deleted.
const OBJECT_FREEING_LOCK = new Lock();

export function lookup_global_object(key) {
    const object = GLOBAL_OBJECT_CACHE[key];
    if (object) {
        if (object instanceof Retain) {
            return object.value;
        } else {
            return object;
        }
    }
    throw new Error(`Key ${key} not found! ${object}`);
}

function is_still_referenced(id) {
    for (const session_id in SESSIONS) {
        const [tracked_objects, allow_delete] = SESSIONS[session_id];
        if (allow_delete && tracked_objects.has(id)) {
            // don't free if a session still holds onto it
            return true;
        }
    }
    return false;
}

function free_object(id) {
    const data = GLOBAL_OBJECT_CACHE[id];
    if (data) {
        if (data instanceof Promise) {
            // Promise => Module. We don't free Modules, since they'll be cached by the active page anyways
            return;
        }
        if (data instanceof Retain) {
            // Retain is a reserved type to never free an object from a session
            return;
        }
        if (!is_still_referenced(id)) {
            // nobody holds on to this id anymore!!
            delete GLOBAL_OBJECT_CACHE[id];
        }
        return;
    } else {
        send_warning(
            `Trying to delete object ${id}, which is not in global session cache.`
        );
    }
    return;
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
                        const status = SESSIONS[x.id][1];
                        if (status === "delete") {
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
                    const status = SESSIONS[id][1];
                    if (status === "delete") {
                        if (!document.getElementById(id)) {
                            console.debug(
                                `adding session to delete candidates: ${id}`
                            );
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

/**
 * @param {string} session_id
 */
export function done_initializing_session(session_id) {
    if (!(session_id in SESSIONS)) {
        throw new Error("Session ");
    }
    console.log("send done loading!");
    send_done_loading(session_id);
    // allow subsessions to get deleted after being fully initialized (prevents deletes while half initializing)
    if (SESSIONS[session_id][1] != "root") {
        SESSIONS[session_id][1] = "delete";
    }
    // allow delete now!
    console.log(`session ${session_id} fully initialized`);
}

export function init_session(session_id, binary_messages, session_status) {
    track_deleted_sessions(); // no-op if already tracking
    OBJECT_FREEING_LOCK.task_lock(session_id);
    try {
        console.log(`init session: ${session_id}, ${session_status}`);
        process_message(decode_binary(binary_messages));
        done_initializing_session(session_id);
    } catch (error) {
        send_done_loading(session_id, error);
    } finally {
        OBJECT_FREEING_LOCK.task_unlock(session_id);
    }
}

/*
To prevent Julia + JS object tracking to go out of sync, we first delete all objects tracked in Julia by calling `close_session(id)` here triggering `send_close_session`.
This will then trigger `evaljs(parent, js"free_session(id)")` on the julia side, which only then will delete the objects in JS.
This is important, since the Julia side serializes the objects based on what's already tracked in Julia/JS, and then just sends references to objects already on the JS side.
If we deleted on JS first, it could happen, that Julia just in that momement serializes objects for a new session, which references an object that is just about to get deleted in JS,
so once it actually arrives in JS, it'd be already gone.
*/
export function close_session(session_id) {
    const [session_objects, status] = SESSIONS[session_id];
    const root_node = document.getElementById(session_id);
    if (root_node) {
        root_node.style.display = "none";
        root_node.parentNode.removeChild(root_node);
    }
    // we don't want to delete sessions, that are currently not deletable (e.g. root session)
    if (status === "delete") {
        send_close_session(session_id, status);
        SESSIONS[session_id] = [session_objects, false];
    }
    return;
}

// called from julia!
export function free_session(session_id) {
    OBJECT_FREEING_LOCK.lock(() => {
        console.log(`actually freeing session ${session_id}`);
        const [tracked_objects, status] = SESSIONS[session_id];
        tracked_objects.forEach(free_object);
        tracked_objects.clear();
        delete SESSIONS[session_id];
    });
}

export function on_node_available(query_selector, timeout) {
    return new Promise((resolve) => {
        function test_node(timeout) {
            let node;
            if (query_selector.by_id) {
                node = document.getElementById(query_selector.by_id);
            } else {
                node = document.querySelector(query_selector.query_selector);
            }
            if (node) {
                resolve(node);
            } else {
                const new_timeout = 2 * timeout;
                console.log(new_timeout);
                setTimeout(test_node, new_timeout, new_timeout);
            }
        }
        test_node(timeout);
    });
}

export function update_or_replace(node, new_html, replace) {
    if (replace) {
        node.parentNode.replaceChild(new_html, node);
    } else {
        while (node.childElementCount > 0) {
            node.removeChild(node.firstChild);
        }
        node.append(new_html);
    }
}

export function update_session_dom(message) {
    const { session_id, messages, html, dom_node_selector, replace } = message;
    on_node_available(dom_node_selector, 1).then((dom) => {
        try {
            update_or_replace(dom, html, replace);
            process_message(messages);
            done_initializing_session(session_id);
        } catch (error) {
            send_done_loading(session_id, error);
        } finally {
            // this locks corresponds to the below task_lock from update session cache for an unitialized session
            // which happens, since we need to send this session via a message
            OBJECT_FREEING_LOCK.task_unlock(session_id);
        }
    });
    return;
}

export function update_session_cache(session_id, new_jl_objects, session_status) {
    function update_cache(tracked_objects) {
        for (const key in new_jl_objects) {
            // always keep track of usage in session
            tracked_objects.add(key);
            // object can be "tracking-only", which mean we already have it in GLOBAL_OBJECT_CACHE
            const new_object = new_jl_objects[key];
            if (new_object == "tracking-only") {
                if (!(key in GLOBAL_OBJECT_CACHE)) {
                    throw new Error(
                        `Key ${key} only send for tracking, but not already tracked!!!`
                    );
                }
            } else {
                if (!(key in GLOBAL_OBJECT_CACHE)) {
                    GLOBAL_OBJECT_CACHE[key] = new_object;
                } else {
                    console.warn(`${key} in session cache and send again!!`);
                }
            }
        }
    }

    const session = SESSIONS[session_id];
    // session already initialized
    if (session) {
        update_cache(session[0]);
    } else {
        // we can update the session cache for a not yet registered session, which we then need to register first:
        // but this means our session is not initialized yet, and we need to lock it from freing objects
        OBJECT_FREEING_LOCK.task_lock(session_id);
        const tracked_items = new Set();
        SESSIONS[session_id] = [tracked_items, session_status];
        update_cache(tracked_items);
    }
}

export { SESSIONS, GLOBAL_OBJECT_CACHE };
