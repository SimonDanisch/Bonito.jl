import * as Connection from "./Connection.js";
import * as Protocol from "./Protocol.js";
import * as Sessions from "./Sessions.js";

const { send_error, send_warning, process_message } = Connection;
const { deserialize, base64decode, decode_binary, encode_binary } = Protocol;
const { init_session, deserialize_cached } = Sessions;

const JSServe = {
    Protocol,
    deserialize,
    base64decode,
    decode_binary,
    encode_binary,

    Connection,
    send_error,
    send_warning,
    process_message,

    Sessions,
    deserialize_cached,
    init_session
};

window.JSServe = JSServe;

export {
    Protocol,
    deserialize,
    Connection,
    send_error,
    send_warning,
    process_message,
};
