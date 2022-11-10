import { encode_binary } from "./Protocol.js";
import { lookup_observable } from "./Sessions.js";

// Save some bytes by using ints for switch variable
const UpdateObservable = "0";
const OnjsCallback = "1";
const EvalJavascript = "2";
const JavascriptError = "3";
const JavascriptWarning = "4";
const RegisterObservable = "5";
const JSDoneLoading = "8";
const FusedMessage = "9";

const CONNECTION = {
    send_message: undefined,
    connection_open_callback: undefined,
    queue: [],
    status: "closed",
};

/*
Registers a callback that gets called
*/
export function register_on_connection_open(callback, session_id) {
    CONNECTION.connection_open_callback = function () {
        // `callback` CAN return a promise. If not, we turn it into one!
        const promise = Promise.resolve(callback())
        // once the callback promise resolves, we're FINALLY done and call done_loading
        // which will signal the Julia side that EVERYTHING is set up!
        promise.then(() => sent_done_loading(session_id))
    }
}

export function on_connection_open(send_message_callback) {
    CONNECTION.send_message = send_message_callback;
    CONNECTION.status = "open";
    // Once connection open, we send all messages that have queued up
    CONNECTION.queue.forEach((message) => send_to_julia(message));
    // then we signal, that our connection is open and unqueued, which can run further callbacks!
    CONNECTION.connection_open_callback()
}

export function on_connection_close() {
    CONNECTION.status = "closed";
}

export function send_to_julia(message) {
    const {send_message, status} = CONNECTION;
    if (send_message && status === "open") {
        send_message(encode_binary(message));
    } else if (status === "closed") {
        CONNECTION.queue.push(message);
    } else {
        console.log("Trying to send messages while connection is offline");
    }
}

export function send_error(message, exception) {
    console.error(message);
    console.error(exception);
    send_to_julia({
        msg_type: JavascriptError,
        message: message,
        exception: String(exception),
        stacktrace: exception == null ? "" : exception.stack,
    });
}

export function send_warning(message) {
    console.warn(message);
    send_to_julia({
        msg_type: JavascriptWarning,
        message: message,
    });
}

export function sent_done_loading(session_id) {
    console.log("done loading")
    send_to_julia({
        msg_type: JSDoneLoading,
        session: session_id,
        exception: "null",
    });
}

export function process_message(data) {
    try {
        switch (data.msg_type) {
            case UpdateObservable:
                // this is a bit annoying...Better would be to let deserialization look up the observable
                // and just do data.observable.notify
                // But this is more efficient, which matters for such hot function (i think, lol)
                const observable = lookup_observable(data.id);
                observable.notify(data.payload, true);
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
};
