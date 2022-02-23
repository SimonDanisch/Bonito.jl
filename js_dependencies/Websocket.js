
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

function isopen() {
    if (session_websocket.length === 0) {
        return false;
    }
    if (session_websocket[0]) {
        return session_websocket[0].readyState === 1;
    }
    return false;
}

function websocket_send(binary_data) {
    const has_conenction = ensure_connection();
    if (has_conenction) {
        if (isopen()) {
            session_websocket[0].send(binary_data);
            return true;
        } else {
            return false;
        }
    } else {
        console.log("Websocket is null!");
        // we're in offline mode!
        return undefined;
    }
}

export function setup_connection(config_input) {
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
                JSServe.process_message(binary);
            };
            JSServe.on_connection_open(websocket_send);
        };

        websocket.onclose = function (evt) {
            console.log("closed websocket connection");
            while (session_websocket.length > 0) {
                session_websocket.pop();
            }
            JSServe.on_connection_close();
            console.log("Wesocket close code: " + evt.code);
        };
        websocket.onerror = function (event) {
            console.error("WebSocket error observed:" + event);
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
    let config = config_input;
    if (!config) {
        config = websocket_config;
    } else {
        websocket_config = config_input;
    }

    const { session_id, proxy_url } = config;

    const url = websocket_url(session_id, proxy_url);
    tryconnect(url);
}
