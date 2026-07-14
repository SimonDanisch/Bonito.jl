import { decode_binary } from "./Protocol.js";
import PQueue from "https://esm.sh/p-queue";

import {
    send_close_session,
    send_done_loading,
    send_error,
    process_message,
} from "./Connection.js";

const SESSIONS = {};
// global object cache with refcounting
// contains {id: [data, refcount]}
// Right now, should only contain Observables + Assets
const GLOBAL_OBJECT_CACHE = {};

// J8: tombstones of recently freed session ids. An in-flight message
// (e.g. an UpdateSession / unpack) can race the close handshake and call
// ensure_session_exists for a session Julia already told us to free. Without
// this guard the session (and its objects) would be resurrected as a zombie
// that leaks for the life of the tab. We keep the id here for a short window so
// such late messages are dropped rather than recreating the entry.
const FREED_SESSION_TOMBSTONES = new Set();
const TOMBSTONE_TTL_MS = 30000;

function tombstone_session(session_id) {
    FREED_SESSION_TOMBSTONES.add(session_id);
    setTimeout(() => FREED_SESSION_TOMBSTONES.delete(session_id), TOMBSTONE_TTL_MS);
}

// Lock synchronizing the freeing of session objects and initializing of sessions.
// Needed for the case, when e.g. a `session1` just gets initialized async, and another `session2` just gets closed async
// it can happen that session1 brings an object-x, which got already tracked by session2 and therefore is in the GLOBAL_OBJECT_CACHE and in the parent session.
// Because its in the parent session and not yet deleted (note we're just about to close session2), session1 will send only the key to object-x, but not its value.
// So, if session2 gets a chance to free object-x, before session1 is initialized,
// the check for `is_still_referenced(object-x)` will return false so object-x will actually get deleted.
// Even though a moment later after initialization of session1, `is_still_referenced(object-x)` will return true and object won't get deleted.
const OBJECT_FREEING_LOCK = new PQueue({ concurrency: 1 });

export function lock_loading(f) {
    // J6: PQueue.add() returns a promise that rejects if the task throws.
    // Discarding it turned any throw inside a locked task into an unhandled
    // rejection (message silently dropped, send_error never called). Attach a
    // catch that surfaces the error with context. Callers that need their own
    // handling still attach a .catch inside `f` (those resolve here normally).
    OBJECT_FREEING_LOCK.add(f).catch((error) => {
        send_error("Error inside object-freeing-locked task", error);
    });
}

export function lookup_global_object(key, warn = true) {
    const object = GLOBAL_OBJECT_CACHE[key];
    if (object) {
        return object;
    }
    // `warn=false`: the caller expects legitimate misses (a late
    // UpdateObservable for an object a sub already freed) and handles null
    // itself. Only genuine missing-key bugs should reach the warning.
    if (warn) {
        console.warn(`Key ${key} not found! ${object}`);
    }
    return null;
}

