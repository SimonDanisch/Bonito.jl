import { send_to_julia, UpdateObservable, send_error } from "./Connection.js";

class Observable {
    #callbacks = [];
    constructor(id, value) {
        this.id = id;
        this.value = value;
    }
    notify(value, dont_notify_julia) {
        this.value = value;
        this.#callbacks.forEach((callback) => {
            try {
                const deregister = callback(value);
                if (deregister == false) {
                    this.#callbacks.splice(
                        this.#callbacks.indexOf(callback),
                        1
                    );
                }
            } catch (exception) {
                send_error(
                    "Error during running onjs callback\n" +
                        "Callback:\n" +
                        callback.toString(),
                    exception
                );
            }
        });
        if (!dont_notify_julia) {
            send_to_julia({
                msg_type: UpdateObservable,
                id: this.id,
                payload: value,
            });
        }
    }
    on(callback) {
        this.#callbacks.push(callback);
    }
}

export { Observable };
