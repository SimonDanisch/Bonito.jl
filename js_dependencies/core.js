const registered_observables = {}
const observable_callbacks = {}
const javascript_object_heap = {}

function put_on_heap(id, value){
    javascript_object_heap[id] = value;
}
function get_heap_object(id){
    return javascript_object_heap[id];
}

const session_websocket = []

// Save some bytes by using ints for switch variable
const UpdateObservable = '0'
const OnjsCallback = '1'
const EvalJavascript = '2'
const JavascriptError = '3'
const JavascriptWarning = '4'

const JSCall = '5'
const JSGetIndex = '6'
const JSSetIndex = '7'

function is_list(value){
    return value && typeof value === 'object' && value.constructor === Array;
}
function is_dict(value){
    return value && typeof value === 'object';
}

function get_session_id(){
    return window.js_call_session_id
    // TODO, well this was a fun idea, but how do I initialize the http
    // session correctly? I'd need to know the stored session id in the http request already
    // From all I know, this is only possible with cookies?
    // check for browser support
    // if (typeof(Storage) !== "undefined") {
    //   // get the session id from local storage
    //   var saved_id = sessionStorage.getItem("julia-jscall-session-id");
    //   if(saved_id){
    //       return saved_id
    //   }else{
    //       sessionStorage.setItem("julia-jscall-session-id", default_id)
    //       return default_id
    //   }
    // } else {
    //   return default_id
    // }
}
const serializer_functions = {
    JSObject: get_heap_object,
}

function deserialize_js(data){
    if(is_list(data)){
        return data.map(deserialize_js)
    }else if(is_dict(data)){
        if('__javascript_type__' in data){
            if(data.__javascript_type__ == 'JSObject'){
                return get_heap_object(data.payload);
            }else{
                send_error(
                    "Can't deserialize custom type: " + data.__javascript_type__,
                    ""
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

function websocket_url(){
    // something like http://127.0.0.1:8081/
    var http_url = "http://127.0.0.1:8081/";
    if(window.websocket_proxy_url){
        http_url = window.websocket_proxy_url;
    }else{
        http_url = window.location.href;
    }
    var ws_url = http_url.replace("http", "ws");
    // now should be like: ws://127.0.0.1:8081/
    if(!ws_url.endsWith("/")){
        ws_url = ws_url + "/";
    }
    ws_url = ws_url + get_session_id() + "/";
    console.log("Websocket: " + ws_url);
    return ws_url;
}

function get_observable(id){
    if(id in registered_observables){
        return registered_observables[id]
    }else{
        throw ("Can't find observable with id: " + id)
    }
}

function send_error(message, exception){
    console.error(message)
    console.error(exception)
    websocket_send({
        type: JavascriptError,
        message: message,
        exception: String(exception)
    })
}


function send_warning(message){
    console.warn(message)

    websocket_send({
        type: JavascriptWarning,
        message: message
    })
}

function run_js_callbacks(id, value){
    if(id in observable_callbacks){
        var callbacks = observable_callbacks[id]
        var deregister_calls = []
        for (var i = 0; i < callbacks.length; i++) {
            // onjs can return false to deregister itself
            try{
                var register = callbacks[i](value)
                if(register == false){
                    deregister_calls.push(i)
                }
            }catch(exception){
                 send_error(
                    "Error during running onjs callback\n" +
                    "Callback:\n" +
                    callbacks[i].toString(),
                    exception
                )
            }
        }
        for (var i = 0; i < deregister_calls.length; i++) {
            callbacks.splice(deregister_calls[i], 1)
        }
    }
}

function update_obs(id, value){
    if(id in registered_observables){
        try{
            registered_observables[id] = value
            // call onjs callbacks
            run_js_callbacks(id, value)
            // update Julia side!
            websocket_send({
                type: UpdateObservable,
                id: id,
                payload: value
            })
        }catch(exception){
            send_error(
                "Error during update_obs with observable " + id,
                exception
            )
        }
        return true
    }else{
        // Actually, this should be an error........
        send_warning("Observable not found " + id + ". Deregistering!")
        return false
    }
}

function websocket_send(data){
    session_websocket[0].send(JSON.stringify(data))
}



function process_message(data){
    switch(data.type) {
        case UpdateObservable:
            try{
                var value = data.payload
                registered_observables[data.id] = value
                // update all onjs callbacks
                run_js_callbacks(data.id, value)
            }catch(exception){
                send_error(
                    "Error while updating observable " + data.id +
                    " from Julia!",
                    exception
                )
            }
            break;
        case OnjsCallback:
            try{
                // register a callback that will executed on js side
                // when observable updates
                var id = data.id
                var f = eval(data.payload);
                var callbacks = observable_callbacks[id] || [];
                callbacks.push(f);
                observable_callbacks[id] = callbacks;
            }catch(exception){
                send_error(
                    "Error while registering an onjs callback.\n" +
                    "onjs function source:\n" +
                    data.payload,
                    exception
                )
            }
            break;
        case EvalJavascript:
            try{
                eval(data.payload);
            }catch(exception){
                send_error(
                    "Error while evaling JS from Julia. Source:\n" +
                    data.payload,
                    exception
                )
            }
            break;
        case JSCall:
            try{
                var func = data.func;
                var result;
                var arguments = data.arguments;
                if(data.needs_new){
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
                // finally put result on the heap, so the julia object works correctly
                put_on_heap(data.result, result);
            }catch(exception){
                send_error(
                    "Error while calling JS function from Julia. Function:\n" +
                    String(func),
                    exception
                )
            }
            break;
        case JSGetIndex:
            try{
                var result = data.object[data.field];
                // if result is a class method, we need to bind it to the parent object
                if(result.bind != undefined){
                    result = result.bind(data.object);
                }
                put_on_heap(data.result, result);
            }catch(exception){
                send_error(
                    "Error while executing getting field " + data.field +
                    " from:\n" + String(data.object),
                    exception
                )
            }
            break;
        case JSSetIndex:
            try{
                data.object[data.field] = data.value;
            }catch(exception){
                send_error(
                    "Error while executing setting field " + data.field +
                    " from:\n" + String(data.object) + " with value " + data.value,
                    exception
                )
            }
            break;
        default:
            send_error(
                "Unrecognized message type: " + data.id + ".",
                ""
            )
    }
}

function setup_connection(){
    var tries = 0
    function tryconnect(url) {
        websocket = new WebSocket(url);
        if(session_websocket.length != 0){
            throw "Inconsistent state. Already opened a websocket!"
        }
        session_websocket.push(websocket)
        websocket.onopen = function () {
            websocket.onmessage = function (evt) {
                var msg = JSON.parse(evt.data);
                var dmsg = deserialize_js(msg);
                process_message(dmsg);
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
                console.log("Retrying to connect the " + tries + " time!")
                setTimeout(()=> tryconnect(websocket_url()), 1000);
            }
        };
    }
    tryconnect(websocket_url())
}

setup_connection()
