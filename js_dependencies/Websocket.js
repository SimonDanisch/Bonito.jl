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
        console.log(`tries: ${this.#tries}`);
        if (this.#websocket) {
            this.#websocket.close();
            this.#websocket = undefined;
        }
        const ws = new WebSocket(this.url);
        ws.binaryType = "arraybuffer";
        this.#websocket = ws;
        const this_ws = this;
        const retryInABit = setTimeout(this_ws.tryconnect, (this.#tries % 17) * 500)
        ws.onopen = function () {
            clearTimeout(retryInABit)
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
                    Bonito.lock_loading(() => {
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
        };

        ws.onclose = function (evt) {
            console.log("closed websocket connection");
            this_ws.#websocket = undefined;
            Bonito.on_connection_close();
            console.log("Wesocket close code: " + evt.code);
            console.log(evt);
            setTimeout(
                () => this_ws.tryconnect(),
                (this_ws.tries % 17) * 500
            );
        };

        ws.onerror = function (event) {
            console.error("WebSocket error observed:");
            console.log(event);
            console.log(this_ws.tries);
            this_ws.tries = this_ws.tries + 1;
            console.log(
                "Retrying to connect the " + this_ws.tries + " time!"
            );
            setTimeout(() => this_ws.tryconnect(), (this_ws.tries % 17) * 500);
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


/**
 * @param {string} session_id
 * @param {string} proxy_url
 */
function websocket_url(session_id, proxy_url) {
    // something like http://127.0.0.1:8081/
    let http_url = window.location.protocol + "//" + window.location.host;
    console.log(proxy_url)
    if (proxy_url !== "./") {
        console.log(proxy_url)
        http_url = proxy_url;
    }
    console.log(http_url)
    let ws_url = http_url.replace("http", "ws");
    // now should be like: ws://127.0.0.1:8081/
    if (!ws_url.endsWith("/")) {
        ws_url = ws_url + "/";
    }
    return ws_url + session_id;
}

export function setup_connection({
    proxy_url,
    session_id,
    compression_enabled,
    query,
    main_connection
}) {
    const url = websocket_url(session_id, proxy_url);
    console.log(`connecting : ${url + query}`);
    const ws = new Websocket(url + query, compression_enabled);
    if (main_connection) {
        ws.on_open(() => {
            Bonito.on_connection_open(
                (binary) => ws.send(binary),
                compression_enabled
            );
        });
    }
}
