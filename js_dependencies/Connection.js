import { encode_binary } from "./Protocol.js";
import { lookup_global_object, update_session_dom } from "./Sessions.js";

// Save some bytes by using ints for switch variable
const UpdateObservable = "0";
const OnjsCallback = "1";
const EvalJavascript = "2";
const JavascriptError = "3";
const JavascriptWarning = "4";
const RegisterObservable = "5";
const JSDoneLoading = "8";
const FusedMessage = "9";
const CloseSession = "10";
const PingPong = "11";
const UpdateSession = "12";
const GetSessionDOM = "13"

const PING_INTERVAL = 5000

function clean_stack(stack) {
    return stack.replaceAll(
        /(data:\w+\/\w+;base64,)[a-zA-Z0-9\+\/=]+:/g,
        "$1<<BASE64>>:"
    );
}


/**
 * Connection status constants
 */
const ConnectionStatus = {
    CONNECTING: "connecting",
    CONNECTED: "connected",
    DISCONNECTED: "disconnected",
    NO_CONNECTION: "no_connection"
};

/**
 * @namespace CONNECTION
 * @property {Function|undefined} send_message - Function to send a message. Initially undefined.
 * @property {Array} queue - Array to hold queued messages.
 * @property {string} status - Connection status, initially set to "closed".
 * @property {boolean} compression_enabled - Flag indicating if compression is enabled, initially set to false.
 * @property {Object|null} indicator - Registered connection indicator object.
 */
const CONNECTION = {
    send_message: undefined,
    queue: [],
    status: "connecting",
    compression_enabled: false,
    lastPing: Date.now(),
    indicator: null,
};

/**
 * Register a connection indicator object.
 * The indicator should implement: onStatusChange(status)
 * where status is one of: "connected", "connecting", "disconnected", "no_connection"
 * @param {Object} indicator - The indicator object with callback methods
 */
export function register_connection_indicator(indicator) {
    CONNECTION.indicator = indicator;
    // Immediately notify the current status
    notify_indicator_status();
}

/**
 * Unregister the current connection indicator
 */
export function unregister_connection_indicator() {
    CONNECTION.indicator = null;
}

/**
 * Set status to no_connection (for static/offline mode)
 * This is called by NoConnection setup to indicate no Julia server connection
 */
export function set_no_connection() {
    CONNECTION.status = "no_connection";
    notify_indicator_status();
}

/**
 * True when running in static/offline mode (no Julia backend). Widgets use this
 * to derive dependent observables client-side, since there's no server to do it.
 */
export function is_no_connection() {
    return CONNECTION.status === "no_connection";
}

/**
 * Notify the indicator of the current connection status
 */
function notify_indicator_status() {
    if (CONNECTION.indicator && typeof CONNECTION.indicator.onStatusChange === 'function') {
        let status;
        if (CONNECTION.status === "no_connection") {
            status = ConnectionStatus.NO_CONNECTION;
        } else if (CONNECTION.status === "open") {
            status = ConnectionStatus.CONNECTED;
        } else if (CONNECTION.status === "connecting") {
            status = ConnectionStatus.CONNECTING;
        } else {
            status = ConnectionStatus.DISCONNECTED;
        }
        CONNECTION.indicator.onStatusChange(status);
    }
}

/**
 * Set status to connecting (called before connection attempt)
 */
export function on_connection_connecting() {
    CONNECTION.status = "connecting";
    notify_indicator_status();
}

export function on_connection_open(send_message_callback, compression_enabled, enable_pings = true) {
    CONNECTION.send_message = send_message_callback;
    CONNECTION.status = "open";
    CONNECTION.compression_enabled = compression_enabled;
    // Notify indicator of connected status
    notify_indicator_status();
    // Once connection open, we send all messages that have queued up.
    // J1: swap the array out BEFORE flushing so the queue is empty while we
    // replay. Otherwise a send failure (which re-queues, see J2) would append
    // back into the array we're iterating, and the whole historical queue
    // would be replayed on every subsequent reconnect (duplicate
    // CloseSession/JSDoneLoading, stale UpdateObservable overwriting newer
    // values, unbounded growth).
    const pending = CONNECTION.queue;
    CONNECTION.queue = [];
    pending.forEach((message) => send_to_julia(message));
    if (enable_pings) {
        send_pings();
    }
}

export function on_connection_close() {
    CONNECTION.status = "closed";
    notify_indicator_status();
    // J3: after the websocket retry loop gave up there is otherwise no path
    // back. Keep messages queued (send_to_julia queues on every non-"open",
    // non-"no_connection" status now) and re-arm a reconnect attempt the next
    // time the browser comes back online or the tab regains focus.
    arm_reconnect_triggers();
}

