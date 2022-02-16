import { deserialize_js, decode_binary, encode_binary } from "./Protocol";

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
};

export function set_message_callback(f) {
    CONNECTION.send_message = f;
}

export function sent_message(message) {
    CONNECTION.send_message(encode_binary(message));
}

export function send_error(message, exception) {
    console.error(message);
    console.error(exception);
    sent_message({
        msg_type: JavascriptError,
        message: message,
        exception: String(exception),
        stacktrace: exception == null ? "" : exception.stack,
    });
}

export function send_warning(message) {
    console.warn(message);
    sent_message({
        msg_type: JavascriptWarning,
        message: message,
    });
}

export function sent_done_loading() {
    sent_message({
        msg_type: JSDoneLoading,
        exception: "null",
    });
}

export function process_message(data) {
    const data = decode_binary(data);
    try {
        switch (data.msg_type) {
            case UpdateObservable:
                const value = deserialize_js(data.payload);
                registered_observables[data.id] = value;
                // update all onjs callbacks
                run_js_callbacks(data.id, value);
                break;
            case RegisterObservable:
                registered_observables[data.id] = deserialize_js(data.payload);
                break;
            case OnjsCallback:
                // register a callback that will executed on js side
                // when observable updates
                const id = data.id;
                const f = deserialize_js(data.payload)();
                on_update(id, f);
                break;
            case EvalJavascript:
                const eval_closure = deserialize_js(data.payload);
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
