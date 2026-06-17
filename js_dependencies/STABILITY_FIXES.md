# Bonito JS client stability fixes (2026-06-10)

Fixes for findings J1–J15 from `stability-review-2026-06-10.md` (Bonito JS client section).
Files touched: `Connection.js`, `Websocket.js`, `Sessions.js`, `Protocol.js`, `Observables.js`, `Bonito.js`.
No `*.bundled.js` / `*.min.js` were edited — the orchestrator rebundles.

For each finding: the bug, the fix, and how an Electron/browser test could exercise it.
The project has an electron-test harness (`/electron-test` skill) that can open a Bonito app,
execute JS in the page, assert on the DOM, capture console logs and take screenshots.

---

## The reconnect cluster (J1–J6) — fix coherently

These interact: status flips, the offline queue, and the requeue-on-failure path all have to
agree. The unifying rule now: **`send_to_julia` queues the message whenever the connection is
not actually writable** (any status except `"open"` with a working socket, and except
`"no_connection"` static mode). The queue is swapped out and flushed exactly once per
`on_connection_open`.

### J1 — offline queue never cleared, replayed on every reconnect

- **Before:** `on_connection_open` did `CONNECTION.queue.forEach(send_to_julia)` but never
  emptied the array. Every reconnect re-sent the entire historical queue: stale
  `UpdateObservable`s overwrote newer values, `CloseSession`/`JSDoneLoading` were duplicated, and
  the array grew unbounded.
- **After (`Connection.js` `on_connection_open`):** swap the array out (`const pending =
  CONNECTION.queue; CONNECTION.queue = []`) **before** flushing. A send that fails mid-flush
  re-queues into the now-fresh array (see J2) instead of being re-iterated.
- **Test:** open an app; `CONNECTION.queue.push(...)` a couple of dummy messages while forcing
  status to `"connecting"`; trigger `on_connection_open`; assert `CONNECTION.queue.length === 0`.
  Force a second reconnect and assert no duplicate messages reach Julia (spy on `send_message`).

### J2 — one message silently lost per disconnect

- **Before:** nothing flipped `CONNECTION.status` off `"open"` when the TCP socket died. The next
  `send_to_julia` called `ws.send` → `ensure_connection()` returned `"connecting"` →
  `send` returned `false`, which `send_to_julia` ignored. One message dropped.
- **After:**
  - `Connection.js` `send_to_julia`: when `send_message(...)` returns `false`/`undefined`, push
    the message back onto `CONNECTION.queue` and flip status to `"closed"` so subsequent sends
    queue too.
  - `Websocket.js` `ws.onclose`: call `Bonito.on_connection_connecting()` immediately so status
    leaves `"open"` the instant the socket closes.
- **Test:** open an app, kill the websocket server-side (or call `WEBSOCKET.close()`), then push a
  message via an observable `.notify`; assert the message lands in `CONNECTION.queue` and is
  delivered after reconnect (spy on `send_message`).

### J3 — no recovery path after the 30s give-up

- **Before:** after `retry_connection` gave up, status became `"closed"`; `send_to_julia` hit the
  `else` branch and dropped messages with a `console.log`. The only revival path (`ws.send` →
  `ensure_connection` → `retry_connection`) was never reached again → an outage >30s permanently
  killed the tab.
- **After (`Connection.js`):**
  - `send_to_julia` now queues on `"closed"` too (only `"no_connection"` static mode drops).
  - `on_connection_close` arms one-time `window` `online`/`focus` listeners
    (`arm_reconnect_triggers`) that call `window.WEBSOCKET.retry_connection()` and flip status to
    `"connecting"` when the tab comes back / regains focus.
- **Test:** simulate an outage > 30s (mock `WebSocket` to always fail) so the retry loop gives up;
  assert messages still accumulate in `CONNECTION.queue`; dispatch a `window` `online` event with a
  reachable server and assert reconnect + queue flush.

### J4 — refcount ignored `"sub"`/`"moving"`/parked states → premature frees

