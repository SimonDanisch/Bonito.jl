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
 * @property {string} connectionType - Type of connection being used.
 */
const CONNECTION = {
    send_message: undefined,
    queue: [],
    status: "closed",
    compression_enabled: false,
    lastPing: Date.now(),
    indicator: null,
    connectionType: "websocket",
    transferring: false
};

/**
 * Register a connection indicator object.
 * The indicator should implement: onStatusChange(status, connectionType)
 * and optionally: onDataTransfer(isTransferring)
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
 * Set the connection type (for NoConnection support)
 * @param {string} connectionType - Type of connection (websocket, no_connection, etc.)
 */
export function set_connection_type(connectionType) {
    CONNECTION.connectionType = connectionType;
    notify_indicator_status();
}

/**
 * Notify the indicator of the current connection status
 */
function notify_indicator_status() {
    if (CONNECTION.indicator && typeof CONNECTION.indicator.onStatusChange === 'function') {
        let status;
        if (CONNECTION.connectionType === "no_connection") {
            status = ConnectionStatus.NO_CONNECTION;
        } else if (CONNECTION.status === "open") {
            status = ConnectionStatus.CONNECTED;
        } else if (CONNECTION.status === "connecting") {
            status = ConnectionStatus.CONNECTING;
        } else {
            status = ConnectionStatus.DISCONNECTED;
        }
        CONNECTION.indicator.onStatusChange(status, CONNECTION.connectionType);
    }
}

/**
 * Notify indicator that data transfer is happening (for blinking)
 * @param {boolean} isTransferring - Whether data is currently being transferred
 */
export function notify_data_transfer(isTransferring) {
    CONNECTION.transferring = isTransferring;
    if (CONNECTION.indicator && typeof CONNECTION.indicator.onDataTransfer === 'function') {
        CONNECTION.indicator.onDataTransfer(isTransferring);
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
    // Once connection open, we send all messages that have queued up
    CONNECTION.queue.forEach((message) => send_to_julia(message));
    if (enable_pings) {
        send_pings();
    }
}

export function on_connection_close() {
    CONNECTION.status = "closed";
    notify_indicator_status();
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
        send_message(encode_binary(message, compression_enabled));
    } else if (status === "closed") {
        CONNECTION.queue.push(message);
    } else {
        console.log("Trying to send messages while connection is offline");
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
            case UpdateObservable:
                // this is a bit annoying...Better would be to let deserialization look up the observable
                // and just do data.observable.notify
                // But this is more efficient, which matters for such hot function (i think, lol)
                lookup_global_object(data.id).notify(data.payload, true);
                break;
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
