import { decode_binary_message, encode_binary } from "./Protocol.js";
import { lookup_globally } from './Sessions.js'

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
    queue: [],
    status: "closed",
};

export function on_connection_open(send_message_callback) {
    CONNECTION.send_message = send_message_callback;
    CONNECTION.status = "open";
    CONNECTION.queue.forEach((message) => send_to_julia(message));
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

export function sent_done_loading() {
    send_to_julia({
        msg_type: JSDoneLoading,
        exception: "null",
    });
}

export async function process_message(binary_or_string) {
    const data = await decode_binary_message(binary_or_string);
    try {
        switch (data.msg_type) {
            case UpdateObservable:
                const observable = lookup_globally(data.id);
                observable.notify(payload, true);
                break;
            case RegisterObservable:
                registered_observables[data.id] = data.payload;
                break;
            case OnjsCallback:
                // register a callback that will executed on js side
                // when observable updates
                on_update(data.id, data.payload());
                break;
            case EvalJavascript:
                const eval_closure = data.payload;
                eval_closure();
                break;
            case FusedMessage:
                const messages = data.payload;
                messages.forEach(process_message);
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
