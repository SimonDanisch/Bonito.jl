
const session_websocket = [];
let websocket_config = undefined;

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
    return ws_url + session_id + "/";
}

function ensure_connection() {
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
                session_websocket[0].send(msg_encode(data));
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
    let websocket;
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
