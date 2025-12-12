import { send_to_julia, UpdateObservable, send_error } from "./Connection.js";

class Observable {
    #callbacks = [];

    /**
     * @param {string} id
     * @param {any} value
     */
    constructor(id, value) {
        this.id = id;
        this.value = value;
    }
    /**
     * @param {any} value
     * @param {boolean} dont_notify_julia
     */
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

    /**
     * @param {any} callback
     */
    on(callback) {
        this.#callbacks.push(callback);
    }
}

export function onany(observables, f) {
    const callback = (x)=> f(observables.map(x=> x.value))
    observables.forEach(obs => {
        obs.on(callback);
    })
}

export { Observable };