- **Before:** `Sessions.is_still_referenced` only counted statuses `"delete"`/`"root"`. A
  sub-session mid-init (`"sub"`), a DOM move (`"moving"`), or a session parked as
  `[objects, false]` awaiting Julia's `free_session` no longer counted → shared objects freed
  underneath them → `Key N not found` / `null.notify`.
- **After:** an id is referenced iff **any** surviving `SESSIONS` entry still tracks it. The only
  moment a session stops counting is when `free_session` deletes the entry entirely (confirmed
  free). Status no longer gates the count.
- **Test:** create a root + sub session sharing one observable; trigger a body re-render that frees
  the sub while it is `[objects, false]`; assert the shared observable is still in
  `GLOBAL_OBJECT_CACHE` and `lookup_global_object(id)` is non-null; then click a control that
  notifies it and assert no `Key not found` console warning.

### J5 — `update_session_dom` froze all message processing for up to 30s

- **Before:** `update_session_dom` ran the whole body (including a 30s `on_node_available` poll)
  inside `lock_loading` (PQueue concurrency 1). One missing selector froze message processing for
  every session for the full timeout.
- **After:** poll `on_node_available` **outside** the lock; take `lock_loading` only around the
  synchronous apply (`update_or_replace` + `init_session_from_msgs`, which touch the shared cache).
- **Test:** send an `UpdateSession` for a selector that does not exist; concurrently send an
  `UpdateObservable` for an existing observable; assert the observable updates promptly (well under
  30s) instead of blocking on the missing-selector poll.

### J6 — decode errors became unhandled rejections (message silently dropped)

- **Before:** `ws.onmessage` ran `decode_binary` + `process_message` inside
  `Bonito.lock_loading(() => {...})`; `lock_loading` discarded the PQueue promise. A throw during
  decode (corrupt msgpack, JS eval error in `JSCODE_TAG`) became an unhandled rejection — message
  dropped, `send_error` never called, observables left partially registered.
- **After:**
  - `Websocket.js` `ws.onmessage`: decode+process now run inside the locked task with a `.catch`
    that calls `Bonito.send_error(...)` and a `.finally` for the data-transfer indicator.
  - `Sessions.js` `lock_loading`: attaches `.catch(error => send_error(...))` on the
    `OBJECT_FREEING_LOCK.add(f)` promise so any locked task that throws surfaces with context
    instead of becoming an unhandled rejection.
- **Test:** feed `ws.onmessage` a deliberately corrupt `ArrayBuffer`; assert a `JavascriptError`
  message is sent to Julia (spy on `send_message`) and that subsequent valid messages still
  process (the lock did not wedge).

---

## MEDIUM findings

### J7 — retry loop could exit with `#is_retrying` stuck true

- **Before:** in `attempt_connection`, if the clock crossed the deadline between the elapsed check
  and the reschedule check, the function returned without rescheduling and without `give_up()`,
  leaving `#is_retrying = true` forever → all future reconnects no-op (`"Already retrying"`).
- **After (`Websocket.js`):** added `else if (!self.isopen()) { give_up(); }` so the flag is always
  reset.
- **Test:** hard to hit deterministically; unit-style: stub timing so the deadline is crossed
  exactly at the boundary and assert `retry_connection` can be called again afterwards (a later
  reconnect actually attempts a connection).

### J8 — `ensure_session_exists` resurrected freed sessions

- **Before:** an in-flight message racing the close handshake called `ensure_session_exists` for a
  session Julia already freed → zombie session + leaked objects for the life of the tab.
- **After (`Sessions.js`):** `free_session` records the id in `FREED_SESSION_TOMBSTONES` (30s TTL);
  `ensure_session_exists` refuses to recreate a tombstoned id. `track_in_session` /
  `register_in_session_cache` now null-check the session and drop late traffic instead of throwing.
- **Test:** free a session, then immediately dispatch a stale `UpdateSession`/observable message
  referencing it; assert `SESSIONS[id]` stays undefined and a tombstone warning is logged.

### J9 — `move_dom_node` double-move wedged status at `"moving"`

- **Before:** a second `move_dom_node` captured `restore = "moving"` (from the still-pending first
  move); when the timers fired the status was permanently `"moving"` → delete observer never closed
  the session; restore-after-free threw on `undefined`.
