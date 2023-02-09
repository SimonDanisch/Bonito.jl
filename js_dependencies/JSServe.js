import * as Connection from "./Connection.js";
import * as Protocol from "./Protocol.js";
import * as Sessions from "./Sessions.js";

const {
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    send_close_session,
    send_pingpong,
    with_message_lock,
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
} = Sessions;

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

const JSServe = {
    Protocol,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    decode_base64_message,
    fetch_binary,

    Connection,
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    send_close_session,
    send_pingpong,
    with_message_lock,

    Sessions,
    init_session,
    free_session,
    // Util
    update_node_attribute,
    update_dom_node,
    lookup_global_object,
    update_or_replace,
};

// @ts-ignore
window.JSServe = JSServe;
console.log("Setting JSServe hehe")
export {
    Protocol,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    decode_base64_message,
    Connection,
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    send_close_session,
    send_pingpong,
    with_message_lock,
    Sessions,
    init_session,
    free_session,
    // Util
    update_node_attribute,
    update_dom_node,
    lookup_global_object,
    update_or_replace,
};
