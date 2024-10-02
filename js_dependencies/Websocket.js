class Websocket {

    /**
     * @type {WebSocket | undefined}
     * @description A private WebSocket instance used for managing WebSocket connections.
     */
    #websocket = undefined;

    #tries = 0;
    #onopen_callbacks = [];

    url = "";
    compression_enabled = false;

    /**
     * @param {string} url
     * @param {boolean} compression_enabled
     */
    constructor(url, compression_enabled) {
        this.tries = 0;
        this.url = url;
        this.compression_enabled = compression_enabled;
        this.tryconnect();
    }

    on_open(f) {
        this.#onopen_callbacks.push(f);
    }

    tryconnect() {
        console.log(`tries; ${this.#tries}`);
        if (this.#websocket) {
            this.#websocket.close();
            this.#websocket = undefined;
        }
        const ws = new WebSocket(this.url);
        ws.binaryType = "arraybuffer";
        this.#websocket = ws;
        const this_ws = this;
        ws.onopen = function () {
            console.log("CONNECTED!!: ", this_ws.url);
            this_ws.#tries = 0; // reset tries

            this_ws.#onopen_callbacks.forEach((f) => f());

            ws.onmessage = function (evt) {
                // run this async... (or do we?)
                new Promise((resolve) => {
                    const binary = new Uint8Array(evt.data);
                    if (binary.length === 1 && binary[0] === 0) {
                        // test write
                        return resolve(null);
                    }
                    Bonito.OBJECT_FREEING_LOCK.lock(() => {
                        Bonito.process_message(
                            Bonito.decode_binary(
                                binary,
                                this_ws.compression_enabled
                            )
                        );
                    });
                    return resolve(null);
                });
            };

            send_pings();
        };

        ws.onclose = function (evt) {
            console.log("closed websocket connection");
            this_ws.#websocket = undefined;
            Bonito.on_connection_close();
            console.log("Wesocket close code: " + evt.code);
            console.log(evt);
        };

        ws.onerror = function (event) {
            console.error("WebSocket error observed:");
            console.log(event);
            console.log(this_ws.tries);
            if (this_ws.tries <= 10) {
                while (session_websocket.length > 0) {
                    session_websocket.pop();
                }
                this_ws.tries = this_ws.tries + 1;
                console.log(
                    "Retrying to connect the " + this_ws.tries + " time!"
                );
                setTimeout(() => this_ws.tryconnect(), 1000);
            } else {
                // ok, we really cant connect and are offline!
                this_ws.#websocket = undefined;
            }
        };
    }

    ensure_connection() {
        const ws = this.#websocket;
        if (!ws) {
            console.log("No websocket");
            // try to connect again!
            this.tryconnect();
            // check if we have a connection now!
            if (!this.#websocket) {
                console.log(
                    "No websocket after connect. We assume server is offline"
                );
                return "offline";
            } else {
                return this.isopen() ? "ok" : "offline";
            }
        } else {
            if (this.isopen()) {
                return "ok";
            } else {
                // session_websocket.length != 0 && !isopen()
                // so we pop the closed connection, and try again!
                this.#websocket = undefined;
                return this.ensure_connection();
            }
        }
    }
    isopen() {
        if (!this.#websocket) {
            return false;
        }
        return this.#websocket.readyState === 1;
    }

    send(binary_data) {
        const status = this.ensure_connection();
        if (status === "ok") {
            if (this.#websocket && this.isopen()) {
                this.#websocket.send(binary_data);
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
}


function send_pings() {
    console.debug("pong")
    Bonito.send_pingpong()
    setTimeout(send_pings, 5000)
}

/**
 * @param {string} session_id
 * @param {string} proxy_url
 */
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
    return ws_url + session_id;
}

const session_websocket = {};

// function setup_connection({ proxy_url, session_id, compression_enabled }) {
//     const low_latency_url = websocket_url(session_id, proxy_url) + "/low_latency"
//     const large_data = websocket_url(session_id, proxy_url) + "/large_data";
//     session_websocket.low_latency = new Websocket(low_latency_url, compression_enabled);
//     session_websocket.large_data = new Websocket(large_data, compression_enabled);
// }
export function setup_connection({ proxy_url, session_id, compression_enabled }) {
    const url = websocket_url(session_id, proxy_url);
    const ws_low = new Websocket(url + "?low_latency", compression_enabled);
    const large_data = new Websocket(url + "?large_data", compression_enabled);
    session_websocket.low_latency = ws_low;
    session_websocket.large_data = large_data;
    ws_low.on_open(()=> {
        Bonito.on_connection_open(send_websocket, compression_enabled);
    })
}

function send_websocket(binary) {
    const ws = session_websocket.low_latency;
    if (!ws) {
        return undefined;
    } else {
        return ws.send(binary);
    }
}
