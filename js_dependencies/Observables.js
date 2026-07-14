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
        // J15: iterate a snapshot. A callback that returns false deregisters
        // itself (splice from this.#callbacks); mutating the array we're
        // iterating with forEach would skip the immediately-following listener.
        // Collect the callbacks to remove and splice them afterwards.
        const callbacks = this.#callbacks.slice();
        const to_remove = [];
        callbacks.forEach((callback) => {
            try {
                const deregister = callback(value);
                if (deregister == false) {
                    to_remove.push(callback);
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
        to_remove.forEach((callback) => {
            const idx = this.#callbacks.indexOf(callback);
            if (idx !== -1) {
                this.#callbacks.splice(idx, 1);
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
