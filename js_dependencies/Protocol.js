import * as MsgPack from "https://cdn.esm.sh/v66/@msgpack/msgpack@2.7.2/es2021/msgpack.js";
import * as Pako from "https://cdn.esm.sh/v66/pako@2.0.4/es2021/pako.js";
import { Observable } from "./Observables.js";
import { deserialize_cached } from "./Sessions.js";
import { send_error } from "./Connection.js";


export function materialize_node(data) {
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
    throw new Error(`Key ${key} not found! ${mcache}`)
}

function deserialize_datatype(cache, type, payload) {
    switch (type) {
        case "TypedVector":
            return payload;
        case "CacheKey":
            return lookup_cached(cache, payload);
        case "DomNodeFull":
            return materialize_node(payload);
        case "Asset":
            if (payload.es6module) {
                return import(payload.url)
            } else {
                return fetch(payload.url); // return url for now
            }
        case "JSCode":
            const source = payload.source
            const objects = deserialize(cache, payload.interpolated_objects)
            const lookup_interpolated = (id) => objects[id];
            // create a new func, that has __lookup_cached as argument
            const eval_func = new Function(
                "__lookup_interpolated",
                "JSServe",
                source
            );
            // return a closure, that when called runs the code!
            return () => {
                try{
                    return eval_func(lookup_interpolated, JSServe)
                } catch (err) {
                    console.log(`error in closure from: ${payload.julia_file}`)
                    console.log(`Source:`)
                    console.log(source)
                    throw err
                }
            }
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
        // Numbers, strings etc
        return data;
    }
}

export function base64encode(data_as_uint8array) {
    // Use a FileReader to generate a base64 data URI
    const base64_promise = new Promise((resolve) => {
        const reader = new FileReader();
        reader.onload = () => {
            /*
            The result looks like
            "data:application/octet-stream;base64,<your base64 data>",
            so we split off the beginning:
            */
            const len = 37; //length of "data:application/octet-stream;base64,"
            const base64url = reader.result
            // now that we're done, resolve our promise!
            resolve(base64url.slice(len, base64url.length));
        };
        reader.readAsDataURL(new Blob([data_as_uint8array]));
    });
    return base64_promise;
}

export function base64decode(base64_str) {
    return new Promise(resolve => {
        fetch("data:application/octet-stream;base64," + base64_str).then(response => {
            response.arrayBuffer().then(array => {
                resolve(new Uint8Array(array))
            })
        })
    })
}

export function decode_binary_message(binary) {
    return deserialize_cached(decode_binary(binary))
}

export function decode_base64_message(base64_string) {
    return base64decode(base64_string).then(decode_binary_message)
}

export function decode_binary(binary) {
    const msg_binary = Pako.inflate(binary);
    return MsgPack.decode(msg_binary);
}

export function encode_binary(data) {
    const binary = MsgPack.encode(data);
    return Pako.deflate(binary);
}

export function load_module_from_bytes(code_ui8_array) {
    return new Promise((resolve) => {
        const reader = new FileReader();
        reader.onload = () => import(reader.result).then(resolve);
        reader.readAsDataURL(
            new Blob([code_ui8_array], { type: "text/javascript" })
        );
    });
}
