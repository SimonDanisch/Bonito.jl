import * as Connection from "./Connection.js";
import { onany } from "./Observables.js";
import * as Protocol from "./Protocol.js";
import * as Sessions from "./Sessions.js";

const {
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    on_connection_connecting,
    send_close_session,
    send_pingpong,
    can_send_to_julia,
    send_to_julia,
    register_connection_indicator,
    unregister_connection_indicator,
    set_no_connection,
    ConnectionStatus,
} = Connection;

const {
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    decode_base64_message,
} = Protocol;

const {
    init_session,
    free_session,
    lookup_global_object,
    update_or_replace,
    lock_loading,
    OBJECT_FREEING_LOCK,
    free_object,
    force_free_object,
    close_all_sessions,
    setup_tab_close_handler,
} = Sessions;

// Setup tab close handler to close sessions when the page is unloaded
setup_tab_close_handler();

function update_node_attribute(node, attribute, value) {
    if (node) {
        if (attribute === "class") {
            node.className = value; // Use className for class attribute
        } else if (node[attribute] != value) {
            node[attribute] = value;
        }
        return true;
    } else {
        return false; //deregister
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
/**
 * @param {RequestInfo | URL} url
 */
function fetch_binary(url) {
    return fetch(url).then((response) => {
        if (!response.ok) {

            throw new Error("HTTP error, status = " + response.status);
        }
        return response.arrayBuffer();
    });
}

/**
 * Load a JavaScript library dynamically and return a promise that resolves with the global object
 * @param {string} url - The URL of the script to load
 * @param {string} global_name - The name of the global variable that will be created
 * @returns {Promise} A promise that resolves with the loaded global object
 */
function load_script(url, global_name) {
    // Script already loaded, return the global immediately
    if (window[global_name]) {
        return Promise.resolve(window[global_name]);
    }

    // Check if script is already in document
    const existing_script = document.querySelector(`script[src="${url}"]`);
    const script = existing_script || document.createElement("script");

    return new Promise((resolve, reject) => {
        // Helper to wait for and return the global after script loads
        // Some libraries (like ACE) may assign their global variable asynchronously
        // after the script's main code executes. We retry with exponential backoff
        // to handle various initialization timing scenarios.
        const waitForGlobal = (retries = 0, maxRetries = 10, delay = 10) => {
            setTimeout(() => {
                if (window[global_name]) {
                    resolve(window[global_name]);
                } else if (retries < maxRetries) {
                    // Retry with exponential backoff: 10ms, 20ms, 40ms, 80ms, etc.
                    waitForGlobal(retries + 1, maxRetries, delay * 2);
                } else {
                    reject(
                        new Error(
                            `Global '${global_name}' not found after loading ${url} (tried ${maxRetries + 1} times)`
                        )
                    );
                }
            }, delay);
        };

        script.addEventListener("load", () => {
            script.dataset.loaded = "true";
            waitForGlobal();
        });

        script.addEventListener("error", () => {
            reject(new Error(`Failed to load script: ${url}`));
        });

        // Only set src and append if this is a new script
        if (!existing_script) {
            script.src = url;
            script.dataset.loaded = "false";
            document.head.appendChild(script);
        }
    });
}

// from: https://www.geeksforgeeks.org/javascript-throttling/
function throttle_function(func, delay) {
    // Previously called time of the function
    let prev = 0;
    // ID of queued future update
    let future_id = undefined;
    function inner_throttle(...args) {
        // Current called time of the function
        const now = new Date().getTime();

        // If we had a queued run, clear it now, we're
        // either going to execute now, or queue a new run.
        if (future_id !== undefined) {
            clearTimeout(future_id);
            future_id = undefined;
        }

        // If difference is greater than delay call
        // the function again.
        if (now - prev > delay) {
            prev = now;
            // "..." is the spread operator here
            // returning the function with the
            // array of arguments
            return func(...args);
        } else {
            // Otherwise, we want to queue this function call
            // to occur at some later later time, so that it
            // does not get lost; we'll schedule it so that it
            // fires just a bit after our choke ends.
            future_id = setTimeout(
                () => inner_throttle(...args),
                delay - (now - prev) + 1
            );
        }
    }
    return inner_throttle;
}

// JavaScript version of generate_state_key to match Julia's formatting
export function generate_state_key(v) {
    if (typeof v === 'number') {
        if (isNaN(v)) {
            return 'NaN';
        } else if (!isFinite(v)) {
            return v > 0 ? 'Infinity' : '-Infinity';
        } else {
            // Round to 6 decimal places and remove trailing zeros
            let formatted = v.toFixed(6);
            // Remove trailing zeros after decimal point
            if (formatted.includes('.')) {
                formatted = formatted.replace(/\.?0+$/, '');
            }
            return formatted;
        }
    } else if (typeof v === 'boolean') {
        return v ? 'true' : 'false';
    } else {
        return String(v);
    }
}

const Bonito = {
    Protocol,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    decode_base64_message,
    fetch_binary,
    load_script,

    Connection,
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    on_connection_connecting,
    send_close_session,
    send_pingpong,

    // Connection indicator API
    register_connection_indicator,
    unregister_connection_indicator,
    set_no_connection,
    ConnectionStatus,

    Sessions,
    init_session,
    free_session,
    lock_loading,
    close_all_sessions,
    // Util
    update_node_attribute,
    update_dom_node,
    lookup_global_object,
    update_or_replace,
    force_free_object,

    OBJECT_FREEING_LOCK,
    can_send_to_julia,
    onany,
    free_object,
    send_to_julia,
    throttle_function,
    generate_state_key,
};

// @ts-ignore
window.Bonito = Bonito;


export {
    Protocol,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    decode_base64_message,
    fetch_binary,
    load_script,
    Connection,
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    on_connection_connecting,
    send_close_session,
    send_pingpong,
    // Connection indicator API
    register_connection_indicator,
    unregister_connection_indicator,
    set_no_connection,
    ConnectionStatus,
    Sessions,
    init_session,
    free_session,
    lock_loading,
    close_all_sessions,
    // Util
    update_node_attribute,
    update_dom_node,
    lookup_global_object,
    update_or_replace,
    onany,
    OBJECT_FREEING_LOCK,
    can_send_to_julia,
    free_object,
    send_to_julia,
    throttle_function,
};
