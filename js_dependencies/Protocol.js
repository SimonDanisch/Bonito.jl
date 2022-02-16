import { encode as msg_encode, decode as msg_decode } from "./3rdparty/msgpack.min.js";
import { inflate, deflate } from "./3rdparty/pako_inflate.min.js";

function materialize_node(data) {
    // if is a node attribute
    if (is_list(data)) {
        return data.map(materialize_node);
    } else if (data.tag) {
        const node = document.createElement(data.tag);
        Object.keys(data).forEach((key) => {
            if (key == "class") {
                node.className = data[key];
            } else if (key != "children" && key != "tag") {
                node.setAttribute(key, data[key]);
            }
        });
        data.children.forEach((child) => {
            if (is_dict(child)) {
                node.appendChild(materialize_node(child));
            } else {
                if (data.tag == "script") {
                    node.text = child;
                } else {
                    node.innerText = child;
                }
            }
        });
        return node;
    } else {
        // anything else is used as is!
        return data;
    }
}

function is_list(value) {
    return value && typeof value === "object" && value.constructor === Array;
}

function is_dict(value) {
    return value && typeof value === "object";
}

function is_string(object) {
    return typeof object === "string";
}

function array_to_buffer(array) {
    return array.buffer.slice(
        array.byteOffset,
        array.byteLength + array.byteOffset
    );
}

function deserialize_datatype(type, payload) {
    switch (type) {
        case "TypedVector":
            return payload;
        case "DomNode":
            return document.querySelector(`[data-jscall-id="${payload}"]`);
        case "DomNodeFull":
            return materialize_node(payload);
        case "JSCode":
            const eval_func = new Function(
                "__eval_context__",
                "JSServe",
                data.payload.source
            );
            const context = deserialize_js(data.payload.context);
            // return a closure, that when called runs the code!
            return () => eval_func(context, JSServe);
        case "Observable":
            const value = deserialize_js(data.payload.value);
            const id = data.payload.id;
            registered_observables[id] = value;
            return id;
        case "Uint8Array":
            const buffer = array_to_buffer(data.payload);
            return new UInt8Array(buffer);
        case "Int32Array":
            const buffer = array_to_buffer(data.payload);
            return new Int32Array(buffer);
        case "Uint32Array":
            const buffer = array_to_buffer(data.payload);
            return new Uint32Array(buffer);
        case "Float32Array":
            const buffer = array_to_buffer(data.payload);
            return new Float32Array(buffer);
        case "Float64Array":
            const buffer = array_to_buffer(data.payload);
            return new Float64Array(buffer);
        default:
            send_error(
                "Can't deserialize custom type: " +
                    data.__javascript_type__,
                null
            );
    }
}


export function deserialize_js(binary_data) {
    const data = decode_binary(binary_data);
    if (is_list(data)) {
        return data.map(deserialize_js);
    } else if (is_dict(data)) {
        if ("__javascript_type__" in data) {
            return deserialize_datatype(data.__javascript_type__, data.payload);
        } else {
            const result = {};
            for (let k in data) {
                if (data.hasOwnProperty(k)) {
                    result[k] = deserialize_js(data[k]);
                }
            }
            return result;
        }
    } else {
        return data;
    }
}

async function base64encode(data_as_uint8array) {
    // Use a FileReader to generate a base64 data URI
    const base64url = await new Promise((r) => {
        const reader = new FileReader();
        reader.onload = () => r(reader.result);
        reader.readAsDataURL(new Blob([data_as_uint8array]));
    });
    /*
    The result looks like
    "data:application/octet-stream;base64,<your base64 data>",
    so we split off the beginning:
    */
    // length of "data:application/octet-stream;base64,"
    const len = 37;
    return base64url.slice(len, base64url.length);
}

async function base64decode(base64_str) {
    const response = await fetch(
        "data:application/octet-stream;base64," + base64_str
    );
    return new Uint8Array(await response.arrayBuffer())
}

export function decode_binary(binary) {
    // we either get a uint buffer or base64 decoded string
    if (is_string(binary)) {
        return decode_binary(base64decode(binary));
    } else {
        return msg_decode(inflate(binary));
    }
}

export function encode_binary(data) {
    const binary = msg_encode(data);
    return deflate(binary);
}

export function decode_string(string) {
    const binary = base64decode(string);
    return decode_binary(binary);
}
