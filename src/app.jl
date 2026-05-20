"""
    App(callback_or_dom; title="Bonito App", loading_page=nothing)
    App((session, request) -> DOM.div(...))
    App((session::Session) -> DOM.div(...))
    App((request::HTTP.Request) -> DOM.div(...))
    App(() -> DOM.div(...))
    App(DOM.div(...))

# Keywords
- `title::String`: Browser tab title (default: `"Bonito App"`)
- `indicator::Union{Nothing, AbstractConnectionIndicator}`: Connection status indicator (default: `nothing`)
- `loading_page`: A component (e.g. `LoadingPage()`) to display while the app handler runs.
  When set, the app DOM is wrapped in an `Observable` that initially shows the loading page,
  then asynchronously replaces it with the real content once the handler completes (default: `nothing`).

# Usage
```julia
using Bonito
app = App() do
    return DOM.div(DOM.h1("hello world"), js\"\"\"console.log('hello world')\"\"\")
end
```

# Loading Page
```julia
app = App(; loading_page=LoadingPage(text="Initializing...")) do session
    data = expensive_setup()
    return DOM.div(data)
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

"""
    record_session_error!(session::Session, err::Exception)

Record `err` as the session's most-recent failure. Sets `session.init_error[]`
(which `isready(session)` re-throws by default, surfacing the cause to any
waiter) and — if this session has a `current_app` with a `ConnectionIndicator`
— pushes the error into `indicator.error[]`. That observable is rendered via
`map(render_error, indicator.error)` into the indicator's DOM, so a connected
browser sees the cause in the page without any custom protocol message.
"""
function record_session_error!(session::Session, err::Exception)
    session.init_error[] = err
    app = session.current_app[]
    if !isnothing(app) && !isnothing(app.indicator) &&
       hasproperty(app.indicator, :error)
        app.indicator.error[] = err
    end
    return nothing
end

"""
    handle_render_error(f, session::Session) -> Node

Run `f()` and return its (Node) result. If `f` throws, log the exception,
record it via `record_session_error!` (so `isready(session)` / `wait_for_ready`
surface the real cause and any indicator on the app picks it up reactively),
and return an error-HTML Node so the caller's downstream emit path (HTTP
response, `show(io, dom)`, the UpdateSession message in `update_session_dom!`)
doesn't have to know whether the render succeeded.

