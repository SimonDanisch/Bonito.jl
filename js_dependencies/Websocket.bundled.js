// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

class Websocket {
    #websocket = undefined;
    #tries = 0;
    #onopen_callbacks = [];
    url = "";
    compression_enabled = false;
    constructor(url, compression_enabled){
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
        ws.onopen = function() {
            console.log("CONNECTED!!: ", this_ws.url);
            this_ws.#tries = 0;
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
            console.log("closed websocket connection");
            this_ws.#websocket = undefined;
            Bonito.on_connection_close();
            console.log("Wesocket close code: " + evt.code);
            console.log(evt);
        };
        ws.onerror = function(event) {
            console.error("WebSocket error observed:");
            console.log(event);
            console.log(this_ws.tries);
            if (this_ws.tries <= 10) {
                this_ws.tries = this_ws.tries + 1;
                console.log("Retrying to connect the " + this_ws.tries + " time!");
                setTimeout(()=>this_ws.tryconnect(), 1000);
            } else {
                this_ws.#websocket = undefined;
            }
        };
    }
    ensure_connection() {
        const ws = this.#websocket;
        if (!ws) {
            console.log("No websocket");
            this.tryconnect();
            if (!this.#websocket) {
                console.log("No websocket after connect. We assume server is offline");
                return "offline";
            } else {
                return this.isopen() ? "ok" : "offline";
            }
        } else {
            if (this.isopen()) {
                return "ok";
            } else {
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
            return undefined;
        }
    }
}
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

