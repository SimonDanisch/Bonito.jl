// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

class Websocket {
    #websocket = undefined;
    #onopen_callbacks = [];
    #is_retrying = false;
    url = "";
    compression_enabled = false;
    constructor(url, compression_enabled){
        this.url = url;
        this.compression_enabled = compression_enabled;
        this.tryconnect();
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
        this.#websocket = undefined;
        this.#is_retrying = true;
        const start_time = Date.now();
        const total_time_ms = total_time_seconds * 1000;
        let attempt = 0;
        let delay = 1000;
        const max_delay = 10000;
        const self = this;
        function give_up() {
            console.log(`Giving up after ${total_time_seconds}s and ${attempt} attempts`);
            self.#websocket = undefined;
            self.#is_retrying = false;
            Bonito.on_connection_close();
        }
        function attempt_connection() {
            if (self.isopen()) {
                return;
            }
            const elapsed = Date.now() - start_time;
            if (elapsed >= total_time_ms) {
                give_up();
                return;
            }
            attempt++;
            console.log(`Connection attempt ${attempt}`);
            if (self.#websocket === undefined) {
                self.tryconnect();
            } else if (self.#websocket.readyState === WebSocket.CLOSED) {
                self.tryconnect();
            } else if (self.#websocket.readyState === WebSocket.CONNECTING) {
                console.log("WebSocket is still connecting...");
            }
            console.log(`Waiting ${delay / 1000}s before retry...`);
            setTimeout(attempt_connection, delay);
            delay = Math.min(delay * 2, max_delay);
        }
        attempt_connection();
    }
    tryconnect() {
        const ws = new WebSocket(this.url);
        ws.binaryType = "arraybuffer";
        this.#websocket = ws;
        const this_ws = this;
        ws.onopen = function() {
            console.log("CONNECTED!!: ", this_ws.url);
            this_ws.#onopen_callbacks.forEach((f)=>f());
            ws.onmessage = function(evt) {
                new Promise((resolve)=>{
                    const binary = new Uint8Array(evt.data);
                    if (binary.length === 1 && binary[0] === 0) {
                        return resolve(null);
                    }
                    Bonito.lock_loading(()=>{
                        Bonito.process_message(Bonito.decode_binary(binary, this_ws.compression_enabled));
                    });
                    return resolve(null);
                });
            };
        };
        ws.onclose = function(evt) {
            console.log("closed websocket connection, code:", evt.code);
            console.log(evt);
            this_ws.retry_connection();
        };
        ws.onerror = function(event) {
            console.error("WebSocket error observed:");
            console.log(event);
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
                if (ws.readyState === WebSocket.CONNECTING) {
                    return "connecting";
                } else {
                    this.#websocket = undefined;
                    return this.ensure_connection();
                }
            }
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
function websocket_url(session_id, proxy_url) {
    let http_url = window.location.protocol + "//" + window.location.host;
    if (proxy_url !== "./") {
        http_url = proxy_url;
    }
    let ws_url = http_url.replace("http", "ws");
    if (!ws_url.endsWith("/")) {
        ws_url = ws_url + "/";
    }
    return ws_url + session_id;
}
function setup_connection({ proxy_url , session_id , compression_enabled , query , main_connection  }) {
    const url = websocket_url(session_id, proxy_url);
    console.log(`connecting : ${url + query}`);
    const ws = new Websocket(url + query, compression_enabled);
    if (main_connection) {
        ws.on_open(()=>{
            Bonito.on_connection_open((binary)=>ws.send(binary), compression_enabled);
        });
    }
}
export { setup_connection as setup_connection };