function is_still_referenced(id) {
    // J4: an id is referenced as long as ANY entry in SESSIONS still tracks
    // it. The ONLY moment a session stops counting is when it has been
    // confirmed-freed by Julia — at which point `free_session` deletes the
    // whole entry from SESSIONS (and drops its tracked ids). So mere presence
    // of the id in any surviving session's tracked set is a live reference.
    //
    // The previous code only counted statuses "delete"/"root", which wrongly
    // ignored:
    //   - "sub": a sub-session mid-init (before done_initializing_session
    //     flips it to "delete") would lose its shared objects to a concurrent
    //     free -> "Key N not found" / null.notify.
    //   - "moving": a session whose DOM is being relocated.
    //   - false: a session parked by close_session awaiting Julia's
    //     free_session confirmation — the whole point of the close handshake.
    //     Counting it as unreferenced freed the object before Julia replied,
    //     so a re-serialization referencing it found null.
    for (const session_id in SESSIONS) {
        const [tracked_objects] = SESSIONS[session_id];
        if (tracked_objects.has(id)) {
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

/**
 * Atomically move `node` to land before `ref` in `parent` (ref=null →
 * last). Preserves the moving subtree's identity (iframe load, focus,
 * scroll, Bonito subsession bindings) by swapping the tracked status to
 * "moving" so the deletion observer ignores the transient detach.
 *
 * Native `Element.moveBefore()` (Chromium 133+, Firefox 144+) would do
 * this without firing the observer at all, but Chromium <133 (Electron 38
 * ≈ Chromium 130) ships an early stub that still fires removedNodes —
 * defeating the point and not feature-detectable. Fallback is correct on
 * every browser; re-enable native once the floor is Chromium 133+.
 */
export function move_dom_node(node, parent, ref) {
    const id = node.id;
    if (!id || !(id in SESSIONS)) {
        // Fresh node (no tracked sub) — observer doesn't care.
        parent.insertBefore(node, ref);
        return;
    }
    // Defer the restore: insertBefore = remove + insert and the observer
    // microtask runs AFTER this function returns. A synchronous restore
    // would flip the status back to "delete" before the observer sees
    // the "moving" sentinel and skip close_session.
    //
    // J9: guard against a double-move. If a previous move is still pending
    // (status already "moving"), capturing the current status as `restore`
    // would capture "moving" and permanently wedge the session there once the
    // timers fire — the delete observer would then never close it, and a
    // restore-after-free would throw on `undefined`. Stash the real
    // pre-move status on the entry and only the LAST timer to fire restores it.
    const entry = SESSIONS[id];
    if (entry[1] !== "moving") {
        // Remember the genuine status to restore to (index 2 is our scratch).
        entry[2] = entry[1];
    }
    entry[1] = "moving";
    // token lets the latest scheduled restore win and earlier ones no-op.
    const token = (entry[3] || 0) + 1;
    entry[3] = token;
    parent.insertBefore(node, ref);
    setTimeout(() => {
        const current = SESSIONS[id];
        // Session may have been freed in the meantime — nothing to restore.
        if (!current || current[3] !== token) {
            return;
        }
        current[1] = current[2];
        current[2] = undefined;
        current[3] = undefined;
    }, 0);
}

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
// Sessions that completed initialization. On a websocket reconnect these are
// re-announced to Julia (a fresh JSDoneLoading), so the server re-opens the
// session: flushes messages queued while disconnected, resets the status and
// fires `session.on_open` for integrations that re-synchronize state.
const INITIALIZED_SESSIONS = new Set();

export function reannounce_initialized_sessions() {
    INITIALIZED_SESSIONS.forEach((session_id) => {
        if (session_id in SESSIONS) {
            send_done_loading(session_id, null);
        } else {
            INITIALIZED_SESSIONS.delete(session_id);
        }
    });
}

export function done_initializing_session(session_id) {
    if (!(session_id in SESSIONS)) {
        // Session was deleted during initialization - still notify Julia to prevent hang
        console.warn(`Session ${session_id} got deleted before done initializing!`);
        send_done_loading(session_id, new Error("Session deleted before initialization completed"));
        return;
    }
    INITIALIZED_SESSIONS.add(session_id);
    send_done_loading(session_id, null);
    // allow subsessions to get deleted after being fully initialized (prevents deletes while half initializing)
    if (SESSIONS[session_id][1] != "root") {
        SESSIONS[session_id][1] = "delete";
    }
    // allow delete now!
}


function init_session_from_msgs(session_id, messages) {
    // J10: report done_loading exactly once. This used to send_done_loading
    // AND rethrow, while every caller's surrounding .catch ALSO sent
    // done_loading (and rethrew into an unhandled rejection). We now own the
    // single done_loading-on-failure report here and swallow the rethrow, so
    // Julia is informed exactly once and there is no dangling rejection.
    try {
        messages.forEach(process_message);
        done_initializing_session(session_id);
    } catch (error) {
        send_done_loading(session_id, error);
        console.error(error.stack || error);
    }
}

export function init_session(session_id, message_promise, session_status, compression) {
    SESSIONS[session_id] = [new Set(), session_status];
    track_deleted_sessions(); // no-op if already tracking
    lock_loading(() => {
        return Promise.resolve(message_promise).then((binary) => {
            const messages = binary ? decode_binary(binary, compression) : [];
            // init_session_from_msgs reports its own failures via done_loading
            // and does not throw (J10).
            init_session_from_msgs(session_id, messages);
        }).catch((error) => {
            // Only reached when message_promise rejects or decode_binary throws
            // — i.e. init_session_from_msgs never ran, so done_loading was not
            // yet sent. Report once here. Do NOT rethrow (J10): lock_loading's
            // own catch would otherwise re-surface it as a duplicate error.
            send_done_loading(session_id, error);
            console.error(error.stack || error);
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
        // J8: remember this id so a late in-flight message can't resurrect it.
        tombstone_session(session_id);
        INITIALIZED_SESSIONS.delete(session_id);
        tracked_objects.forEach(free_object);
        tracked_objects.clear();
    });
}

export function on_node_available(node_id, timeout, max_timeout = 30000) {
    return new Promise((resolve, reject) => {
        let elapsed = 0;
        function test_node(current_timeout) {
            const node = document.querySelector(`[data-jscall-id='${node_id}']`);
            if (node) {
                resolve(node);
            } else {
                elapsed += current_timeout;
                if (elapsed > max_timeout) {
                    reject(new Error(`Timeout waiting for DOM node with data-jscall-id='${node_id}' after ${max_timeout}ms`));
                    return;
                }
                const new_timeout = Math.min(current_timeout * 2, 1000); // cap at 1s intervals
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
        // J14: clear ALL children, not just element children. The old loop
        // condition `childElementCount > 0` removed `firstChild` (which may be
        // a text node), so once only text nodes remained the count was 0 and
        // the loop exited leaving stale text content behind. Use firstChild as
        // the loop condition so text/comment nodes are cleared too.
        while (node.firstChild) {
            node.removeChild(node.firstChild);
        }
        node.append(new_html);
    }
}

export function update_session_dom(message) {
    const { session_id, session_status, messages, html, dom_node_selector, replace } = message;
    // Ensure session exists - it should have been created during SerializedMessage unpack,
    // but we ensure it here to handle any race conditions
    ensure_session_exists(session_id, session_status || "sub");
    // J5: poll for the target DOM node OUTSIDE the global OBJECT_FREEING_LOCK.
    // on_node_available can block for up to 30s when a selector never appears;
    // holding the (concurrency-1) lock across that wait froze ALL message
    // processing for every session for the full timeout. Only the synchronous
    // apply (DOM swap + replaying this session's init messages, which touches
    // the shared object cache) needs the lock.
    return on_node_available(dom_node_selector, 1).then((dom) => {
        lock_loading(() => {
            update_or_replace(dom, html, replace);
            init_session_from_msgs(session_id, messages);
        });
    }).catch((error) => {
        send_done_loading(session_id, error);
    });
}

/**
 * Ensure a session exists in SESSIONS. Creates it if it doesn't exist.
 * This is needed because sessions without observables won't have any objects
 * that call register_in_session_cache during unpacking.
 *
 * @param {string} session_id
 * @param {string} session_status - "root" or "sub"
 */
export function ensure_session_exists(session_id, session_status) {
    if (session_id in SESSIONS) {
        return;
    }
    // J8: do not resurrect a session that was just freed by Julia. A message
    // that was already in flight when the close handshake completed must not
    // recreate the entry (zombie session + leaked objects). "root" sessions are
    // never tombstoned, so this only blocks late sub-session traffic.
    if (FREED_SESSION_TOMBSTONES.has(session_id)) {
        console.warn(`Ignoring (re)creation of freed session ${session_id} (tombstoned)`);
        return;
    }
    SESSIONS[session_id] = [new Set(), session_status];
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
    ensure_session_exists(session_id, session_status);
    const session = SESSIONS[session_id];
    if (!session) {
        // J8: session was tombstoned (freed) and ensure_session_exists refused
        // to resurrect it — this is a late in-flight message; drop it.
        console.warn(`track_in_session for freed session ${session_id} ignored`);
        return;
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
    ensure_session_exists(session_id, session_status);
    const session = SESSIONS[session_id];
    if (!session) {
        // J8: session was tombstoned (freed); refuse to re-register objects for
        // a dead session. Still publish to the global cache only if a live
        // session already references the key, otherwise it would leak.
        console.warn(`register_in_session_cache for freed session ${session_id} ignored`);
        return;
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
