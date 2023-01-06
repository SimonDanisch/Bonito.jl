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
        const promise = Promise.resolve(callback());
        // once the callback promise resolves, we're FINALLY done and call done_loading
        // which will signal the Julia side that EVERYTHING is set up!
        promise.then(() => send_done_loading(session_id));
    };
}

export function on_connection_open(send_message_callback) {
    CONNECTION.send_message = send_message_callback;
    CONNECTION.status = "open";
    // Once connection open, we send all messages that have queued up
    CONNECTION.queue.forEach((message) => send_to_julia(message));
    // then we signal, that our connection is open and unqueued, which can run further callbacks!
    CONNECTION.connection_open_callback();
}

export function on_connection_close() {
    CONNECTION.status = "closed";
}

export function send_to_julia(message) {
    const { send_message, status } = CONNECTION;
    if (send_message && status === "open") {
        send_message(encode_binary(message));
    } else if (status === "closed") {
        CONNECTION.queue.push(message);
    } else {
        console.log("Trying to send messages while connection is offline");
    }
}

export function send_pingpong() {
    send_to_julia({ msg_type: PingPong });
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

export function send_done_loading(session) {
    send_to_julia({
        msg_type: JSDoneLoading,
        session,
        exception: "null",
    });
}

export function send_close_session(session, subsession) {
    console.log(`closing ${session}`);
    send_to_julia({
        msg_type: CloseSession,
        session,
        subsession,
    });
}

// JS DOESN't HAVE LOCKS ?????
export class Lock {
    constructor() {
        this.locked = false;
        this.queue = [];
    }
    unlock() {
        this.locked = false;
        if (this.queue.length > 0) {
            const job = this.queue.pop();
            // this will call unlock after its finished and work through the queue like that
            this.lock(job);
        }
    }
    lock(func) {
        if (this.locked) {
            return this.queue.push(func);
        } else {
            this.locked = true;
            // func may return a promise that needs resolved first
            return Promise.resolve(func()).then((x) => this.unlock());
        }
    }
}

const MESSAGE_PROCESS_LOCK = new Lock();

// Makes sure, we process all messages in order... Used in initilization in session.jl
export function with_message_lock(func) {
    MESSAGE_PROCESS_LOCK.lock(func);
}

export function process_message(data) {
    if (!data) {
        // there are messages, that will be processed in Sessions.js (e.g. `update_session_dom`).
        // in that case, `deserialize_cached` will return null, which is then fed by the connection into process_message
        return; // in that case we ignore the message
    }
    try {
        switch (data.msg_type) {
            case UpdateObservable:
                // this is a bit annoying...Better would be to let deserialization look up the observable
                // and just do data.observable.notify
                // But this is more efficient, which matters for such hot function (i think, lol)
                const observable = lookup_global_object(data.id);
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
            case PingPong:
                // just getting a ping, nothing to do here :)
                console.debug("ping");
                break;
            case "UpdateSession":
                // just getting a ping, nothing to do here :)
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
};
