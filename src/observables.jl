
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
    send(x.session, payload = value, id = x.id, type = UpdateObservable)
end

"""
Update the value of an observable, without sending changes to the JS frontend.
This will be used to update updates from the forntend.
"""
function update_nocycle!(obs::Observable, value)
    setindex!(
        obs, value,
        notify = (f-> !(f isa JSUpdateObservable))
    )
end



"""
Register all Observables of a session with the connected Javascript frontend.
It updates all the values on the JS side accordingly,
and enables two way communication
"""
function register_obs!(session::Session)
    for (id, (registered, observable)) in session.observables
        if !registered
            # Register on the JS side by sending the current value
            send(
                session,
                type = UpdateObservable,
                id = id,
                payload = observable[]
            )
            updater = JSUpdateObservable(session, id)
            # Make sure we update the Javascript values!
            on(updater, observable)
            session.observables[id] = (true, observable)
        end
    end
    return
end


function jsrender(session::Session, obs::Observable)
    html = map(obs) do value
        repr_richest(value)
    end
    dom = DOM.m_unesc("span", html[])
    onjs(session, html, js"""
        function (html){
            var dom = $(dom);
            if(dom){
                dom.innerHTML = html;
                return true;
            }else{
                //deregister the callback if the observable dom is gone
                return false;
            }
        }
    """)
    return dom
end
