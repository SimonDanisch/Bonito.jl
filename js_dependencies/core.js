const registered_observables = {};
const observable_callbacks = {};
const javascript_object_heap = {};

function put_on_heap(id, value){
    javascript_object_heap[id] = value;
}

function delete_from_heap(id){
    delete javascript_object_heap[id];
}

function get_heap_object(id){
    if(id in javascript_object_heap){
        return javascript_object_heap[id];
    }else{
        send_error("Could not find heap object: " + id, null);
        throw "Could not find heap object: " + id;
    }
}

const session_websocket = [];

// Save some bytes by using ints for switch variable
const UpdateObservable = '0';
const OnjsCallback = '1';
const EvalJavascript = '2';
const JavascriptError = '3';
const JavascriptWarning = '4';
const JSCall = '5';
const JSGetIndex = '6';
const JSSetIndex = '7';
const JSDoneLoading = '8';
const FusedMessage = '9';
const DeleteObjects = '10';

function is_list(value){
    return value && typeof value === 'object' && value.constructor === Array;
}

function is_dict(value){
    return value && typeof value === 'object';
}

function randhex(){
    return (Math.random() * 16 | 0).toString(16);
}

// TODO use a secure library for this shit
function rand4hex(){
    return randhex() + randhex() + randhex() + randhex();
}

function get_session_id(){
    // We have one session id, which handles the connection
    // for one APP state
    var session_id = window.js_call_session_id;

    var browser_id = rand4hex();

    // Now, we also need an id for having multiple tabs open in the same browser
    // or for a refresh. this will always be random one...
    // We will create a new websocket connection for any new tab,
    // which will share the same state with the other tabs/refresh
    // var tab_id = rand4hex();
    return session_id + "/" + browser_id; //* "/" * tab_id;
}

const serializer_functions = {
    JSObject: get_heap_object,
}

function materialize(data){
    // if is a node attribute
    if(is_list(data)){
        return data.map(materialize);
    }else if(data.tag){
        var node = document.createElement(data.tag);
        for(var key in data){
            if(key == 'class'){
                node.className = data[key];
            }else if(key != 'children' && key != 'tag'){
                node.setAttribute(key, data[key]);
            }
        }
        for(var idx in data.children){
            var child = data.children[idx];
            if(is_dict(child)){
                node.appendChild(materialize(child));
            }else{
                node.innerText = child;
            }
        }
        return node;
    }else{ // anything else is used as is!
        return data;
    }
}

function js_dereference_rec(parent, field_names) {
    if(field_names.length == 0){
        // we're done, no more fields to index into
        return parent;
    }
    const next_field = field_names.shift();
    let next_parent;
    // skip new, which sneaks into our reference due to how we handle new in Julia
    if(next_field != 'new') {
        next_parent = js_getindex(parent, next_field)
    } else {
        next_parent = parent;
    }
    return js_dereference_rec(next_parent, field_names);
}

function js_dereference(field_names) {
    // see if the name is a Javascript Module
    const parent_field = field_names.shift();
    let parent = window[parent_field];
    if(!parent) {
        // if not a module, it must be on the heap!
        parent = get_heap_object(parent_field);
        if(!parent) {
            // ok, we're out of options at this point!
            send_error("Could not dereference " + parent_field + "." + field_names, null);
        }
    }
    return js_dereference_rec(parent, field_names);
}

function deserialize_js(data){
    if(is_list(data)){
        return data.map(deserialize_js);
    }else if(is_dict(data)){
        if('__javascript_type__' in data){
            if(data.__javascript_type__ == 'JSObject'){
                return get_heap_object(data.payload);
            }else if (data.__javascript_type__ == 'JSReference'){
                return js_dereference(data.payload);
            }else if (data.__javascript_type__ == 'typed_vector'){
                return data.payload;
            }else if (data.__javascript_type__ == 'DomNode'){
                return document.querySelector('[data-jscall-id="' + data.payload + '"]');
            }else if (data.__javascript_type__ == 'js_code'){
                return data.payload;
            }else{
                send_error(
                    "Can't deserialize custom type: " + data.__javascript_type__,
                    null
                );
                return undefined;
            }
        }else{
            var result = {};
            for (var k in data) {
                if (data.hasOwnProperty(k)) {
                    result[k] = deserialize_js(data[k]);
                }
            }
            return result;
        }
    }else{
        return data;
    }
}

function get_observable(id){
    if(id in registered_observables){
        return registered_observables[id];
    }else{
        throw ("Can't find observable with id: " + id)
    }
}