// J3: lazily-registered window listeners that kick the websocket retry loop
// back to life after a give-up. Registered once; the handlers no-op while the
// connection is healthy.
let reconnect_triggers_armed = false;
function arm_reconnect_triggers() {
    if (reconnect_triggers_armed) {
        return;
    }
    if (typeof window === "undefined" || !window.addEventListener) {
        return;
    }
    reconnect_triggers_armed = true;
    const try_revive = () => {
        // Only act when we actually lost the connection. While "open" or
        // "connecting" the websocket state machine already owns recovery.
        if (CONNECTION.status === "open"
            || CONNECTION.status === "connecting"
            || CONNECTION.status === "no_connection") {
            return;
        }
        if (typeof window !== "undefined" && window.WEBSOCKET
            && typeof window.WEBSOCKET.retry_connection === "function") {
            CONNECTION.status = "connecting";
            notify_indicator_status();
            window.WEBSOCKET.retry_connection();
        }
    };
    window.addEventListener("online", try_revive);
    window.addEventListener("focus", try_revive);
}

export function can_send_to_julia() {
    return CONNECTION.status === "open";
}

export function is_julia_responsive(){
    return Date.now() - CONNECTION.lastPing < 2 * PING_INTERVAL
}

export function send_to_julia(message) {
    const { send_message, status, compression_enabled } = CONNECTION;
    if (send_message !== undefined && status === "open") {
        // J2: send_message (Websocket.send) returns false when the underlying
        // socket is not actually writable (dead/half-open TCP where nothing has
        // flipped our status yet). Re-queue instead of dropping the message, and
        // flip status so subsequent sends queue too until we reconnect.
        const sent = send_message(encode_binary(message, compression_enabled));
        if (sent === false || sent === undefined) {
            CONNECTION.queue.push(message);
            if (CONNECTION.status === "open") {
                CONNECTION.status = "closed";
                notify_indicator_status();
                arm_reconnect_triggers();
            }
        }
    } else if (status === "no_connection") {
        // Static/offline mode: there is no Julia server to talk to.
        console.log("Trying to send messages while in no_connection (static) mode");
    } else {
        // J3: "connecting" or "closed" (post give-up) — keep the message so it
        // can be replayed once the connection is (re)established. The queue is
        // swapped out and flushed in on_connection_open.
        CONNECTION.queue.push(message);
    }
}

export function send_pingpong() {
    send_to_julia({ msg_type: PingPong });
}

let timeout = null;
function send_pings() {
    clearTimeout(timeout)
    if (!can_send_to_julia()) {
        return
    }
    send_pingpong()
    timeout = setTimeout(send_pings, PING_INTERVAL)
}



export function send_error(message, exception) {
    console.error(message);
    console.error(exception);
    send_to_julia({
        msg_type: JavascriptError,
        message: message,
        exception: String(exception),
        stacktrace: exception === null ? "" : clean_stack(exception.stack),
    });
}

export function send_warning(message) {
    console.warn(message);
    send_to_julia({
        msg_type: JavascriptWarning,
        message: message,
    });
}

/**
 * @param {string} session
 */
export function send_done_loading(session, exception) {
    send_to_julia({
        msg_type: JSDoneLoading,
        session,
        message: "",
        exception: exception === null ? "nothing" : String(exception),
        stacktrace: exception === null ? "" : clean_stack(exception.stack),
    });
}

export function send_close_session(session, subsession) {
    send_to_julia({
        msg_type: CloseSession,
        session,
        subsession,
    });
}

export function process_message(data) {
    try {
        switch (data.msg_type) {
            case UpdateObservable: {
                // A late UpdateObservable can arrive for an object the browser
                // already freed (a sub closed during a DOM swap, or an
                // evaljs_value result landing after its comm was freed) while
                // the server was still sending. That's a benign race — drop it
                // instead of crashing on `null.notify`. `warn=false` keeps it
                // quiet; the "Key not found" warning is reserved for real bugs.
                const observable = lookup_global_object(data.id, false);
                observable && observable.notify(data.payload, true);
                break;
            }
            case OnjsCallback:
                // register a callback that will executed on js side
                // when observable updates
                data.obs.on(data.payload());
                break;
            case EvalJavascript:
                // javascript functions will get deserialized to a function, which we now just call to eval the code!
                data.payload();
                break;
            case FusedMessage:
                data.payload.forEach(process_message);
                break;
            case PingPong:
                // just getting a ping, nothing to do here :)
                console.debug("ping");
                CONNECTION.lastPing = Date.now()
                break;
            case UpdateSession:
                update_session_dom(data);
                break;
            default:
                throw new Error(
                    "Unrecognized message type: " + data.msg_type + "."
                );
        }
    } catch (e) {
        send_error(`Error while processing message ${JSON.stringify(data)}`, e);
    }
}

export {
    UpdateObservable,
    OnjsCallback,
    EvalJavascript,
    JavascriptError,
    JavascriptWarning,
    RegisterObservable,
    JSDoneLoading,
    FusedMessage,
    ConnectionStatus
};
