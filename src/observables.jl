"""
Functor to update JS part when an observable changes.
We make this a Functor, so we can clearly identify it and don't sent
any updates, if the JS side requires to update an Observable
(so we don't get an endless update cycle)
"""
struct JSUpdateObservable
    session::Session
    id::String
end

function (x::JSUpdateObservable)(value)
    # Sent an update event
    send(x.session, payload=value, id=x.id, msg_type=UpdateObservable)
end

"""
Update the value of an observable, without sending changes to the JS frontend.
This will be used to update updates from the forntend.
"""
function update_nocycle!(obs::Observable, value)
    setindex!(obs, value, notify = (f-> !(f isa JSUpdateObservable)))
end

function jsrender(session::Session, obs::Observable)
    html = map(obs) do data
        if isopen(session)
            fuse(session) do
                new_dom = jsrender(session, data)
                # if session is already running, register_resource! won't
                # be called by html display, and also on_document_load will just
                # be ignored... So we need to do this here:
                register_resource!(session, new_dom)
                codes = JSServe.serialize_message_readable.(session.message_queue)
                all_javascript = [session.on_document_load..., codes...]
                source, data = JSServe.serialize2string(all_javascript)
                # sourc_scr = DOM.script(source, charset="utf8")
                dom_with_deps = DOM.span(session.dependencies..., new_dom)
                empty!(session.dependencies)
                empty!(session.message_queue)
                empty!(session.on_document_load)
                return Dict(:dom => dom_with_deps, :javascript => serialize_js(source))
            end
        else
            return Dict(:dom => DOM.span(jsrender(session, data)))
        end
    end
    div = DOM.span(html[][:dom])
    onjs(session, html, js"""function (html){
        const dom = materialize(deserialize_js(html.dom));
        const div = $(div);
        div.children[0].replaceWith(dom);
        deserialize_js(html.javasript);
    }""")
    return div
end