function send_error(message, exception){
    console.error(message);
    console.error(exception);
    websocket_send({
        msg_type: JavascriptError,
        message: message,
        exception: String(exception),
        stacktrace: exception == null ? "" : exception.stack
    })
}

function send_warning(message){
    console.warn(message);

    websocket_send({
        msg_type: JavascriptWarning,
        message: message
    });
}

function run_js_callbacks(id, value){
    if(id in observable_callbacks){
        var callbacks = observable_callbacks[id];
        var deregister_calls = [];
        for (var i = 0; i < callbacks.length; i++) {
            // onjs can return false to deregister itself
            try{
                var register = callbacks[i](value);
                if(register == false){
                    deregister_calls.push(i);
                }
            }catch(exception){
                 send_error(
                    "Error during running onjs callback\n" +
                    "Callback:\n" +
                    callbacks[i].toString(),
                    exception
                );
            }
        }
        for (var i = 0; i < deregister_calls.length; i++) {
            callbacks.splice(deregister_calls[i], 1);
        }
    }
}

function update_obs(id, value){
    if(id in registered_observables){
        try{
            registered_observables[id] = value;
            // call onjs callbacks
            run_js_callbacks(id, value);
            // update Julia side!
            websocket_send({
                msg_type: UpdateObservable,
                id: id,
                payload: value
            });
        }catch(exception){
            send_error(
                "Error during update_obs with observable " + id,
                exception
            );
        }
        return true;
    } else {
        return false;
    }
}


function ensure_connection(){
    // we lost the connection :(
    if(session_websocket.length == 0){
        // try to connect again!
        setup_connection();
    }
    // check if we have a connection now!
    if(session_websocket.length == 0){
        // still no connection...
        // Display a warning, that we lost conenction!
        var popup = document.getElementById('WEBSOCKET_CONNECTION_WARNING');
        if(!popup){
            var doc_root = document.getElementById('application-dom');
            var popup = document.createElement('div');
            popup.id = "WEBSOCKET_CONNECTION_WARNING";
            popup.innerText = "Lost connection to server!";
            doc_root.appendChild(popup);
        }
        return false;
    } else {
        return true;
    }
}

function websocket_send(data){
    const has_conenction = ensure_connection();
    if(has_conenction) {
        if (session_websocket[0].readyState == 1) {
            session_websocket[0].send(msgpack.encode(data));
        } else {
            // wait until in ready state
            setTimeout(()=> websocket_send(data), 100);
        }
    }
}

function register_onjs(f, observable) {
    const callbacks = observable_callbacks[observable] || [];
    callbacks.push(f);
    observable_callbacks[observable] = callbacks;
}

function call_js_func(func, arguments, needs_new, result_object) {
    let result;
    if(needs_new){
        // if argument list we need to use apply
        if (is_list(arguments)){
            result = new func(...arguments);
        }else{
            // for dictionaries we use a normal call
            result = new func(arguments);
        }
    }else{
        // TODO remove code duplication here. I don't think new would propagate
        // correctly if we'd use something like apply_func
        if (is_list(arguments)){
            result = func(...arguments);
        }else{
            // for dictionaries we use a normal call
            result = func(arguments);
        }
    }
    put_on_heap(result_object, result);
}

function js_getindex(object, field) {
    let result = object[field];
    // if result is a class method, we need to bind it to the parent object
    if(result.bind != undefined){
        result = result.bind(object);
    }
    return result;
}

function put_js_getindex(object, field, result_object) {
    const result = js_getindex(object, field);
    put_on_heap(result_object, result);
}

function delete_heap_objects(objects) {
    for(var object in objects){
        delete_from_heap(objects[object]);
    }
}

function update_node_attribute(node, attribute, value){
    if(node){
        if(node[attribute] != value){
            node[attribute] = value;
        }
        return true;
    }else{
        return false; //deregister
    }
}

function init_from_byte_array(init_func, data) {
    for (let obs_id in data.observables) {
        registered_observables[obs_id] = data.observables[obs_id];
    }
    init_func(data.payload);
    websocket_send({msg_type: JSDoneLoading});
}

function init_from_file(init_func, url) {
    var t0 = performance.now();
    var http_request = new XMLHttpRequest();
    http_request.open("GET", url, true);
    http_request.responseType = "arraybuffer";
    http_request.onload = function (event) {
        var t1 = performance.now();
        var arraybuffer = http_request.response; // Note: not oReq.responseText
        if (arraybuffer) {
            var bytes = new Uint8Array(arraybuffer);
            var data = msgpack.decode(bytes);
            init_from_byte_array(init_func, data);
            console.log("Processing done!! " + (t1 - t0) + " milliseconds.");
        }else{
            send_warning("Didn't receive any setup data from server.")
        }
    };
    http_request.send(null);
}

