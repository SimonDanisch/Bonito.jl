const registered_observables = {};
const observable_callbacks = {};

function run_js_callbacks(id, value) {
    if (id in observable_callbacks) {
        const callbacks = observable_callbacks[id];
        const deregister_calls = [];
        for (const i in callbacks) {
            // onjs can return false to deregister itself
            try {
                const register = callbacks[i](value);
                if (register == false) {
                    deregister_calls.push(i);
                }
            } catch (exception) {
                send_error(
                    "Error during running onjs callback\n" +
                        "Callback:\n" +
                        callbacks[i].toString(),
                    exception
                );
            }
        }
        deregister_calls.forEach((cb) => {
            callbacks.splice(cb, 1);
        });
    }
}

function get_observable(id) {
    if (id in registered_observables) {
        return registered_observables[id];
    } else {
        throw "Can't find observable with id: " + id;
    }
}

function delete_observables(ids) {
    ids.forEach((id) => {
        delete registered_observables[id];
        delete observable_callbacks[id];
    });
}

function update_obs(id, value) {
    if (id in registered_observables) {
        try {
            registered_observables[id] = value;
            // call onjs callbacks
            run_js_callbacks(id, value);
            // update Julia side!
            websocket_send({
                msg_type: UpdateObservable,
                id: id,
                payload: value,
            });
        } catch (exception) {
            send_error(
                "Error during update_obs with observable " + id,
                exception
            );
        }
        return true;
    } else {
        send_error(`
                Observable with id ${id} can't be updated because it's not registered.
            `);
    }
}

function on_update(observable_id, callback) {
    const callbacks = observable_callbacks[observable_id] || [];
    callbacks.push(callback);
    observable_callbacks[observable_id] = callbacks;
}
