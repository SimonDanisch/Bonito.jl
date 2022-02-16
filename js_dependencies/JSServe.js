import { process_message, set_message_callback } from "./Connection";

const loaded_es6_modules = {};

async function load_module_from_bytes(key, code_ui8_array) {
    const js_module_promise = new Promise((r) => {
        const reader = new FileReader();
        reader.onload = async () => r(await import(reader.result));
        reader.readAsDataURL(
            new Blob([code_ui8_array], { type: "text/javascript" })
        );
    });

    const module = await js_module_promise;
    loaded_es6_modules[key] = module;
    return module;
}

function load_module_from_key(key) {
    const module = loaded_es6_modules[key];
    if (!module) {
        throw `Module with key ${key} not found`;
    }
    return module
}

const JSServe = {
    set_message_callback,
    process_message,
    deserialize_js,
    get_observable,
    on_update,
    delete_observables,
    send_warning,
    send_error,
    setup_connection,
    sent_done_loading,
    update_obs,
    update_node_attribute,
    is_list,
    registered_observables,
    observable_callbacks,
    session_object_cache,
    track_deleted_sessions,
    register_sub_session,
    update_dom_node,
    resize_iframe_parent,
    update_cached_value,
    init_from_b64,
    materialize_node,
};

window.update_obs = update_obs;

export {
    deserialize_js,
    get_observable,
    on_update,
    delete_observables,
    send_warning,
    send_error,
    setup_connection,
    sent_done_loading,
    update_obs,
    update_node_attribute,
    is_list,
    registered_observables,
    observable_callbacks,
    session_object_cache,
    track_deleted_sessions,
    register_sub_session,
    update_dom_node,
    resize_iframe_parent,
    update_cached_value,
    init_from_b64,
    process_message,
    materialize_node,
};
