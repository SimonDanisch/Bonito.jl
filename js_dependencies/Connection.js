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
 * @namespace CONNECTION
 * @property {Function|undefined} send_message - Function to send a message. Initially undefined.
 * @property {Array} queue - Array to hold queued messages.
 * @property {string} status - Connection status, initially set to "closed".
 * @property {boolean} compression_enabled - Flag indicating if compression is enabled, initially set to false.
 */
const CONNECTION = {
    send_message: undefined,
    queue: [],
    status: "closed",
    compression_enabled: false,
    lastPing: Date.now()
};

export function on_connection_open(send_message_callback, compression_enabled, enable_pings = true) {
    CONNECTION.send_message = send_message_callback;
    CONNECTION.status = "open";
    CONNECTION.compression_enabled = compression_enabled;
    // Once connection open, we send all messages that have queued up
    CONNECTION.queue.forEach((message) => send_to_julia(message));
    if (enable_pings) {
        send_pings();
    }
}

export function on_connection_close() {
    CONNECTION.status = "closed";
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
    FusedMessage
};
