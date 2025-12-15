import { Retain, decode_binary } from "./Protocol.js";
import PQueue from "https://esm.sh/p-queue";

import {
    send_close_session,
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
const OBJECT_FREEING_LOCK = new PQueue({ concurrency: 1 });

export function lock_loading(f) {
    OBJECT_FREEING_LOCK.add(f);
}

export function lookup_global_object(key) {
    const object = GLOBAL_OBJECT_CACHE[key];
    if (object) {
        if (object instanceof Retain) {
            return object.value;
        } else {
            return object;
        }
    }
    console.warn(`Key ${key} not found! ${object}`);
    return null;
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

export function force_free_object(id) {
    for (const session_id in SESSIONS) {
        const [tracked_objects, allow_delete] = SESSIONS[session_id];
        tracked_objects.delete(id);
    }
    delete GLOBAL_OBJECT_CACHE[id];
}

export function free_object(id) {
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
        console.warn(
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
        console.warn(`Session ${session_id} got deleted before done initializing!`);
        return;
    }
    send_done_loading(session_id, null);
    // allow subsessions to get deleted after being fully initialized (prevents deletes while half initializing)
    if (SESSIONS[session_id][1] != "root") {
        SESSIONS[session_id][1] = "delete";
    }
    // allow delete now!
}


function init_session_from_msgs(session_id, messages) {
    try {
        messages.forEach(process_message);
        done_initializing_session(session_id);
    } catch (error) {
        send_done_loading(session_id, error);
        console.error(error.stack);
        throw error;
    }
}

export function init_session(session_id, message_promise, session_status, compression) {
    SESSIONS[session_id] = [new Set(), session_status];
    track_deleted_sessions(); // no-op if already tracking
    lock_loading(() => {
        return Promise.resolve(message_promise).then((binary) => {
            const messages = binary ? decode_binary(binary, compression) : [];
            init_session_from_msgs(session_id, messages);
        }).catch((error) => {
            send_done_loading(session_id, error);
            console.error(error.stack);
            throw error;
        });
    });
}

/*
To prevent Julia + JS object tracking to go out of sync, we first delete all objects tracked in Julia by calling `close_session(id)` here triggering `send_close_session`.
This will then trigger `evaljs(parent, js"free_session(id)")` on the julia side, which only then will delete the objects in JS.
This is important, since the Julia side serializes the objects based on what's already tracked in Julia/JS, and then just sends references to objects already on the JS side.
If we deleted on JS first, it could happen, that Julia just in that momement serializes objects for a new session, which references an object that is just about to get deleted in JS,
so once it actually arrives in JS, it'd be already gone.
*/
export function close_session(session_id) {
    const session = SESSIONS[session_id];
    if (!session) {
        // when does this happen...Double close?
        // I've usually seen it when something errors, so I guess in that case the cleanup isn't done properly
        console.warn("double freeing session from JS!")
        return
    }
    const [session_objects, status] = session;
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
    lock_loading(() => {
        const session = SESSIONS[session_id];
        if (!session) {
            console.warn("double freeing session from Julia!");
            return;
        }
        const [tracked_objects, status] = session;
        delete SESSIONS[session_id];
        tracked_objects.forEach(free_object);
        tracked_objects.clear();
    });
}

export function on_node_available(node_id, timeout) {
    return new Promise((resolve) => {
        function test_node(timeout) {
            const node = document.querySelector(`[data-jscall-id='${node_id}']`);
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
    lock_loading(() => {
        const { session_id, messages, html, dom_node_selector, replace } = message;
        return on_node_available(dom_node_selector, 1).then((dom) => {
            update_or_replace(dom, html, replace);
            init_session_from_msgs(session_id, messages);
        }).catch((error) => {
            send_done_loading(session_id, error);
        });
    });
}

/**
 * Track a key in the session without adding to global cache.
 * Used by TrackingOnly extension - the object already exists in GLOBAL_OBJECT_CACHE
 * from a parent session, we just need to track it in this session.
 *
 * @param {string} session_id
 * @param {string} key - The object's cache key
 * @param {string} session_status - "root" or "sub"
 */
export function track_in_session(session_id, key, session_status) {
    // Ensure session exists
    let session = SESSIONS[session_id];
    if (!session) {
        const tracked_items = new Set();
        SESSIONS[session_id] = [tracked_items, session_status];
        session = SESSIONS[session_id];
    }
    const tracked_objects = session[0];

    // Track in session (object should already be in GLOBAL_OBJECT_CACHE)
    tracked_objects.add(key);

    if (!(key in GLOBAL_OBJECT_CACHE)) {
        console.warn(`TrackingOnly: Key ${key} not found in GLOBAL_OBJECT_CACHE`);
    }
}

/**
 * Register a single object to the session cache immediately during MsgPack unpacking.
 * This is called from Protocol.js extension decoders (like OBSERVABLE_TAG) so that
 * CacheKey references can resolve objects that were just decoded in the same unpack call.
 *
 * @param {string} session_id
 * @param {string} key - The object's cache key (e.g., observable id)
 * @param {any} object - The object to register
 * @param {string} session_status - "root" or "sub"
 */
export function register_in_session_cache(session_id, key, object, session_status) {
    // Ensure session exists
    let session = SESSIONS[session_id];
    if (!session) {
        const tracked_items = new Set();
        SESSIONS[session_id] = [tracked_items, session_status];
        session = SESSIONS[session_id];
    }
    const tracked_objects = session[0];

    // Track in session
    tracked_objects.add(key);

    // Add to global cache (skip if already there - shouldn't happen during single unpack)
    if (!(key in GLOBAL_OBJECT_CACHE)) {
        GLOBAL_OBJECT_CACHE[key] = object;
    }
}

// NOTE: This function is kept for backwards compatibility but is no longer called
// from Protocol.js. All objects (Observables, TrackingOnly) now self-register
// during MsgPack unpacking via register_in_session_cache/track_in_session.
export function update_session_cache(session_id, new_jl_objects, session_status) {
    function update_cache(tracked_objects) {
        for (const [key, new_object] of new_jl_objects) {
            tracked_objects.add(key);
            // Objects should already be in cache from self-registration during unpack
            if (!(key in GLOBAL_OBJECT_CACHE)) {
                GLOBAL_OBJECT_CACHE[key] = new_object;
            }
        }
    }

    const session = SESSIONS[session_id];
    if (session) {
        update_cache(session[0]);
    } else {
        const tracked_items = new Set();
        SESSIONS[session_id] = [tracked_items, session_status];
        update_cache(tracked_items);
    }
}

export { SESSIONS, GLOBAL_OBJECT_CACHE, OBJECT_FREEING_LOCK };
