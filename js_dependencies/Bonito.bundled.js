"use strict";
(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
    get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
  }) : x)(function(x) {
    if (typeof require !== "undefined") return require.apply(this, arguments);
    throw Error('Dynamic require of "' + x + '" is not supported');
  });
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));

  // dev/Bonito/js_dependencies/Connection.js
  var Connection_exports = {};
  __export(Connection_exports, {
    EvalJavascript: () => EvalJavascript,
    FusedMessage: () => FusedMessage,
    JSDoneLoading: () => JSDoneLoading,
    JavascriptError: () => JavascriptError,
    JavascriptWarning: () => JavascriptWarning,
    Lock: () => Lock,
    OnjsCallback: () => OnjsCallback,
    RegisterObservable: () => RegisterObservable,
    UpdateObservable: () => UpdateObservable,
    can_send_to_julia: () => can_send_to_julia,
    on_connection_close: () => on_connection_close,
    on_connection_open: () => on_connection_open,
    process_message: () => process_message,
    send_close_session: () => send_close_session,
    send_done_loading: () => send_done_loading,
    send_error: () => send_error,
    send_pingpong: () => send_pingpong,
    send_to_julia: () => send_to_julia,
    send_warning: () => send_warning
  });

  // dev/Bonito/js_dependencies/Protocol.js
  var Protocol_exports = {};
  __export(Protocol_exports, {
    Retain: () => Retain,
    base64decode: () => base64decode,
    base64encode: () => base64encode,
    decode_base64_message: () => decode_base64_message,
    decode_binary: () => decode_binary,
    encode_binary: () => encode_binary,
    unpack_binary: () => unpack_binary
  });
  var MsgPack = __toESM(__require("https://cdn.jsdelivr.net/npm/@msgpack/msgpack/mod.ts"));
  var Pako = __toESM(__require("https://cdn.esm.sh/v66/pako@2.0.4/es2021/pako.js"));

  // dev/Bonito/js_dependencies/Observables.js
  var Observable = class {
    #callbacks = [];
    /**
     * @param {string} id
     * @param {any} value
     */
    constructor(id, value) {
      this.id = id;
      this.value = value;
    }
    /**
     * @param {any} value
     * @param {boolean} dont_notify_julia
     */
    notify(value, dont_notify_julia) {
      this.value = value;
      this.#callbacks.forEach((callback) => {
        try {
          const deregister = callback(value);
          if (deregister == false) {
            this.#callbacks.splice(
              this.#callbacks.indexOf(callback),
              1
            );
          }
        } catch (exception) {
          send_error(
            "Error during running onjs callback\nCallback:\n" + callback.toString(),
            exception
          );
        }
      });
      if (!dont_notify_julia) {
        send_to_julia({
          msg_type: UpdateObservable,
          id: this.id,
          payload: value
        });
      }
    }
    /**
     * @param {any} callback
     */
    on(callback) {
      this.#callbacks.push(callback);
    }
  };
  function onany(observables, f) {
    const callback = (x) => f(observables.map((x2) => x2.value));
    observables.forEach((obs) => {
      obs.on(callback);
    });
  }

  // dev/Bonito/js_dependencies/Sessions.js
  var Sessions_exports = {};
  __export(Sessions_exports, {
    GLOBAL_OBJECT_CACHE: () => GLOBAL_OBJECT_CACHE,
    OBJECT_FREEING_LOCK: () => OBJECT_FREEING_LOCK,
    SESSIONS: () => SESSIONS,
    close_session: () => close_session,
    done_initializing_session: () => done_initializing_session,
    free_object: () => free_object,
    free_session: () => free_session,
    init_session: () => init_session,
    lock_loading: () => lock_loading,
    lookup_global_object: () => lookup_global_object,
    on_node_available: () => on_node_available,
    track_deleted_sessions: () => track_deleted_sessions,
    update_or_replace: () => update_or_replace,
    update_session_cache: () => update_session_cache,
    update_session_dom: () => update_session_dom
  });
  var SESSIONS = {};
  var GLOBAL_OBJECT_CACHE = {};
  var OBJECT_FREEING_LOCK = new Lock();
  function lock_loading(f) {
    OBJECT_FREEING_LOCK.lock(f);
  }
  function lookup_global_object(key) {
    const object = GLOBAL_OBJECT_CACHE[key];
    if (object) {
      if (object instanceof Retain) {
        return object.value;
      } else {
        return object;
      }
    }
    throw new Error(`Key ${key} not found! ${object}`);
  }
  function is_still_referenced(id) {
    for (const session_id in SESSIONS) {
      const [tracked_objects, allow_delete] = SESSIONS[session_id];
      if (allow_delete && tracked_objects.has(id)) {
        return true;
      }
    }
    return false;
  }
  function free_object(id) {
    const data = GLOBAL_OBJECT_CACHE[id];
    if (data) {
      if (data instanceof Promise) {
        return;
      }
      if (data instanceof Retain) {
        return;
      }
      if (!is_still_referenced(id)) {
        delete GLOBAL_OBJECT_CACHE[id];
      }
      return;
    } else {
      console.warn(
        `Trying to delete object ${id}, which is not in global session cache.`
      );
    }
    return;
  }
  var DELETE_OBSERVER = void 0;
  function track_deleted_sessions() {
    if (!DELETE_OBSERVER) {
      const observer = new MutationObserver(function(mutations) {
        let removal_occured = false;
        const to_delete = /* @__PURE__ */ new Set();
        mutations.forEach((mutation) => {
          mutation.removedNodes.forEach((x) => {
            if (x.id in SESSIONS) {
              const status = SESSIONS[x.id][1];
              if (status === "delete") {
                to_delete.add(x.id);
              }
            } else {
              removal_occured = true;
            }
          });
        });
        if (removal_occured) {
          Object.keys(SESSIONS).forEach((id) => {
            const status = SESSIONS[id][1];
            if (status === "delete") {
              if (!document.getElementById(id)) {
                console.debug(
                  `adding session to delete candidates: ${id}`
                );
                to_delete.add(id);
              }
            }
          });
        }
        to_delete.forEach((id) => {
          close_session(id);
        });
      });
      observer.observe(document, {
        attributes: false,
        childList: true,
        characterData: false,
        subtree: true
      });
      DELETE_OBSERVER = observer;
    }
  }
  function done_initializing_session(session_id) {
    if (!(session_id in SESSIONS)) {
      throw new Error("Session ");
    }
    send_done_loading(session_id, null);
    if (SESSIONS[session_id][1] != "root") {
      SESSIONS[session_id][1] = "delete";
    }
    console.log(`session ${session_id} fully initialized`);
  }
  function init_session(session_id, binary_messages, session_status, compression_enabled) {
    track_deleted_sessions();
    OBJECT_FREEING_LOCK.task_lock(session_id);
    try {
      SESSIONS[session_id] = [/* @__PURE__ */ new Set(), session_status];
      console.log(`init session: ${session_id}, ${session_status}`);
      if (binary_messages) {
        process_message(
          decode_binary(binary_messages, compression_enabled)
        );
      }
      done_initializing_session(session_id);
    } catch (error) {
      send_done_loading(session_id, error);
      console.error(error.stack);
      throw error;
    } finally {
      OBJECT_FREEING_LOCK.task_unlock(session_id);
    }
  }
  function close_session(session_id) {
    const session = SESSIONS[session_id];
    if (!session) {
      console.warn("double freeing session from JS!");
      return;
    }
    const [session_objects, status] = session;
    const root_node = document.getElementById(session_id);
    if (root_node) {
      root_node.style.display = "none";
      root_node.parentNode.removeChild(root_node);
    }
    if (status === "delete") {
      send_close_session(session_id, status);
      SESSIONS[session_id] = [session_objects, false];
    }
    return;
  }
  function free_session(session_id) {
    OBJECT_FREEING_LOCK.lock(() => {
      const session = SESSIONS[session_id];
      if (!session) {
        console.warn("double freeing session from Julia!");
        return;
      }
      const [tracked_objects, status] = session;
      delete SESSIONS[session_id];
      tracked_objects.forEach(free_object);
      tracked_objects.clear();
    });
  }
  function on_node_available(node_id, timeout) {
    return new Promise((resolve) => {
      function test_node(timeout2) {
        const node = document.querySelector(`[data-jscall-id='${node_id}']`);
        if (node) {
          resolve(node);
        } else {
          const new_timeout = 2 * timeout2;
          console.log(new_timeout);
          setTimeout(test_node, new_timeout, new_timeout);
        }
      }
      test_node(timeout);
    });
  }
  function update_or_replace(node, new_html, replace) {
    if (replace) {
      node.parentNode.replaceChild(new_html, node);
    } else {
      while (node.childElementCount > 0) {
        node.removeChild(node.firstChild);
      }
      node.append(new_html);
    }
  }
  function update_session_dom(message) {
    const { session_id, messages, html, dom_node_selector, replace } = message;
    on_node_available(dom_node_selector, 1).then((dom) => {
      try {
        update_or_replace(dom, html, replace);
        process_message(messages);
        done_initializing_session(session_id);
      } catch (error) {
        send_done_loading(session_id, error);
        console.error(error.stack);
        throw error;
      } finally {
        OBJECT_FREEING_LOCK.task_unlock(session_id);
      }
    });
    return;
  }
  function update_session_cache(session_id, new_jl_objects, session_status) {
    function update_cache(tracked_objects) {
      for (const key in new_jl_objects) {
        tracked_objects.add(key);
        const new_object = new_jl_objects[key];
        if (new_object == "tracking-only") {
          if (!(key in GLOBAL_OBJECT_CACHE)) {
            throw new Error(
              `Key ${key} only send for tracking, but not already tracked!!!`
            );
          }
        } else {
          if (key in GLOBAL_OBJECT_CACHE) {
            console.warn(
              `${key} in session cache and send again!! ${new_object}`
            );
          }
          GLOBAL_OBJECT_CACHE[key] = new_object;
        }
      }
    }
    const session = SESSIONS[session_id];
    if (session) {
      update_cache(session[0]);
    } else {
      OBJECT_FREEING_LOCK.task_lock(session_id);
      const tracked_items = /* @__PURE__ */ new Set();
      SESSIONS[session_id] = [tracked_items, session_status];
      update_cache(tracked_items);
    }
  }

  // dev/Bonito/js_dependencies/Protocol.js
  var Retain = class {
    constructor(value) {
      this.value = value;
    }
  };
  var EXTENSION_CODEC = new MsgPack.ExtensionCodec();
  window.EXTENSION_CODEC = EXTENSION_CODEC;
  function unpack(uint8array) {
    return MsgPack.decode(uint8array, { extensionCodec: EXTENSION_CODEC });
  }
  function pack(object) {
    return MsgPack.encode(object, { extensionCodec: EXTENSION_CODEC });
  }
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
      }
    });
  }
  register_ext_array(17, Int8Array);
  register_ext_array(18, Uint8Array);
  register_ext_array(19, Int16Array);
  register_ext_array(20, Uint16Array);
  register_ext_array(21, Int32Array);
  register_ext_array(22, Uint32Array);
  register_ext_array(23, Float32Array);
  register_ext_array(24, Float64Array);
  function register_ext(type_tag, decode2, encode2) {
    EXTENSION_CODEC.register({
      type: type_tag,
      decode: decode2,
      encode: encode2
    });
  }
  var JLArray = class {
    constructor(size, array) {
      this.size = size;
      this.array = array;
    }
  };
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
  var OBSERVABLE_TAG = 101;
  var JSCODE_TAG = 102;
  var RETAIN_TAG = 103;
  var CACHE_KEY_TAG = 104;
  var DOM_NODE_TAG = 105;
  var SESSION_CACHE_TAG = 106;
  var SERIALIZED_MESSAGE_TAG = 107;
  var RAW_HTML_TAG = 108;
  register_ext(OBSERVABLE_TAG, (uint_8_array) => {
    const [id, value] = unpack(uint_8_array);
    return new Observable(id, value);
  });
  register_ext(JSCODE_TAG, (uint_8_array) => {
    const [interpolated_objects, source, julia_file] = unpack(uint_8_array);
    const lookup_interpolated = (id) => interpolated_objects[id];
    try {
      const eval_func = new Function(
        "__lookup_interpolated",
        "Bonito",
        source
      );
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
        return;
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
  function base64encode(data_as_uint8array) {
    const base64_promise = new Promise((resolve) => {
      const reader = new FileReader();
      reader.onload = () => {
        const len = 37;
        const base64url = reader.result;
        resolve(base64url.slice(len, base64url.length));
      };
      reader.readAsDataURL(new Blob([data_as_uint8array]));
    });
    return base64_promise;
  }
  function base64decode(base64_str) {
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
  function decode_base64_message(base64_string, compression_enabled) {
    return base64decode(base64_string).then(
      (x) => decode_binary(x, compression_enabled)
    );
  }
  function decode_binary(binary, compression_enabled) {
    const serialized_message = unpack_binary(binary, compression_enabled);
    const [session_id, message_data] = serialized_message;
    return message_data;
  }
  function unpack_binary(binary, compression_enabled) {
    if (compression_enabled) {
      return unpack(Pako.inflate(binary));
    } else {
      return unpack(binary);
    }
  }
  function encode_binary(data, compression_enabled) {
    if (compression_enabled) {
      return Pako.deflate(pack(data));
    } else {
      return pack(data);
    }
  }

  // dev/Bonito/js_dependencies/Connection.js
  var UpdateObservable = "0";
  var OnjsCallback = "1";
  var EvalJavascript = "2";
  var JavascriptError = "3";
  var JavascriptWarning = "4";
  var RegisterObservable = "5";
  var JSDoneLoading = "8";
  var FusedMessage = "9";
  var CloseSession = "10";
  var PingPong = "11";
  var UpdateSession = "12";
  function clean_stack(stack) {
    return stack.replaceAll(
      /(data:\w+\/\w+;base64,)[a-zA-Z0-9\+\/=]+:/g,
      "$1<<BASE64>>:"
    );
  }
  var CONNECTION = {
    send_message: void 0,
    queue: [],
    status: "closed",
    compression_enabled: false
  };
  function on_connection_open(send_message_callback, compression_enabled, enable_pings = true) {
    CONNECTION.send_message = send_message_callback;
    CONNECTION.status = "open";
    CONNECTION.compression_enabled = compression_enabled;
    CONNECTION.queue.forEach((message) => send_to_julia(message));
    if (enable_pings) {
      send_pings();
    }
  }
  function on_connection_close() {
    CONNECTION.status = "closed";
  }
  function can_send_to_julia() {
    return CONNECTION.status === "open";
  }
  function send_to_julia(message) {
    const { send_message, status, compression_enabled } = CONNECTION;
    if (send_message !== void 0 && status === "open") {
      send_message(encode_binary(message, compression_enabled));
    } else if (status === "closed") {
      CONNECTION.queue.push(message);
    } else {
      console.log("Trying to send messages while connection is offline");
    }
  }
  function send_pingpong() {
    send_to_julia({ msg_type: PingPong });
  }
  function send_pings() {
    if (!can_send_to_julia()) {
      return;
    }
    send_pingpong();
    setTimeout(send_pings, 5e3);
  }
  function send_error(message, exception) {
    console.error(message);
    console.error(exception);
    send_to_julia({
      msg_type: JavascriptError,
      message,
      exception: String(exception),
      stacktrace: exception === null ? "" : clean_stack(exception.stack)
    });
  }
  function send_warning(message) {
    console.warn(message);
    send_to_julia({
      msg_type: JavascriptWarning,
      message
    });
  }
  function send_done_loading(session, exception) {
    send_to_julia({
      msg_type: JSDoneLoading,
      session,
      message: "",
      exception: exception === null ? "nothing" : String(exception),
      stacktrace: exception === null ? "" : clean_stack(exception.stack)
    });
  }
  function send_close_session(session, subsession) {
    send_to_julia({
      msg_type: CloseSession,
      session,
      subsession
    });
  }
  var Lock = class {
    constructor() {
      this.locked = false;
      this.queue = [];
      this.locking_tasks = /* @__PURE__ */ new Set();
    }
    unlock() {
      this.locked = false;
      if (this.queue.length > 0) {
        const job = this.queue.pop();
        this.lock(job);
      }
    }
    /**
     * @param {string} task_id
     */
    task_lock(task_id) {
      this.locked = true;
      this.locking_tasks.add(task_id);
    }
    task_unlock(task_id) {
      this.locking_tasks.delete(task_id);
      if (this.locking_tasks.size == 0) {
        this.unlock();
      }
    }
    lock(func) {
      return new Promise((resolve) => {
        if (this.locked) {
          const func_res = () => Promise.resolve(func()).then(resolve);
          this.queue.push(func_res);
        } else {
          this.locked = true;
          Promise.resolve(func()).then((x) => {
            this.unlock();
            resolve(x);
          });
        }
      });
    }
  };
  function process_message(data) {
    try {
      switch (data.msg_type) {
        case UpdateObservable:
          lookup_global_object(data.id).notify(data.payload, true);
          break;
        case OnjsCallback:
          data.obs.on(data.payload());
          break;
        case EvalJavascript:
          data.payload();
          break;
        case FusedMessage:
          data.payload.forEach(process_message);
          break;
        case PingPong:
          console.debug("ping");
          break;
        case UpdateSession:
          update_session_dom(data);
          break;
        default:
          throw new Error(
            "Unrecognized message type: " + data.msg_type + "."
          );
      }
    } catch (e) {
      send_error(`Error while processing message ${JSON.stringify(data)}`, e);
    }
  }

  // dev/Bonito/js_dependencies/Bonito.js
  var {
    send_error: send_error2,
    send_warning: send_warning2,
    process_message: process_message2,
    on_connection_open: on_connection_open2,
    on_connection_close: on_connection_close2,
    send_close_session: send_close_session2,
    send_pingpong: send_pingpong2,
    can_send_to_julia: can_send_to_julia2,
    send_to_julia: send_to_julia2
  } = Connection_exports;
  var {
    base64decode: base64decode2,
    base64encode: base64encode2,
    decode_binary: decode_binary2,
    encode_binary: encode_binary2,
    decode_base64_message: decode_base64_message2
  } = Protocol_exports;
  var {
    init_session: init_session2,
    free_session: free_session2,
    lookup_global_object: lookup_global_object2,
    update_or_replace: update_or_replace2,
    lock_loading: lock_loading2,
    OBJECT_FREEING_LOCK: OBJECT_FREEING_LOCK2,
    free_object: free_object2
  } = Sessions_exports;
  function update_node_attribute(node, attribute, value) {
    if (node) {
      if (node[attribute] != value) {
        node[attribute] = value;
      }
      return true;
    } else {
      return false;
    }
  }
  function update_dom_node(dom, html) {
    if (dom) {
      dom.innerHTML = html;
      return true;
    } else {
      return false;
    }
  }
  function fetch_binary(url) {
    return fetch(url).then((response) => {
      if (!response.ok) {
        throw new Error("HTTP error, status = " + response.status);
      }
      return response.arrayBuffer();
    });
  }
  function throttle_function(func, delay) {
    let prev = 0;
    let future_id = void 0;
    function inner_throttle(...args) {
      const now = (/* @__PURE__ */ new Date()).getTime();
      if (future_id !== void 0) {
        clearTimeout(future_id);
        future_id = void 0;
      }
      if (now - prev > delay) {
        prev = now;
        return func(...args);
      } else {
        future_id = setTimeout(
          () => inner_throttle(...args),
          delay - (now - prev) + 1
        );
      }
    }
    return inner_throttle;
  }
  var Bonito = {
    Protocol: Protocol_exports,
    base64decode: base64decode2,
    base64encode: base64encode2,
    decode_binary: decode_binary2,
    encode_binary: encode_binary2,
    decode_base64_message: decode_base64_message2,
    fetch_binary,
    Connection: Connection_exports,
    send_error: send_error2,
    send_warning: send_warning2,
    process_message: process_message2,
    on_connection_open: on_connection_open2,
    on_connection_close: on_connection_close2,
    send_close_session: send_close_session2,
    send_pingpong: send_pingpong2,
    Sessions: Sessions_exports,
    init_session: init_session2,
    free_session: free_session2,
    lock_loading: lock_loading2,
    // Util
    update_node_attribute,
    update_dom_node,
    lookup_global_object: lookup_global_object2,
    update_or_replace: update_or_replace2,
    OBJECT_FREEING_LOCK: OBJECT_FREEING_LOCK2,
    can_send_to_julia: can_send_to_julia2,
    onany,
    free_object: free_object2,
    send_to_julia: send_to_julia2,
    throttle_function
  };
  window.Bonito = Bonito;
})();
