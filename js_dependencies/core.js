const registered_observables = {}
const observable_callbacks = {}
websocket = null

// Save some bytes by using ints for switch variable
const UpdateObservable = '0'
const OnjsCallback = '1'
const EvalJavascript = '2'
const JavascriptError = '3'
const JavascriptWarning = '4'

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

function websocket_url(){
    // something like http://127.0.0.1:8081/
    var http_url = window.location.href
    if(window.websocket_proxy_url){
        http_url = window.websocket_proxy_url
    }
    var ws_url = http_url.replace("http", "ws");
    // now should be like: ws://127.0.0.1:8081/
    if(!ws_url.endsWith("/")){
        ws_url = ws_url + "/"
    }
    ws_url = ws_url + get_session_id() + "/"
    console.log(ws_url)
    return ws_url
}

function get_observable(id){
    if(id in registered_observables){
        return registered_observables[id]
    }else{
        throw ("Can't find observable with id: " + id)
    }
}

function send_error(message, exception){
    websocket_send({
        type: JavascriptError,
        message: message,
        exception: String(exception)
    })
}


function send_warning(message){
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
    websocket.send(JSON.stringify(data))
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
                var callbacks = observable_callbacks[id] || []
                callbacks.push(f)
                observable_callbacks[id] = callbacks
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
        default:
            send_error(
                "Unrecognized message type: " + data.id + ".",
                ""
            )
    }
}

function setup_connection(){
    function tryconnect(url) {
        websocket = new WebSocket(url);
        websocket.onopen = function () {
            websocket.onmessage = function (evt) {
                process_message(JSON.parse(evt.data))
            }
        }
        websocket.onclose = function (evt) {
            if (evt.code === 1005) {
                // TODO handle this!?
                //tryconnect(url)
            }
        }
    }
    tryconnect(websocket_url())
}

setup_connection()
