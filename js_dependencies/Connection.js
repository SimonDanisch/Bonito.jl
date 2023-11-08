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

const CONNECTION = {
    send_message: undefined,
    queue: [],
    status: "closed",
};

export function on_connection_open(send_message_callback, compression_enabled) {
    CONNECTION.send_message = send_message_callback;
    CONNECTION.status = "open";
    CONNECTION.compression_enabled = compression_enabled;
    // Once connection open, we send all messages that have queued up
    CONNECTION.queue.forEach((message) => send_to_julia(message));
}

export function on_connection_close() {
    CONNECTION.status = "closed";
}

export function can_send_to_julia() {
    return CONNECTION.status === "open";
}

export function send_to_julia(message) {
    const { send_message, status, compression_enabled } = CONNECTION;
    if (send_message && status === "open") {
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

export function send_error(message, exception) {
    console.error(message);
    console.error(exception);
    send_to_julia({
        msg_type: JavascriptError,
        message: message,
        exception: String(exception),
        stacktrace: exception === null ? "" : exception.stack,
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
        stacktrace: exception === null ? "" : exception.stack,
    });
}

export function send_close_session(session, subsession) {
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
        this.locking_tasks = new Set();
    }
    unlock() {
        this.locked = false;
        if (this.queue.length > 0) {
            const job = this.queue.pop();
            // this will call unlock after its finished and work through the queue like that
            this.lock(job);
        }
    }
    /**
     * @param {string} task_id
     */
    task_lock(task_id) {
        this.locked = true
        this.locking_tasks.add(task_id)
    }
    task_unlock(task_id) {
        this.locking_tasks.delete(task_id);
        if (this.locking_tasks.size == 0){
            this.unlock()
        }
    }
    lock(func) {
        return new Promise(resolve=> {
            if (this.locked) {
                const func_res = ()=> Promise.resolve(func()).then(resolve);
                this.queue.push(func_res);
            } else {
                this.locked = true;
                // func may return a promise that needs resolved first
                Promise.resolve(func()).then((x) => {
                    this.unlock()
                    resolve(x)
                });
            }
        })
    }
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
