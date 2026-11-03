const JSServe = (function () {
    const registered_observables = {};
    const observable_callbacks = {};
    const session_object_cache = {};

    function update_cache({ to_remove, to_register }) {
        to_remove.forEach((x) => {
            delete session_object_cache[x];
        });
        Object.keys(to_register).forEach((k) => {
            session_object_cache[k] = deserialize_js(to_register[k]);
        });
        return;
    }

    function update_cached_value(id, new_value) {
        session_object_cache[id] = new_value;
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
    // Save some bytes by using ints for switch variable
    const UpdateObservable = "0";
    const OnjsCallback = "1";
    const EvalJavascript = "2";
    const JavascriptError = "3";
    const JavascriptWarning = "4";
    const RegisterObservable = "5";
    const JSDoneLoading = "8";
    const FusedMessage = "9";

    function resize_iframe_parent(session_id) {
        const body = document.body;
        const html = document.documentElement;
        const height = Math.max(
            body.scrollHeight,
            body.offsetHeight,
            html.clientHeight,
            html.scrollHeight,
            html.offsetHeight
        );
        const width = Math.max(
            body.scrollWidth,
            body.offsetWidth,
            html.clientWidth,
            html.scrollHeight,
            html.offsetWidth
        );
        if (parent.postMessage) {
            parent.postMessage([session_id, width, height], "*");
        }
    }

    function is_list(value) {
        return (
            value && typeof value === "object" && value.constructor === Array
        );
    }

    function is_dict(value) {
        return value && typeof value === "object";
    }

    function randhex() {
        return ((Math.random() * 16) | 0).toString(16);
    }

    // TODO use a secure library for this shit
    function rand4hex() {
        return randhex() + randhex() + randhex() + randhex();
    }

    function materialize_node(data) {
        // if is a node attribute
        if (is_list(data)) {
            return data.map(materialize_node);
        } else if (data.tag) {
            const node = document.createElement(data.tag);
            Object.keys(data).forEach((key) => {
                if (key == "class") {
                    node.className = data[key];
                } else if (key != "children" && key != "tag") {
                    node.setAttribute(key, data[key]);
                }
            });
            data.children.forEach((child) => {
                if (is_dict(child)) {
                    node.appendChild(materialize_node(child));
                } else {
                    if (data.tag == "script") {
                        node.text = child;
                    } else {
                        node.innerText = child;
                    }
                }
            });
            return node;
        } else {
            // anything else is used as is!
            return data;
        }
    }

    function deserialize_js(data) {
        if (is_list(data)) {
            return data.map(deserialize_js);
        } else if (is_dict(data)) {
            if ("__javascript_type__" in data) {
                if (data.__javascript_type__ == "TypedVector") {
                    return data.payload;
                } else if (data.__javascript_type__ == "DomNode") {
                    return document.querySelector(
                        '[data-jscall-id="' + data.payload + '"]'
                    );
                } else if (data.__javascript_type__ == "DomNodeFull") {
                    return materialize_node(data.payload);
                } else if (data.__javascript_type__ == "JSCode") {
                    const eval_func = new Function(
                        "__eval_context__",
                        data.payload.source
                    );
                    const context = deserialize_js(data.payload.context);
                    // return a closure, that when caleld evals runs the code!
                    return () => eval_func(context);
                } else if (data.__javascript_type__ == "Observable") {
                    const value = deserialize_js(data.payload.value);
                    const id = data.payload.id;
                    registered_observables[id] = value;
                    return id;
                } else if (data.__javascript_type__ == "Reference") {
                    const ref = session_object_cache[data.payload];
                    if (!ref) {
                        throw new Error(
                            `Could not dereference ${data.payload}!`
                        );
                    }
                    return ref;
                } else {
                    send_error(
                        "Can't deserialize custom type: " +
                            data.__javascript_type__,
                        null
                    );
                    return undefined;
                }
            } else {
                var result = {};
                for (var k in data) {
                    if (data.hasOwnProperty(k)) {
                        result[k] = deserialize_js(data[k]);
                    }
                }
                return result;
            }
        } else {
            return data;
        }
    }

    function send_error(message, exception) {
        console.error(message);
        console.error(exception);
        websocket_send({
            msg_type: JavascriptError,
            message: message,
            exception: String(exception),
            stacktrace: exception == null ? "" : exception.stack,
        });
    }

    function send_warning(message) {
        console.warn(message);
        websocket_send({
            msg_type: JavascriptWarning,
            message: message,
        });
    }

    function sent_done_loading() {
        websocket_send({
            msg_type: JSDoneLoading,
            exception: "null",
        });
    }

    function update_node_attribute(node, attribute, value) {
        if (node) {
            if (node[attribute] != value) {
                node[attribute] = value;
            }
            return true;
        } else {
            return false; //deregister
        }
    }

    function run_js_callbacks(id, value) {
        if (id in observable_callbacks) {
            const callbacks = observable_callbacks[id];
            const deregister_calls = [];
            for (const i in callbacks) {
                // onjs can return false to deregister itself
                try {
                    var register = callbacks[i](value);
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
            for (var i = 0; i < deregister_calls.length; i++) {
                callbacks.splice(deregister_calls[i], 1);
            }
        }
    }

    const session_websocket = [];

    function ensure_connection() {
        // we lost the connection :(
        if (offline_forever()) {
            return false;
        }

        if (session_websocket.length == 0) {
            console.log("Length of websocket 0");
            // try to connect again!
            setup_connection();
        }
        // check if we have a connection now!
        if (session_websocket.length == 0) {
            console.log(
                "Length of websocket 0 after setup_connection. We assume server is offline"
            );
            // still no connection...
            // Display a warning, that we lost conenction!
            var popup = document.getElementById("WEBSOCKET_CONNECTION_WARNING");
            if (!popup) {
                const doc_root = document.getElementById("application-dom");
                const popup = document.createElement("div");
                popup.id = "WEBSOCKET_CONNECTION_WARNING";
                popup.innerText = "Lost connection to server!";
                doc_root.appendChild(popup);
            }
            return false;
        }
        return true;
    }

    function websocket_send(data) {
        const has_conenction = ensure_connection();
        if (has_conenction) {
            if (session_websocket[0]) {
                if (session_websocket[0].readyState == 1) {
                    session_websocket[0].send(msgpack.encode(data));
                } else {
                    console.log("Websocket not in readystate!");
                    // wait until in ready state
                    setTimeout(() => websocket_send(data), 100);
                }
            } else {
                console.log("Websocket is null!");
                // we're in offline mode!
                return;
            }
        }
    }

    function update_dom_node(dom, html) {
        if (dom) {
            dom.innerHTML = html;
            return true;
        } else {
            //deregister the callback if the observable dom is gone
            return false;
        }
    }

    function process_message(data) {
        try {
            if (data.update_cache) {
                // the message comes with new cached variables, which we need to update
                // before processing any messages
                update_cache(data.update_cache);
                if (!data.data) {
                    console.log(data.update_cache);
                }
                // we allow to send empty messages, that only update the cache!
                if (data.data) {
                    process_message(data.data);
                }
                return;
            }
            switch (data.msg_type) {
                case UpdateObservable:
                    const value = deserialize_js(data.payload);
                    registered_observables[data.id] = value;
                    // update all onjs callbacks
                    run_js_callbacks(data.id, value);
                    break;
                case RegisterObservable:
                    registered_observables[data.id] = deserialize_js(
                        data.payload
                    );
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
            send_error(
                `Error while processing message ${JSON.stringify(data)}`,
                e
            );
        }
    }

    function websocket_url(session_id, proxy_url) {
        // something like http://127.0.0.1:8081/
        let http_url = window.location.protocol + "//" + window.location.host;
        if (proxy_url) {
            http_url = proxy_url;
        }
        let ws_url = http_url.replace("http", "ws");
        // now should be like: ws://127.0.0.1:8081/
        if (!ws_url.endsWith("/")) {
            ws_url = ws_url + "/";
        }
        const browser_id = rand4hex();
        ws_url = ws_url + session_id + "/" + browser_id + "/";
        return ws_url;
    }

    function decode_binary(binary) {
        return msgpack.decode(pako.inflate(binary));
    }

    function decode_string(string) {
        const binary = Base64.decode(string);
        return decode_binary(binary);
    }

    function init_from_b64(data_str_b64) {
        const message = decode_string(data_str_b64);
        process_message(message)
    }

    let websocket_config = undefined;

    function offline_forever() {
        return websocket_config && websocket_config.offline;
    }

    function setup_connection(config_input) {
        let config = config_input;

        if (!config) {
            config = websocket_config;
        } else {
            websocket_config = config_input;
        }

        const { offline, proxy_url, session_id } = config;
        // we're in offline mode, dont even try!
        if (offline) {
            console.log("OFFLINE FOREVER");
            return;
        }
        const url = websocket_url(session_id, proxy_url);
        let tries = 0;
        function tryconnect(url) {
            if (session_websocket.length != 0) {
                const old_ws = session_websocket.pop();
                old_ws.close();
            }
            websocket = new WebSocket(url);
            websocket.binaryType = "arraybuffer";
            session_websocket.push(websocket);

            websocket.onopen = function () {
                console.log("CONNECTED!!: ", url);
                websocket.onmessage = function (evt) {
                    const binary = new Uint8Array(evt.data);
                    const data = decode_binary(binary);
                    process_message(data);
                };
            };

            websocket.onclose = function (evt) {
                console.log("closed websocket connection");
                while (session_websocket.length > 0) {
                    session_websocket.pop();
                }
                if (window.dont_even_try_to_reconnect) {
                    // ok, we cant even right now and just give up
                    session_websocket.push(null);
                    return;
                }
                console.log("Wesocket close code: " + evt.code);
            };
            websocket.onerror = function (event) {
                console.error("WebSocket error observed:" + event);
                console.log(
                    "dont_even_try_to_reconnect: " +
                        window.dont_even_try_to_reconnect
                );

                if (tries <= 1) {
                    while (session_websocket.length > 0) {
                        session_websocket.pop();
                    }
                    tries = tries + 1;
                    console.log("Retrying to connect the " + tries + " time!");
                    setTimeout(() => tryconnect(url), 1000);
                } else {
                    // ok, we really cant connect and are offline!
                    session_websocket.push(null);
                }
            };
        }
        if (url) {
            tryconnect(url);
        } else {
            // we're in offline mode!
            session_websocket.push(null);
        }
    }

    const session_dom_nodes = new Set();

    function register_sub_session(session_id) {
        session_dom_nodes.add(session_id);
    }

    function track_deleted_sessions(delete_session) {
        const observer = new MutationObserver(function (mutations) {
            // observe the dom for deleted nodes,
            // and push all found removed session doms to the observable `delete_session`
            let removal_occured = false;
            const to_delete = new Set();
            mutations.forEach((mutation) => {
                mutation.removedNodes.forEach((x) => {
                    if (x.id && session_dom_nodes.has(x.id)) {
                        to_delete.add(x.id);
                    } else {
                        removal_occured = true;
                    }
                });
            });
            // removal occured from elements not matching the id!
            if (removal_occured) {
                session_dom_nodes.forEach((id) => {
                    if (!document.getElementById(id)) {
                        to_delete.add(id);
                    }
                });
            }
            to_delete.forEach((id) => {
                session_dom_nodes.delete(id);
                JSServe.update_obs(delete_session, id);
            });
        });

        observer.observe(document, {
            attributes: false,
            childList: true,
            characterData: false,
            subtree: true,
        });
    }

    return {
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
        materialize_node
    };
})();
