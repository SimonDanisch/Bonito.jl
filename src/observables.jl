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
        # We need to fuse all events, since we can't e.g. sent an
        # evaljs event, before we even loaded the div/ or an onload
        # that relies on the div's to be present
        fuse(session) do
            new_dom = jsrender(session, data)
            register_resource!(session, new_dom)
            messages = []; onload = []; dependencies = [];
            if isopen(session)
                messages = copy(session.message_queue)
                empty!(session.message_queue)
                for (asset, loaded) in session.dependencies
                    if !loaded
                        session.dependencies[asset] = true
                        push!(dependencies, serialize_js(asset))
                    end
                end
                onload = copy(session.on_document_load)
                empty!(session.on_document_load)
            end
            s = Session()
            register_resource!(s, onload)
            observables = Dict((k => v[2][] for (k, v) in s.observables))
            msgs = filter(messages) do msg
                msg[:msg_type] == OnjsCallback
            end
            return Dict(:dom => DOM.div(new_dom),
                        :dependencies => dependencies,
                        :observables => observables,
                        :onload => onload,
                        :messages => messages)
        end
    end
    div = DOM.span(html[][:dom])

    onjs(session, html, js"""function (html){
        function load_dom(){
            // first of all we materialize the new dom!
            const dom = materialize(deserialize_js(html.dom));
            const div = $(div);
            div.children[0].replaceWith(dom);
            // register the observables:
            for (let obs_id in html.observables) {
                registered_observables[obs_id] = html.observables[obs_id];
            }
            // After the dom is active, we can run the onload functions!
            const onload = deserialize_js(html.onload);

            for (let i in onload) {
                onload[i]();
            }
            // now, we can execute the fused messages!
            const messages = html.messages;
            for (var i in messages) {
                process_message(messages[i]);
            }
        }
        if(html.dependencies.length > 0) {
            load_javascript_sources(html.dependencies, load_dom);
        } else {
            load_dom();
        }
    }""")
    return div
end
