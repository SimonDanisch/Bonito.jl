// https://www.npmjs.com/package/@msgpack/msgpack
import * as MsgPack from "http://cdn.esm.sh/v97/@msgpack/msgpack@2.8.0/es2022/msgpack.js";
import * as Pako from "https://cdn.esm.sh/v66/pako@2.0.4/es2021/pako.js";
import { Observable } from "./Observables.js";
import {
    deserialize_cached,
    update_session_cache,
    lookup_global_object,
} from "./Sessions.js";

export class Retain {
    constructor(value) {
        this.value = value;
    }
}

const EXTENSION_CODEC = new MsgPack.ExtensionCodec();

/**
 * @param {Uint8Array} uint8array
 */
function unpack(uint8array) {
    return MsgPack.decode(uint8array, { extensionCodec: EXTENSION_CODEC });
}

function array_to_buffer(array) {
    return array.buffer.slice(
        array.byteOffset,
        array.byteLength + array.byteOffset
    );
}
/**
 * @param {Uint8ArrayConstructor} ArrayType
 * @param {Uint8Array} uint8array
 */
function reinterpret_array(ArrayType, uint8array) {
    if (ArrayType === Uint8Array) {
        return uint8array;
    } else {
        // console.log(ArrayType)
        // console.log(uint8array.byteOffset)
        // console.log(uint8array.byteLength)
        return new ArrayType(array_to_buffer(uint8array));
        // return new ArrayType(
        //     uint8array.buffer,
        //     uint8array.byteOffset,
        //     uint8array.byteLength
        // );
    }
}

function register_ext_array(type_tag, array_type) {
    EXTENSION_CODEC.register({
        type: type_tag,
        decode: (uint8array) => reinterpret_array(array_type, uint8array),
    });
}

register_ext_array(0x11, Int8Array);
register_ext_array(0x12, Uint8Array);
register_ext_array(0x13, Int16Array);
register_ext_array(0x14, Uint16Array);
register_ext_array(0x15, Int32Array);
register_ext_array(0x16, Uint32Array);
register_ext_array(0x17, Float32Array);
register_ext_array(0x18, Float64Array);

function register_ext(type_tag, constructor) {
    EXTENSION_CODEC.register({
        type: type_tag,
        decode: constructor,
    });
}

register_ext(100, (uint_8_array) => {
    const [id, value] = unpack(uint_8_array);
    return new Observable(id, value);
});

register_ext(101, (uint_8_array) => {
    const [es6module, url] = unpack(uint_8_array);
    if (es6module) {
        return import(url);
    } else {
        return fetch(url); // return url for now
    }
});

register_ext(102, (uint_8_array) => {
    const [interpolated_objects, source, julia_file] = unpack(uint_8_array);
    const lookup_interpolated = (id) => interpolated_objects[id];
    // create a new func, that has __lookup_cached as argument
    try {
        const eval_func = new Function("__lookup_interpolated", "JSServe", source);
        // return a closure, that when called runs the code!
        return () => {
            try {
                return eval_func(lookup_interpolated, JSServe);
            } catch (err) {
                console.log(`error in closure from: ${julia_file}`);
                console.log(`Source:`);
                console.log(source);
                throw err;
            }
        };
    } catch (err) {
        console.log(`error in closure from: ${julia_file}`);
        console.log(`Source:`);
        console.log(source);
        throw err;
    }
});

register_ext(103, (uint_8_array) => {
    const real_value = unpack(uint_8_array);
    return new Retain(real_value);
});

register_ext(104, (uint_8_array) => {
    const key = unpack(uint_8_array);
    return lookup_global_object(key);
});

register_ext(105, (uint_8_array) => {
    const [tag, children, attributes] = unpack(uint_8_array);
    const node = document.createElement(tag);
    Object.keys(attributes).forEach((key) => {
        if (key == "class") {
            node.className = attributes[key];
        } else {
            node.setAttribute(key, attributes[key]);
        }
    });
    children.forEach((child) => node.append(child));
    return node;
});

register_ext(106, (uint_8_array) => {
    const [session_id, objects] = unpack(uint_8_array);
    update_session_cache(session_id, objects);
    return session_id;
});

register_ext(107, (uint_8_array) => {
    const [session_id, message] = unpack(uint_8_array);
    return message;
});

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
            const base64url = reader.result;
            // now that we're done, resolve our promise!
            resolve(base64url.slice(len, base64url.length));
        };
        reader.readAsDataURL(new Blob([data_as_uint8array]));
    });
    return base64_promise;
}

export function base64decode(base64_str) {
    return new Promise((resolve) => {
        fetch("data:application/octet-stream;base64," + base64_str).then(
            (response) => {
                response.arrayBuffer().then((array) => {
                    resolve(new Uint8Array(array));
                });
            }
        );
    });
}

export function decode_binary_message(binary) {
    return deserialize_cached(decode_binary(binary));
}

export function decode_base64_message(base64_string) {
    return base64decode(base64_string).then(decode_binary_message);
}

export function decode_binary(binary) {
    const msg_binary = Pako.inflate(binary);
    return unpack(msg_binary);
}

export function encode_binary(data) {
    const binary = MsgPack.encode(data);
    return Pako.deflate(binary);
}
