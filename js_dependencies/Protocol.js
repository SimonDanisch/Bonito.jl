import * as MsgPack from "https://cdn.esm.sh/v66/@msgpack/msgpack@2.7.2/es2021/msgpack.js";
import * as Pako from "https://cdn.esm.sh/v66/pako@2.0.4/es2021/pako.js";
import { Observable } from "./Observables.js";
import { deserialize_cached, lookup_globally } from "./Sessions.js";

function materialize_node(data) {
    // if is a node attribute
    if (Array.isArray(data)) {
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

async function load_module_from_bytes(code_ui8_array) {
    const js_module_promise = new Promise((r) => {
        const reader = new FileReader();
        reader.onload = async () => r(await import(reader.result));
        reader.readAsDataURL(
            new Blob([code_ui8_array], { type: "text/javascript" })
        );
    });
    return await js_module_promise;
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

function lookup_cached(cache, key) {
    const mcache = cache[key];
    if (mcache) {
        return mcache;
    }
    return lookup_globally(key);
}

function deserialize_datatype(cache, type, payload) {
    switch (type) {
        case "TypedVector":
            return payload;
        case "CacheKey":
            return lookup_cached(cache, payload);
        case "DomNode":
            return materialize_node(payload);
        case "Asset":
            if (payload.es6module) {
                return load_module_from_bytes(
                    deserialize(cache, payload.bytes)
                );
            } else {
                return deserialize(cache, payload.bytes);
            }
        case "JSCode":
            const lookup_cached_inner = (id) => lookup_cached(cache, id);
            const eval_func = new Function(
                "__lookup_cached",
                "JSServe",
                deserialize(cache, payload)
            );
            // return a closure, that when called runs the code!
            return () => eval_func(lookup_cached_inner, JSServe);
        case "Observable":
            const value = deserialize(cache, payload.value);
            return new Observable(payload.id, value);
        case "Uint8Array":
            return payload;
        case "Int32Array":
            return new Int32Array(array_to_buffer(payload));
        case "Uint32Array":
            return new Uint32Array(array_to_buffer(payload));
        case "Float32Array":
            return new Float32Array(array_to_buffer(payload));
        case "Float64Array":
            return new Float64Array(array_to_buffer(payload));
        default:
            send_error("Can't deserialize custom type: " + type, null);
    }
}

export function deserialize(cache, data) {
    if (Array.isArray(data)) {
        return data.map((x) => deserialize(cache, x));
    } else if (is_dict(data)) {
        if ("__javascript_type__" in data) {
            return deserialize_datatype(
                cache,
                data.__javascript_type__,
                data.payload
            );
        } else {
            const result = {};
            for (let k in data) {
                if (data.hasOwnProperty(k)) {
                    result[k] = deserialize(cache, data[k]);
                }
            }
            return result;
        }
    } else {
        return data;
    }
}

export async function base64encode(data_as_uint8array) {
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

export async function base64decode(base64_str) {
    const response = await fetch(
        "data:application/octet-stream;base64," + base64_str
    );
    return new Uint8Array(await response.arrayBuffer());
}

export async function decode_binary_message(binary) {
    // we either get a uint buffer or base64 decoded string
    if (is_string(binary)) {
        return decode_binary_message(await base64decode(binary));
    } else {
        return await deserialize_cached(decode_binary(binary));
    }
}

export function decode_binary(binary) {
    const msg_binary = Pako.inflate(binary);
    return MsgPack.decode(msg_binary);
}

export function encode_binary(data) {
    const binary = MsgPack.encode(data);
    return Pako.deflate(binary);
}
