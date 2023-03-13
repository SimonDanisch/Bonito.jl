// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

const session_websocket = [];
function websocket_url(session_id, proxy_url) {
    let http_url = window.location.protocol + "//" + window.location.host;
    if (proxy_url) {
        http_url = proxy_url;
    }
    let ws_url = http_url.replace("http", "ws");
    if (!ws_url.endsWith("/")) {
        ws_url = ws_url + "/";
    }
    return ws_url + session_id;
}
function ensure_connection() {
    if (session_websocket.length == 0) {
        console.log("Length of websocket 0");
        setup_connection();
        if (session_websocket.length == 0) {
            console.log("Length of websocket 0 after setup_connection. We assume server is offline");
            var popup = document.getElementById("WEBSOCKET_CONNECTION_WARNING");
            if (!popup) {
                const doc_root = document.getElementById("application-dom");
                const popup1 = document.createElement("div");
                popup1.id = "WEBSOCKET_CONNECTION_WARNING";
                popup1.innerText = "Lost connection to server!";
                doc_root.appendChild(popup1);
            }
            return 'offline';
        } else {
            return isopen() ? 'ok' : 'offline';
        }
    } else {
        if (isopen()) {
            return 'ok';
        } else {
            session_websocket.pop();
            return ensure_connection();
        }
    }
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
    const status = ensure_connection();
    if (status === 'ok') {
        if (isopen()) {
            session_websocket[0].send(binary_data);
            return true;
        } else {
            return false;
        }
    } else {
        console.log("Websocket is null!");
        return undefined;
    }
}
function send_pings() {
    console.log("pong");
    JSServe.send_pingpong();
    setTimeout(send_pings, 5000);
}
function setup_connection(config) {
    let tries = 0;
    let websocket;
    function tryconnect(url) {
        console.log(`tries; ${tries}`);
        if (session_websocket.length != 0) {
            const old_ws = session_websocket.pop();
            old_ws.close();
        }
        websocket = new WebSocket(url);
        websocket.binaryType = "arraybuffer";
        session_websocket.push(websocket);
        websocket.onopen = function() {
            console.log("CONNECTED!!: ", url);
            tries = 0;
            websocket.onmessage = function(evt) {
                new Promise((resolve)=>{
                    const binary = new Uint8Array(evt.data);
                    if (binary.length === 1 && binary[0] === 0) {
                        return resolve(null);
                    }
                    JSServe.process_message(JSServe.decode_binary(binary, config.compression_enabled));
                    return resolve(null);
                });
            };
            JSServe.on_connection_open(websocket_send, config.compression_enabled);
            send_pings();
        };
        websocket.onclose = function(evt) {
            console.log("closed websocket connection");
            while(session_websocket.length > 0){
                session_websocket.pop();
            }
            JSServe.on_connection_close();
            console.log("Wesocket close code: " + evt.code);
            console.log(evt);
        };
        websocket.onerror = function(event) {
            console.error("WebSocket error observed:");
            console.log(event);
            console.log(tries);
            if (tries <= 10) {
                while(session_websocket.length > 0){
                    session_websocket.pop();
                }
                tries = tries + 1;
                console.log("Retrying to connect the " + tries + " time!");
                setTimeout(()=>tryconnect(url), 1000);
            } else {
                session_websocket.push(null);
            }
        };
    }
    const { session_id , proxy_url  } = config;
    const url = websocket_url(session_id, proxy_url);
    tryconnect(url);
}
export { setup_connection as setup_connection };

