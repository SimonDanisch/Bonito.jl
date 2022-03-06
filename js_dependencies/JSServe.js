import * as Connection from "./Connection.js";
import * as Protocol from "./Protocol.js";
import * as Sessions from "./Sessions.js";

const {
    send_error,
    send_warning,
    process_message,
    on_connection_open,
    on_connection_close,
} = Connection;

const {
    deserialize,
    base64decode,
    base64encode,
    decode_binary,
    encode_binary,
} = Protocol;

const { init_session, deserialize_cached } = Sessions;

const JSServe = {
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

    Sessions,
    deserialize_cached,
    init_session,
};
