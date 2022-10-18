import * as Connection from "./Connection.js";
import * as Protocol from "./Protocol.js";
import * as Sessions from "./Sessions.js";

const {
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    register_init_messages
} = Connection;

const {
    deserialize,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    decode_binary_message
} = Protocol;

const { init_session, deserialize_cached, GLOBAL_SESSION_CACHE } = Sessions;

window.GLOBAL_SESSION_CACHE = GLOBAL_SESSION_CACHE

const JSServe = {
    Protocol,
    deserialize,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
    decode_binary_message,

    Connection,
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
    register_init_messages,
    GLOBAL_SESSION_CACHE,

    Sessions,
    deserialize_cached,
    init_session,
};

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
    register_init_messages,
    Sessions,
    deserialize_cached,
    init_session,
};