The single error boundary for app rendering. Sites above this one don't
need their own try/catch — `rendered_dom` always returns a Node.
"""
function handle_render_error(f, session::Session)
    try
        return f()
    catch err
        bt = Base.catch_backtrace()
        @error "Error rendering app" exception = (err, bt)
        record_session_error!(session, err)
        return HTTPServer.err_to_html(err, bt)
    end
end

function rendered_dom(session::Session, app::App, target=HTTP.Request(); apply_jsrender=true)
    app.session[] = session
    session.current_app[] = app
    return handle_render_error(session) do
        dom = Base.invokelatest(app.handler, session, target)
        if apply_jsrender
            dom = Base.invokelatest(jsrender, session, dom)
        end
        # Only render indicator for root sessions (not subsessions)
        if isroot(session) && !isnothing(app.indicator)
            indicator_dom = jsrender(session, app.indicator)
            dom = DOM.div(dom, indicator_dom)
        end
        return dom
    end
end

# Live-update a sub-app inside an already-displayed parent session. The render
# path through `update_session_dom!` → `render_subsession` → `session_dom` →
# `rendered_dom` is wrapped by `handle_render_error`, so an erroring `new_app`
# produces an UpdateSession message containing the error DOM. The browser
# swaps it in the same way it would have swapped a successful render. No
# try/catch needed here.
function update_app!(parent::Session, new_app::App)
    @assert root_session(parent) === parent "never call this function with a subsession"
    update_session_dom!(parent, "subsession-application-dom", new_app)
    return new_app
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
    session = HTTPSession(server)
    session.title = app.title
    html_str = sprint() do io
        page_html(io, session, app)
    end
    mark_displayed!(session)
    return html(html_str)
end

function Base.close(app::App)
    # NOTE: this used to call `free(session)`, but `free` only removes the
    # session from `parent.children` and clears bookkeeping — it does NOT
    # close `session.asset_server`. Calling it from App's finalizer (when
    # the App was dropped without explicit close, e.g. update_app! replacing
    # `handler.current_app`) silently leaked refcounts on the parent
    # HTTPAssetServer.
    #
    # Now, App.close just drops the back-reference. The session itself is
    # owned by whoever else holds it (root.children, the DisplayHandler's
    # previous_session buffer, the observable double-buffer), and those
    # owners are responsible for the eventual close cascade.
    app.session[] = nothing
end

mutable struct DisplayHandler
    session::Session
    server::HTTPServer.Server
    route::String
    current_app::App
    # Double-buffer: the previously-displayed app's session is kept alive
    # for one more swap so an in-flight browser fetch for its assets still
    # resolves. Closed when the next swap arrives, or on `close(handler)`.
    previous_session::Union{Session, Nothing}
end

function Base.close(handler::DisplayHandler)
    if !isnothing(handler.previous_session)
        close(handler.previous_session)
        handler.previous_session = nothing
    end
    close(handler.session)
end

function HTTPSession(server::HTTPServer.Server)
    asset_server = HTTPAssetServer(server)
    Conn = FORCED_CONNECTION[]
    if !isnothing(Conn) && Conn <: AbstractWebsocketConnection
        connection = Conn(server)
    else
        connection = WebSocketConnection(server)
    end
    return Session(connection; asset_server=asset_server)
end

function DisplayHandler(server::HTTPServer.Server, app::App; route="/browser-display")
    session = HTTPSession(server)
    handler = DisplayHandler(session, server, route, app, nothing)
    route!(server, route => handler)
    return handler
end

function update_app!(handler::DisplayHandler, app::App)
    # the connection is open, so we can just use it to update the dom!
    old_session = handler.current_app.session[]
    handler.current_app = app
    # `throw=false`: branching on connection state, not waiting for ready.
    if isready(handler.session; throw=false)
        # Double-buffer: close the older session (two swaps back), promote
        # `old_session` to the previous slot. The browser may still be
        # mid-fetch on `old_session`'s assets when we mount the new app —
        # leaving it alive for one more swap gives those fetches a live
        # ChildAssetServer to resolve against.
        if !isnothing(handler.previous_session)
            close(handler.previous_session)
        end
        handler.previous_session = old_session
        update_app!(handler.session, app)
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
    parent = handler.session
    not_initialized = parent.status != UNINITIALIZED
    changed_compression = parent.compression_enabled != default_compression()
    ForcedCon = FORCED_CONNECTION[]
    changed_connection = !isnothing(ForcedCon) && !(parent.connection isa ForcedCon)
    if not_initialized || changed_compression || changed_connection
        @debug("creating new Session for unititialized display handler")
        # Close the old root before replacing it. Otherwise its children +
        # asset_server refcount contributions leak — this is exactly what
        # the subsessions "server cleanup" test catches under
        # Compression+DualWebsocket (which flips both globals between the
        # two test passes, taking this branch). We also drop any buffered
        # `previous_session` since it's a sub of the now-stale root.
        if !isnothing(handler.previous_session)
            close(handler.previous_session)
            handler.previous_session = nothing
        end
        close(handler.session)
        parent = HTTPSession(handler.server)
        handler.session = parent
    end
    sub = Session(parent)
    # The page wrapper (`<title>` etc.) is rendered from the parent session,
    # so carry the displayed app's title onto it — otherwise `display(disp,
    # app)` pages always show the default "Bonito App" regardless of the
    # `title=` passed to `App(...)` (only the `route!(server, "/" => app)`
    # path set it before).
    parent.title = handler.current_app.title
    # Render-time errors are absorbed by `handle_render_error` inside
    # `rendered_dom` — we get back a valid Node either way (success DOM or
    # inline error HTML) and the page wrap finishes normally. Infrastructure
    # failures (Session ctor, find_head_body, sprint, …) propagate to the
    # HTTPServer's `delegate` which returns a 500.
    parent_dom = session_dom(parent, App(nothing; indicator=handler.current_app.indicator, loading_page=nothing); html_document=true)
    sub_dom = session_dom(sub, handler.current_app)
    _, parent_body, _ = find_head_body(parent_dom)
    push!(children(parent_body), sub_dom)
    html_str = sprint(io -> print_as_page(io, parent_dom))
    # The closing time is calculated from here. If after 20s no connection is
    # established the browser is assumed to have never connected.
    mark_displayed!(parent)
    mark_displayed!(sub)
    return html(html_str)
end

function wait_for_ready(app::App; timeout=100)
    success = wait_for(()-> !isnothing(app.session[]); timeout=timeout)
    success !== :success && return nothing
    isclosed(app.session[]) && return nothing
    wait_for(timeout=timeout) do
        isready(app.session[]) || isclosed(app.session[])
    end
    task = app.loading_task[]
    if !isnothing(task)
        wait_for(; timeout=timeout) do
            istaskdone(task)
        end
    end
end

function jsrender(session::Session, app::App)
    return rendered_dom(session, app; apply_jsrender=false)
end
