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
    handle_app_error!(err, app::App, parent_session=nothing)

Unified error handling for App rendering errors.
- Logs the error
- Closes the app's session if it was created (prevents wait_for_ready hanging)
- If session was never set, creates a closed dummy session (prevents wait_for_ready hanging)
- Returns error HTML node
- If parent_session is provided and ready, sends error to browser via evaljs
"""
function handle_app_error!(err, app::Union{App, Nothing}, parent_session=nothing)
    bt = Base.catch_backtrace()
    @error "Error rendering app" exception = (err, bt)

    # Handle app session to prevent wait_for_ready from hanging
    if !isnothing(app)
        if !isnothing(app.session[])
            # Close the session if it was created
            try
                close(app.session[])
            catch close_err
                @debug "Error closing session" exception = close_err
            end
        else
            # Session was never set - create a closed dummy session
            # so wait_for_ready doesn't wait forever
            try
                dummy = Session(NoConnection())
                dummy.status = CLOSED
                app.session[] = dummy
            catch
                # If even creating a dummy session fails, wait_for_ready will timeout
            end
        end
    end

    # Generate error HTML
    error_html = HTTPServer.err_to_html(err, bt)

    # If we have a ready parent session, try to send error to browser via evaljs
    # This bypasses the rendering pipeline that might be broken
    if !isnothing(parent_session) && isready(parent_session)
        try
            error_html_str = sprint(io -> show(io, MIME"text/html"(), error_html))
            # Construct JSCode manually since @js_str isn't defined yet at include time
            js_code = JSCode([
                JSString("const target = document.getElementById('subsession-application-dom'); if (target) { target.innerHTML = "),
                error_html_str,
                JSString("; }")
            ])
            evaljs(parent_session, js_code)
        catch err2
            @error "Failed to display error in browser" exception = (err2, Base.catch_backtrace())
        end
    end

    return error_html
end

function update_app!(parent::Session, new_app::App)
    root = root_session(parent)
    @assert root === parent "never call this function with a subsession"
    try
        update_session_dom!(parent, "subsession-application-dom", new_app)
    catch err
        handle_app_error!(err, new_app, parent)
    end
end


function rendered_dom(session::Session, app::App, target=HTTP.Request(); apply_jsrender=true)
    app.session[] = session
    session.current_app[] = app
    try
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
    catch err
        html = HTTPServer.err_to_html(err, Base.catch_backtrace())
        return jsrender(session, html)
    end
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

function Base.close(handler::DisplayHandler)
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
    handler = DisplayHandler(session, server, route, app)
    route!(server, route => handler)
    return handler
end

function update_app!(handler::DisplayHandler, app::App)
    # the connection is open, so we can just use it to update the dom!
    old_session = handler.current_app.session[]
    handler.current_app = app
    if isready(handler.session)
        if !isnothing(old_session)
            close(old_session)
        end
        update_app!(handler.session, app)
        return false
    else
        # Need to wait for someone to actually visit http://.../browser-display
        return true # needs loading!
    end
end

function HTTPServer.apply_handler(handler::DisplayHandler, context)
    try
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
        # We need to create a new session if either of these happen
        if not_initialized || changed_compression || changed_connection
            @debug("creating new Session for unititialized display handler")
            parent = HTTPSession(handler.server) # new session
            handler.session = parent
        end
        sub = Session(parent)
        # Use indicator from user's app on the parent wrapper (only root has indicator)
        parent_dom = session_dom(parent, App(nothing; indicator=handler.current_app.indicator, loading_page=nothing); html_document=true)
        sub_dom = session_dom(sub, handler.current_app)

        # first time rendering in a subsession, we put the
        # subsession dom as a bonito fragment into the parent body
        _, parent_body, _ = find_head_body(parent_dom)
        push!(children(parent_body), sub_dom)
        html_str = sprint(io -> print_as_page(io, parent_dom))
        # The closing time is calculated from here
        # If after 20s after rendering and sending the HTML to the browser
        # no connection is established, it will be assumed that the browser never connected
        mark_displayed!(parent)
        mark_displayed!(sub)
        return html(html_str)
    catch err
        # Use unified error handling - closes app session to prevent wait_for_ready hang
        error_html = handle_app_error!(err, handler.current_app, nothing)
        html_str = sprint(io -> print_as_page(io, error_html))
        return html(html_str)
    end
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