- **After:** stash the genuine pre-move status on the entry once (only when not already `"moving"`)
  and use a monotonic token so only the **latest** scheduled restore wins; the restore no-ops if the
  session was freed meanwhile.
- **Test:** call `move_dom_node` on the same tracked node twice in quick succession; after the
  microtask flush assert `SESSIONS[id][1]` is back to its original status (e.g. `"delete"`), then
  remove the node and assert `close_session` fires.

### J10 — init failure sent `done_loading` twice + unhandled rejection

- **Before:** `init_session_from_msgs` caught, sent `done_loading`, and rethrew; every caller's
  `.catch` sent `done_loading` again and rethrew into an unhandled rejection.
- **After (`Sessions.js`):** `init_session_from_msgs` owns the single done-loading-on-failure report
  and no longer rethrows. `init_session`'s `.catch` only fires for promise/decode failures (where
  `init_session_from_msgs` never ran) and reports once without rethrowing.
- **Test:** inject a message that throws during `process_message`; assert exactly one
  `JSDoneLoading` with an exception reaches Julia and no unhandled-rejection is logged.

### J11 — re-serialized Observable id → duplicate instances, dead callbacks

- **Before:** `OBSERVABLE_TAG` always did `new Observable(id, value)`. If the id already existed,
  `UpdateObservable` routed to the cached instance (via `lookup_global_object`) while the new
  session's callbacks were attached to the duplicate → new view never updated.
- **After (`Protocol.js`):** reuse the existing cached `Observable` for a known id; only construct
  a new one when none exists.
- **Test:** render two sessions sharing one observable where the second receives a full value (not a
  `CacheKey`); update the observable from Julia and assert both sessions' DOM update.

### J12 — `load_script` hung when reusing an already-loaded script tag

- **Before:** when a matching `<script>` already existed and its `load` event had fired, the newly
  attached `load` listener never ran → the promise never resolved.
- **After (`Bonito.js`):** if `existing_script.dataset.loaded === "true"`, start polling for the
  global immediately (covers async-global libs) instead of waiting for a `load` that won't come.
- **Test:** call `load_script(url, name)` twice for the same URL; assert the second call resolves
  (does not hang) and yields the global.

### J13 — base64 encode/decode promises could never reject (hang on bad input)

- **Before:** `base64encode` only set `reader.onload`; `base64decode` chained `.then` with no
  rejection path. Bad input hung every awaiter forever.
- **After (`Protocol.js`):** `base64encode` adds `onerror`/`onabort` → reject and wraps
  `readAsDataURL` in try/catch; `base64decode` chains `.catch(reject)`.
- **Test:** call `base64decode("not valid base64 ***")` and assert the promise rejects rather than
  hanging.

### J14 — `update_or_replace` left stale text nodes

- **Before:** the clear loop used `node.childElementCount > 0` and removed `firstChild`. Once only
  text/comment nodes remained, the count was 0 and the loop exited, leaving them behind.
- **After (`Sessions.js`):** loop on `node.firstChild` so all child nodes (including text/comment)
  are removed before appending the new content.
- **Test:** put a text node before an element child in a session DOM node, run a non-replace
  `update_session_dom`, and assert the stale text is gone.

### J15 — callback deregistration during `notify` skipped the next listener

- **Before:** `Observable.notify` iterated `this.#callbacks` with `forEach` and `splice`d during
  iteration; removing a callback shifted the array and skipped the immediately-following listener.
- **After (`Observables.js`):** iterate a `slice()` snapshot, collect callbacks to remove, splice
  them afterwards.
- **Test:** register three callbacks where the first returns `false` (deregisters); notify once and
  assert all three ran (the second was not skipped) and the first is gone on the next notify.

---

## Wire-protocol note

None of these changes alter the wire protocol — message types, field names, and the
`dont_notify_julia` echo-suppression are unchanged. Behavior changes are limited to:
queue/requeue/retry timing, refcount accounting, lock scope, DOM clearing, and promise
error-propagation. The orchestrator does **not** need to touch the Julia side for J1–J15.
