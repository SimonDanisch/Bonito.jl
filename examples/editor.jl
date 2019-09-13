using Hyperscript
using JSServe, Observables
using JSServe.DOM

using JSServe: Application, Session, evaljs, linkjs, update_dom!, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session
using JSServe.DOM
using UUIDs
# Javascript & CSS dependencies can be declared locally and
# freely interpolated in the DOM / js string, and will make sure it loads
const ace = JSServe.Dependency(
    :ace,
    ["https://cdn.jsdelivr.net/gh/ajaxorg/ace-builds/src-min/ace.js"]
)

message_area_style = css(
    ".message_area",
    display = "flex",
    flexDirection = "column",
    width = "50%",
    height = "80%",
    padding = "5px",
    backgroundColor = "#f1f1f1",
    border = "1px solid black"
)

editor_style = css(
    ".editor",
    width = "50%",
    height = "10em",
    border = "1px solid black"
)

result_style = css(
    ".result",
    padding = "2px",
    alignSelf = "flex-end",
    border = "1px solid black"
)

message_style = css(
    ".message",
    padding = "2px",
    margin = "4px",
    alignSelf = "flex-start",
    border = "1px solid black"
)

message_myself_style = css(
    ".myself",
    alignSelf = "flex-end",
)

all_styles = (
    message_area_style, editor_style, result_style,
    message_style, message_myself_style
)

new_message = Observable(Dict{Symbol, Any}())

struct ChatRoom
    id::String
    name::String
    users::Vector{Session}
    # Message inbox
    new_message::Observable{Dict{Symbol, Any}}
    session2name::Dict{String, String}
    history::Vector{Message}
    workers::Vector{WebSocket}
end

all_chatrooms = Dict{String, ChatRoom}()

function ChatRoom()
    id = string(UUIDs.uuid4())
    users = Session[]
    new_message = Observable(Dict{Symbol, Any}())
    history = Message[]
    workers = WebSocket[]
    on(new_message) do message
        push!(history, message)
        if message[:type] == "julia" && !isempty(workers)
            JSServe.serialize_websocket(worker, message)
        end
    end
    return ChatRoom(
        id,
        users,
        new_message,
        history,
        workers
    )
end

function on_chat_route(id, user)
    chatroom = chatrooms[id]

end

function dom_handler(session, request)
    editor = DOM.div("""
        function test()
            1 + 1
        end
        """,
        class = "editor"
    )
    message_area = DOM.div(class = "message_area")
    JSServe.onload(session, editor, js"""
        function (element){
            function now(){
                var date = new Date();
                return date.getFullYear() + "-" +
                    date.getMonth() + "-" +
                    date.getDay() + "T" +
                    date.getHours() + ":" +
                    date.getMinutes() + ":" +
                    date.getSeconds()
            }
            function uuidv4() {
              return 'xxxxxxxx_xxxx_4xxx_yxxx_xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
                return v.toString(16);
              });
            }
            var EditSession = require("ace/edit_session").EditSession;
            // var js = new EditSession("1 + 1");
            var editor = $ace.edit(element);
            editor.setTheme("ace/theme/chrome");
            editor.session.setMode("ace/mode/julia");
            editor.setOptions({
                autoScrollEditorIntoView: true,
                copyWithEmptySelection: true,
                maxLines: 15,
                minLines: 6,
                mergeUndoDeltas: "always"
            });
            editor.session.setUseSoftTabs(true);
            editor.session.setTabSize(4);
            editor.setHighlightActiveLine(false);
            editor.commands.addCommand({
                name: 'Send Message',
                bindKey: {win: 'Ctrl-Enter',  mac: 'Command-Enter'},
                exec: function(editor) {
                    var string = editor.getValue();
                    update_obs($new_message, {
                        sender: get_session_id(),
                        time: now(),
                        type: "julia",
                        content: string,
                        id: uuidv4(),
                    })
                    editor.setValue("")
                },
                readOnly: true // false if this command should not apply in readOnly mode
            });
            editor.resize();
            // editor.setSession(js);
        }
    """)
    onjs(session, new_message, js"""
        function (message){
            var msg_area = $message_area;
            var msg = document.createElement("div");
            var result = document.createElement("div");
            result.className = "result";
            msg.className = "message";
            if(message.sender == get_session_id()){
                msg.className += " myself";
            }
            msg.innerText = message.content;
            msg.setAttribute("id", message.id);
            msg_area.appendChild(msg);
            msg.appendChild(result)
        }
    """)
    return DOM.div(
        DOM.style(all_styles...),
        DOM.div(message_area, editor)
    )
end

on(new_message) do message
    if message[:type] == "julia"
        html = try
            value = include_string(Main, message[:content], "message")
            richest_html(value)
        catch e
            string("<font color = \"red\"> Error: ", e, "</font>")
        end
        for (id, session) in JSServe.active_sessions(app)
            evaljs(session, js"""
                var selector = $("#" * message[:id] * ">.result")
                var result = document.querySelector(selector);
                if(result){
                    var html = $(html);
                    result.innerHTML = html;
                }
            """)
        end
        return
    end
end


# app = JSServe.Application(
#     dom_handler,
#     get(ENV, "WEBIO_SERVER_HOST_URL", "127.0.0.1"),
#     parse(Int, get(ENV, "WEBIO_HTTP_PORT", "8081")),
#     verbose = false
# )


function workyaass()
    html = try
        value = include_string(Main, message[:content], "message")
        richest_html(value)
    catch e
        string("<font color = \"red\"> Error: ", e, "</font>")
    end
    for (id, session) in JSServe.active_sessions(app)
        evaljs(session, js"""
            var selector = $("#" * message[:id] * ">.result")
            var result = document.querySelector(selector);
            if(result){
                var html = $(html);
                result.innerHTML = html;
            }
        """)
    end
    return
end
