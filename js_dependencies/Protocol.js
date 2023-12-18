// https://www.npmjs.com/package/@msgpack/msgpack
import * as MsgPack from "https://cdn.jsdelivr.net/npm/@msgpack/msgpack/mod.ts";
import * as Pako from "https://cdn.esm.sh/v66/pako@2.0.4/es2021/pako.js";
import { Observable } from "./Observables.js";
import { update_session_cache, lookup_global_object } from "./Sessions.js";

export class Retain {
    constructor(value) {
        this.value = value;
    }
}

const EXTENSION_CODEC = new MsgPack.ExtensionCodec();

window.EXTENSION_CODEC = EXTENSION_CODEC;

/**
 * @param {Uint8Array} uint8array
 */
function unpack(uint8array) {
    return MsgPack.decode(uint8array, { extensionCodec: EXTENSION_CODEC });
}

/**
 * @param {any} object
 * @return {Uint8Array}
 */
function pack(object) {
    return MsgPack.encode(object, { extensionCodec: EXTENSION_CODEC });
}

/**
 * @param {Uint8ArrayConstructor} ArrayType
 * @param {Uint8Array} uint8array
 */
function reinterpret_array(ArrayType, uint8array) {
    if (ArrayType === Uint8Array) {
        return uint8array;
    } else {
        const bo = uint8array.byteOffset;
        const bpe = ArrayType.BYTES_PER_ELEMENT;
        const new_array_length = uint8array.byteLength / bpe;
        const buffer = uint8array.buffer.slice(bo, bo + uint8array.byteLength);
        return new ArrayType(buffer, 0, new_array_length);
    }
}

function register_ext_array(type_tag, array_type) {
    EXTENSION_CODEC.register({
        type: type_tag,
        decode: (uint8array) => reinterpret_array(array_type, uint8array),
        encode: (object) => {
            if (object instanceof array_type) {
                return new Uint8Array(
                    object.buffer,
                    object.byteOffset,
                    object.byteLength
                );
            } else {
                return null;
            }
        },
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

function register_ext(type_tag, decode, encode) {
    EXTENSION_CODEC.register({
        type: type_tag,
        decode,
        encode,
    });
}

class JLArray {
    constructor(size, array) {
        this.size = size;
        this.array = array;
    }
}

register_ext(
    99,
    (uint_8_array) => {
        const [size, array] = unpack(uint_8_array);
        return new JLArray(size, array);
    },
    (object) => {
        if (object instanceof JLArray) {
            return pack([object.size, object.array]);
        } else {
            return null;
        }
    }
);

const OBSERVABLE_TAG = 101;
const JSCODE_TAG = 102;
const RETAIN_TAG = 103;
const CACHE_KEY_TAG = 104;
const DOM_NODE_TAG = 105;
const SESSION_CACHE_TAG = 106;
const SERIALIZED_MESSAGE_TAG = 107;
const RAW_HTML_TAG = 108;

register_ext(OBSERVABLE_TAG, (uint_8_array) => {
    const [id, value] = unpack(uint_8_array);
    return new Observable(id, value);
});

register_ext(JSCODE_TAG, (uint_8_array) => {
    const [interpolated_objects, source, julia_file] = unpack(uint_8_array);
    const lookup_interpolated = (id) => interpolated_objects[id];
    // create a new func, that has __lookup_cached as argument
    try {
        const eval_func = new Function(
            "__lookup_interpolated",
            "Bonito",
            source
        );
        // return a closure, that when called runs the code!
        return () => {
            try {
                return eval_func(lookup_interpolated, window.Bonito);
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

register_ext(RETAIN_TAG, (uint_8_array) => {
    const real_value = unpack(uint_8_array);
    return new Retain(real_value);
});

register_ext(CACHE_KEY_TAG, (uint_8_array) => {
    const key = unpack(uint_8_array);
    return lookup_global_object(key);
});

function create_tag(tag, attributes) {
    if (attributes.juliasvgnode) {
        // painfully figured out, that if you don't use createElementNS for
        // svg, it will simply show up as an svg div with size 0x0
        return document.createElementNS("http://www.w3.org/2000/svg", tag);
    } else {
        return document.createElement(tag);
    }
}

register_ext(DOM_NODE_TAG, (uint_8_array) => {
    const [tag, children, attributes] = unpack(uint_8_array);
    const node = create_tag(tag, attributes);
    Object.keys(attributes).forEach((key) => {
        if (key == "juliasvgnode") {
            return; //skip our internal node, needed to create proper svg
        }
        if (key == "class") {
            node.className = attributes[key];
        } else {
            node.setAttribute(key, attributes[key]);
        }
    });
    children.forEach((child) => node.append(child));
    return node;
});

register_ext(RAW_HTML_TAG, (uint_8_array) => {
    const html = unpack(uint_8_array);
    const div = document.createElement("div");
    div.innerHTML = html;
    return div;
});

register_ext(SESSION_CACHE_TAG, (uint_8_array) => {
    const [session_id, objects, session_status] = unpack(uint_8_array);
    update_session_cache(session_id, objects, session_status);
    return session_id;
});

register_ext(SERIALIZED_MESSAGE_TAG, (uint_8_array) => {
    const [session_id, message] = unpack(uint_8_array);
    return message;
});

/**
 * @param {Uint8Array} data_as_uint8array
 */
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

/**
 * @param {string} base64_str
 */
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

/**
 *
 * @param {string} base64_string
 * @param {boolean} compression_enabled
 */
export function decode_base64_message(base64_string, compression_enabled) {
    return base64decode(base64_string).then((x) =>
        decode_binary(x, compression_enabled)
    );
}

export function decode_binary(binary, compression_enabled) {
    // This should ALWAYS be a `SerializedMessage` from the Julia side
    const serialized_message = unpack_binary(binary, compression_enabled);
    const [session_id, message_data] = serialized_message;
    return message_data;
}

/**
 *
 * @param {Uint8Array} binary
 * @param {boolean} compression_enabled
 */
export function unpack_binary(binary, compression_enabled) {
    if (compression_enabled) {
        return unpack(Pako.inflate(binary));
    } else {
        return unpack(binary);
    }
}

/**
 * @param {any} data
 * @param {boolean} compression_enabled
 */
export function encode_binary(data, compression_enabled) {
    if (compression_enabled) {
        return pack(Pako.deflate(pack(data)));
    } else {
        return pack(data);
    }
}
