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
    register_on_connection_open,
    send_pingpong,
} = Connection;

const {
    deserialize,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    materialize_node,
    decode_binary_message,
    decode_base64_message,
} = Protocol;

const { init_session, deserialize_cached, free_session, lookup_observable } =
    Sessions;

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


const JSServe = {
    Protocol,
    deserialize,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    materialize_node,
    decode_binary_message,
    decode_base64_message,

    Connection,
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    send_close_session,
    register_on_connection_open,
    send_pingpong,

    Sessions,
    deserialize_cached,
    init_session,
    free_session,
    // Util
    update_node_attribute,
    update_dom_node,
    lookup_observable,
};

// @ts-ignore
window.JSServe = JSServe;

export {
    Protocol,
    deserialize,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    Connection,
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    register_on_connection_open,
    Sessions,
    deserialize_cached,
    init_session,
    free_session,
};
