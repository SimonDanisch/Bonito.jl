"""
    App(callback_or_dom; title="JSServe App")
    App((session, request) -> DOM.div(...))
    App((session::Session) -> DOM.div(...))
    App((request::HTTP.Request) -> DOM.div(...))
    App(() -> DOM.div(...))
    App(DOM.div(...))

Usage:
```julia
using JSServe
app = App() do
    return DOM.div(DOM.h1("hello world"), js\"\"\"console.log('hello world')\"\"\")
end
```

If you depend on global observable, make sure to bind it to the session.


# Or bind a global
global some_observable = Observable("global hello world")
App() do session::Session
    bound_global = bind_global(session, some_observable)
    return DOM.div(bound_global)
end
```
"""
App

function update_app!(old_app::App, new_app::App)
    if isnothing(old_app.session[])
        error("Old app has to be displayed first, to actually update it")
    end
    old_session = old_app.session[]
    parent = root_session(old_session)
    update_session_dom!(parent, "JSServe-application-dom", new_app)
    if old_session.connection isa SubConnection
        close(old_session)
    end
end

function rendered_dom(session::Session, app::App, target=HTTP.Request())
    app.session[] = session
    dom = Base.invokelatest(app.handler, session, target)
    return jsrender(session, dom)
end

function bind_global(session::Session, var::AbstractObservable{T}) where T
    # preserve eltype:
    result = Observable{T}(var[])
    map!(identity, session, result, var)
    return result
end

# Enable route!(server, "/" => app)

function HTTPServer.apply_handler(app::App, context)
    server = context.application
    asset_server = HTTPAssetServer(server)
    connection = WebSocketConnection(server)
    session = Session(connection; asset_server=asset_server, title=app.title)
    html_dom = rendered_dom(session, app, context.request)
    html_str = sprint() do io
        page_html(io, session, html_dom)
    end
    return html(html_str)
end

function Base.close(app::App)
    !isnothing(app.session[]) && close(app.session[])
    app.session[] = nothing
end
