class Websocket {
    /**
     * @type {WebSocket | undefined}
     * @description A private WebSocket instance used for managing WebSocket connections.
     */
    #websocket = undefined;

    #onopen_callbacks = [];
    #is_retrying = false;
    #retry_timeout_id = null;

    url = "";
    compression_enabled = false;

    /**
     * @param {string} url
     * @param {boolean} compression_enabled
     */
    constructor(url, compression_enabled) {
        this.url = url;
        this.compression_enabled = compression_enabled;
        this.tryconnect();
    }
    close() {
        if (this.#websocket) {
            this.#websocket.close();
        } else {
            console.log("No websocket to close");
        }
    }
    on_open(f) {
        this.#onopen_callbacks.push(f);
    }

    retry_connection(total_time_seconds = 30) {
        if (this.#is_retrying) {
            console.log("Already retrying connection");
            return;
        }
        if (this.isopen()) {
            return;
        }

        this.#cleanup_websocket(); // Clean up existing websocket
        this.#is_retrying = true;

        // Clear any existing retry timeout
        if (this.#retry_timeout_id) {
            clearTimeout(this.#retry_timeout_id);
            this.#retry_timeout_id = null;
        }

        const start_time = Date.now();
        const total_time_ms = total_time_seconds * 1000;
        let attempt = 0;
        let delay = 1000; // Start with 1 second
        const max_delay = 10000; // Cap at 10 seconds
        const self = this;

        function give_up() {
            console.log(
                `Giving up after ${total_time_seconds}s and ${attempt} attempts`
            );
            if (self.#retry_timeout_id) {
                clearTimeout(self.#retry_timeout_id);
                self.#retry_timeout_id = null;
            }
            self.#cleanup_websocket();
            self.#is_retrying = false; // Reset flag
            Bonito.on_connection_close();
        }

        function attempt_connection() {
            // Check if we're out of time
            if (self.isopen()) {
                self.#is_retrying = false; // Reset retry flag
                if (self.#retry_timeout_id) {
                    clearTimeout(self.#retry_timeout_id);
                    self.#retry_timeout_id = null;
                }
                console.log("Connection successful!");
                return; // Exit successfully
            }
            const elapsed = Date.now() - start_time;
            if (elapsed >= total_time_ms) {
                give_up();
                return; // Stop trying
            }
            attempt++;
            console.log(`Connection attempt ${attempt}`);
            if (self.#websocket === undefined) {
                self.tryconnect();
            } else if (self.#websocket.readyState === WebSocket.CLOSED) {
                // If the websocket is closed, try to reconnect
                self.tryconnect();
            } else if (self.#websocket.readyState === WebSocket.CONNECTING) {
                // If it's still connecting, just wait
                console.log("WebSocket is still connecting...");
            }
            // Only schedule next attempt if we haven't succeeded and have time left
            if (!self.isopen() && (Date.now() - start_time) < total_time_ms) {
                console.log(`Waiting ${delay / 1000}s before retry...`);
                self.#retry_timeout_id = setTimeout(attempt_connection, delay);
                delay = Math.min(delay * 2, max_delay);
            }
        }

        // Start the first attempt immediately
        attempt_connection();
    }

    tryconnect() {
        const ws = new WebSocket(this.url);
        ws.binaryType = "arraybuffer";
        this.#websocket = ws;
        const this_ws = this;

        ws.onopen = function () {
            console.log("CONNECTED!!: ", this_ws.url);
            this_ws.#onopen_callbacks.forEach((f) => f());

            ws.onmessage = function (evt) {
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
            console.log("closed websocket connection, code:", evt.code);
            console.log(evt);
            // Only retry if not already retrying
            if (!this_ws.#is_retrying) {
                this_ws.retry_connection();
            }
        };

        ws.onerror = function (event) {
            console.error("WebSocket error observed:");
            console.log(event);
            // Let onclose handle the retry to avoid double retries
        };
    }

    ensure_connection() {
        const ws = this.#websocket;
        if (!ws) {
            console.log("No websocket");
            this.retry_connection();
            return "connecting";
        } else {
            if (this.isopen()) {
                return "ok";
            } else {
                // Connection exists but isn't open
                if (ws.readyState === WebSocket.CONNECTING) {
                    return "connecting";
                } else {
                    // Connection is closed/failed, clean up and try again
                    this.#cleanup_websocket();
                    this.retry_connection();
                    return "connecting";
                }
            }
        }
    }

    #cleanup_websocket() {
        if (this.#websocket) {
            // Remove event listeners to prevent memory leaks
            this.#websocket.onopen = null;
            this.#websocket.onclose = null;
            this.#websocket.onerror = null;
            this.#websocket.onmessage = null;

            // Close if still open
            if (this.#websocket.readyState === WebSocket.OPEN ||
                this.#websocket.readyState === WebSocket.CONNECTING) {
                this.#websocket.close();
            }

            this.#websocket = undefined;
        }
    }

    isopen() {
        if (!this.#websocket) {
            return false;
        }
        return this.#websocket.readyState === WebSocket.OPEN;
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
        } else if (status === "connecting") {
            console.log("Websocket is connecting, message queued/dropped");
            return false;
        } else {
            console.log("Websocket is offline!");
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
    if (proxy_url !== "./") {
        http_url = proxy_url;
    }
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
    main_connection,
}) {
    // TODO why does this make the tests hang?
    // Detect tab duplication using BroadcastChannel.
    // When a tab is duplicated, both tabs have the same session_id embedded in HTML.
    // We use BroadcastChannel to detect if another tab is already using this session.
    // if (BroadcastChannel) {
    //     const channel = new BroadcastChannel(`bonito_session_${session_id}`);
    //     // Handle messages from other tabs
    //     channel.onmessage = (event) => {
    //         console.log("BroadcastChannel message received:", event.data);
    //         if (event.data === "session_in_use") {
    //             // Another tab already owns this session - we're a duplicate
    //             console.log(
    //                 "Detected duplicated tab (another tab owns this session), reloading..."
    //             );
    //             channel.close();
    //             window.location.reload();
    //         } else if (event.data === "who_owns_session") {
    //             // Another tab is asking - we own this session, tell them
    //             channel.postMessage("session_in_use");
    //         }
    //     };
    //     // Ask if any other tab is using this session
    //     channel.postMessage("who_owns_session");
    // }

    const url = websocket_url(session_id, proxy_url);
    console.log(`connecting : ${url + query}`);
    const ws = new Websocket(url + query, compression_enabled);
    window.WEBSOCKET = ws;
    if (main_connection) {
        ws.on_open(() => {
            Bonito.on_connection_open(
                (binary) => ws.send(binary),
                compression_enabled
            );
        });
    }
}
