function update_app!(old_app::App, new_app::App)
    if isnothing(old_app.session[])
        error("Old app has to be displayed first, to actually update it")
    end
    old_session = old_app.session[]
    parent = root_session(old_session)
    update_session_dom!(parent, "JSServer-application-dom", new_app)
    if old_session.connection isa SubConnection
        close(old_session)
    end
end

function rendered_dom(session::Session, app::App, target=(; target="/"))
    app.session[] = session
    dom = Base.invokelatest(app.handler, session, target)
    return jsrender(session, dom)
end