function process_message(data){
    switch(data.msg_type) {
        case UpdateObservable:
            try{
                var value = data.payload;
                registered_observables[data.id] = value;
                // update all onjs callbacks
                run_js_callbacks(data.id, value);
            }catch(exception){
                send_error(
                    "Error while updating observable " + data.id + " from Julia!",
                    exception
                );
            }
            break;
        case OnjsCallback:
            let js_source = "";
            try{
                // register a callback that will executed on js side
                // when observable updates
                const id = data.id;
                js_source = deserialize_js(data.payload);
                const f = eval(js_source);
                register_onjs(f, id);
            }catch(exception){
                send_error(
                    "Error while registering an onjs callback.\n" +
                    "onjs function source:\n" + js_source,
                    exception
                );
            }
            break;
        case EvalJavascript:
            const code = deserialize_js(data.payload);
            try{
                eval(code);
            }catch(exception){
                send_error(
                    "Error while evaling JS from Julia. Source:\n" + code,
                    exception
                );
            }
            break;
        case JSCall:
            try{
                var func = eval(deserialize_js(data.func));
                var arguments = deserialize_js(data.arguments);
                call_js_func(func, arguments, data.needs_new, data.result);
            }catch(exception){
                send_error(
                    "Error while calling JS function from Julia. Function:\n" +
                    String(func),
                    exception
                );
            }
            break;
        case JSGetIndex:
            try{
                var obj = deserialize_js(data.object);
                put_js_getindex(obj, data.field, data.result);
            }catch(exception){
                send_error(
                    "Error while executing getting field " + data.field +
                    " from:\n" + obj,
                    exception
                );
            }
            break;
        case JSSetIndex:
            try{
                var obj = deserialize_js(data.object);
                var val = deserialize_js(data.value);
                obj[data.field] = val;
            }catch(exception){
                send_error(
                    "Error while executing setting field " + data.field +
                    " from:\n" + String(obj) + " with value " + String(val),
                    exception
                );
            }
            break;
        case FusedMessage:
            try{
                var messages = data.payload;
                for(var i in messages){
                    process_message(messages[i]);
                }
            }catch(exception){
                send_error(
                    "Error while executing setting field " + data.field +
                    " from:\n" + String(obj) + " with value " + String(val),
                    exception
                );
            }
            break;
        case DeleteObjects:
            try{
                delete_heap_objects(data.payload);
            }catch(exception){
                send_error(
                    "Error while deleting objects: " + objects_to_delete,
                    exception
                );
            }
            break;
        default:
            send_error("Unrecognized message type: " + data.msg_type + ".", null);
    }
}



function websocket_url(){
    // something like http://127.0.0.1:8081/
    let http_url = window.location.protocol + "//" + window.location.host;

    if(window.websocket_proxy_url){
        http_url = window.websocket_proxy_url;
    }
    let ws_url = http_url.replace("http", "ws");
    // now should be like: ws://127.0.0.1:8081/
    if(!ws_url.endsWith("/")){
        ws_url = ws_url + "/";
    }
    ws_url = ws_url + get_session_id() + "/";
    console.log("Websocket: " + ws_url);
    return ws_url;
}

function setup_connection(){
    let tries = 0;
    function tryconnect(url) {
        websocket = new WebSocket(url);
        websocket.binaryType = 'arraybuffer';
        if(session_websocket.length != 0){
            throw "Inconsistent state. Already opened a websocket!"
        }
        session_websocket.push(websocket)
        websocket.onopen = function () {
            websocket.onmessage = function (evt) {
                const binary = new Uint8Array(evt.data);
                const data = msgpack.decode(binary);
                process_message(data);
            }
        }
        websocket.onclose = function (evt) {
            session_websocket.length = 0;
            if (evt.code === 1005) {
                // TODO handle this!?
                //tryconnect(url)
            }
        }
        websocket.onerror = function(event) {
            console.error("WebSocket error observed:", event);
            if(tries <= 5){
                session_websocket.length = 0;
                tries = tries + 1;
                console.log("Retrying to connect the " + tries + " time!");
                setTimeout(()=> tryconnect(websocket_url()), 1000);
            }
        };
    }
    tryconnect(websocket_url());
}

setup_connection();
