"""
    App(callback_or_dom; title="Bonito App")
    App((session, request) -> DOM.div(...))
    App((session::Session) -> DOM.div(...))
    App((request::HTTP.Request) -> DOM.div(...))
    App(() -> DOM.div(...))
    App(DOM.div(...))

Usage:
```julia
using Bonito
app = App() do
    return DOM.div(DOM.h1("hello world"), js\"\"\"console.log('hello world')\"\"\")
end
```

If you depend on global observable, make sure to bind it to the session.
This is pretty important, since every time you display the app, listeners will get registered to it, that will just continue staying there until your Julia process gets closed.
`bind_global` prevents that by binding the observable to the life cycle of the session and cleaning up the state after the app isn't displayed anymore.
If you serve the `App` via a `Server`, be aware, that those globals will be shared with everyone visiting the page, so possibly by many users concurrently.
```julia
global some_observable = Observable("global hello world")
App() do session::Session
    bound_global = bind_global(session, some_observable)
    return DOM.div(bound_global)
end
```
"""
App

function update_app!(parent::Session, new_app::App)
    root = root_session(parent)
    @assert root === parent "never call this function with a subsession"
    update_session_dom!(parent, "subsession-application-dom", new_app)
end

function rendered_dom(session::Session, app::App, target=HTTP.Request())
    app.session[] = session
    session.current_app[] = app
    dom = Base.invokelatest(app.handler, session, target)
    return jsrender(session, dom)
end

function bind_global(session::Session, var::AbstractObservable{T}) where T
    # preserve eltype:
    result = Observable{T}(var[])
    map!(identity, session, result, var)
    return result
end

function serve_app(app, context)
    @debug "Serving from thread: $(Threads.threadid())"
    server = context.application
    asset_server = HTTPAssetServer(server)
    connection = WebSocketConnection(server)
    session = Session(connection; asset_server=asset_server, title=app.title)
    html_dom = rendered_dom(session, app, context.request)
    html_str = sprint() do io
        page_html(io, session, html_dom)
    end
    response = html(html_str)
    mark_displayed!(session)
    return response
end

# Enable route!(server, "/" => app)
function HTTPServer.apply_handler(app::App, context)
    if app.threaded
        task = ThreadPools.spawnbg(() -> serve_app(app, context))
        return fetch(task)
    else
        return serve_app(app, context)
    end
end

function Base.close(app::App)
    session = app.session[]
    # Needs to be async because of finalizers (todo, figure out better ways!)
    !isnothing(session) && free(session)
    app.session[] = nothing
end

mutable struct DisplayHandler
    session::Session
    server::HTTPServer.Server
    route::String
    current_app::App
end

function HTTPSession(server::HTTPServer.Server)
    asset_server = HTTPAssetServer(server)
    connection = WebSocketConnection(server)
    return Session(connection; asset_server=asset_server)
end

function DisplayHandler(server::HTTPServer.Server, app::App; route="/browser-display")
    session = HTTPSession(server)
    handler = DisplayHandler(session, server, route, app)
    route!(server, route => handler)
    return handler
end

function update_app!(handler::DisplayHandler, app::App)
    # the connection is open, so we can just use it to update the dom!
    old_session = handler.current_app.session[]

    handler.current_app = app
    if isready(handler.session)
        update_app!(handler.session, app)
        # Close old session after rendering, so we can don't delete re-used resources
        if !isnothing(old_session)
            close(old_session)
        end
        return false
    else
        # Need to wait for someone to actually visit http://.../browser-display
        return true # needs loading!
    end
end

function HTTPServer.apply_handler(handler::DisplayHandler, context)
    # we only allow one open tab/browser to show the browser display
    # Multiple sessions wouldn't be too hard, but that means we'd need manage multiple right here
    # And this is already complicated enough!
    # so, if we serve the display handler url, it means to start fresh
    # But if UNINITIALIZED, it's simply the first request to the page!
    if handler.session.status != UNINITIALIZED
        @debug("creating new Session for unititialized display handler")
        handler.session = HTTPSession(handler.server) # new session
    end
    parent = handler.session
    sub = Session(parent)
    init_dom = session_dom(parent, App(nothing); html_document=true)
    sub_dom = session_dom(sub, handler.current_app)
    # first time rendering in a subsession, we combine init of parent session
    # with the dom we're rendering right now
    dom = DOM.div(init_dom, sub_dom)
    html_str = sprint(io -> print_as_page(io, dom))
    # The closing time is calculated from here
    # If after 20s after rendering and sending the HTML to the browser
    # no connection is established, it will be assumed that the browser never connected
    mark_displayed!(parent)
    mark_displayed!(sub)
    return html(html_str)
end

function wait_for_ready(app::App; timeout=100)
    wait_for(()-> !isnothing(app.session[]); timeout=timeout)
    isclosed(app.session[]) && return nothing
    wait_for(()-> isready(app.session[]); timeout=timeout)
end
