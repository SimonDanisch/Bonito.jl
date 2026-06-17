using PrecompileTools

"""
    serve_workload(app::App; updates = Pair{Observable, Any}[])

Precompile-workload helper: serves `app` on a loopback server and exercises
the full serving stack the way a real browser would — page request, one
asset request, and a websocket client speaking the frontend protocol
(session announce, which runs `init_session` and flushes the queued init
messages through the websocket write path, plus observable updates through
the inbox/`process_message` path).

Intended for `PrecompileTools.@compile_workload` blocks of packages building
on Bonito (e.g. WGLMakie), so the serve path is compiled into their
pkgimage with all their own types and method extensions loaded — without
this, the first display at runtime pays several seconds of inference for
the listener/stream-handler/websocket-decoder task bodies.

`updates` are `observable => payload` pairs sent as frontend observable
updates (the observables must be registered with the served session, i.e.
rendered into the app). When empty, the first registered `Observable{Int}`
gets an update instead, if any.
"""
function serve_workload(app::App; updates = Pair{Observable, Any}[])
    # the same DisplayHandler/sub-session path `display(...)` takes at
    # runtime (this is what electron displays serve through), not a plain
    # app route
    browser_display = HTTPServer.BrowserDisplay(; open_browser = false)
    Base.display(browser_display, app)
    handler = browser_display.handler
    server = handler.server
    try
        page = HTTP.get(HTTPServer.local_url(server, handler.route); retry = false)
        # one asset request compiles the asset-serving handler chain
        asset_url = match(r"http://[^\"]+/assets/[^\"]+", String(page.body))
        isnothing(asset_url) || HTTP.get(asset_url.match; retry = false)
        root = handler.session
        sub = app.session[]
        registered_key(session, obs) = findfirst(session.session_objects) do val
            (val isa CachedEntry ? val.object : val) === obs
        end
        announce(ws, id) = HTTP.WebSockets.send(ws, MsgPack.pack(Dict{String, Any}(
            "msg_type" => JSDoneLoading,
            "exception" => "nothing",
            "session" => id,
        )))
        HTTP.WebSockets.open("ws://127.0.0.1:$(server.port)/$(root.id)") do ws
            # announce root and sub session like the frontend does on load:
            # runs init_session server-side and flushes the queued init
            # messages through the websocket write path
            announce(ws, root.id)
            isnothing(sub) || announce(ws, sub.id)
            sleep(0.2)
            # observable updates compile the interaction hot path
            # (inbox reader -> process_message -> update_nocycle!)
            keyed_updates = Pair{String, Any}[]
            for (obs, payload) in updates
                for session in (sub, root)
                    isnothing(session) && continue
                    key = registered_key(session, obs)
                    isnothing(key) || (push!(keyed_updates, key => payload); break)
                end
            end
            if isempty(keyed_updates) && !isnothing(sub)
                for (key, val) in sub.session_objects
                    obj = val isa CachedEntry ? val.object : val
                    if obj isa Observable{Int}
                        push!(keyed_updates, key => 4)
                        break
                    end
                end
            end
            for (key, payload) in keyed_updates
                HTTP.WebSockets.send(ws, MsgPack.pack(Dict{String, Any}(
                    "msg_type" => UpdateObservable,
                    "id" => key,
                    "payload" => payload,
                )))
            end
            sleep(0.2)
            # evaljs_value round trip: compiles the evaljs/wait/fetch path.
            # Our protocol client never answers, so this times out - by
            # design. The Int timeout matters: the runtime default is an Int,
            # and the wait closure specializes on it.
            isnothing(sub) || try
                evaljs_value(sub, js"1"; timeout = 1)
            catch e
                # Expected: our protocol client never answers, so the round-trip
                # times out by design. Anything else is a real failure — let it
                # reach the outer warn-and-skip handler instead of hiding here.
                (e isa ErrorException && e.msg == "Timed out") || rethrow()
            end
        end
    catch e
        # never fail a package build over this: sandboxed build environments
        # may forbid (even loopback) networking - the workload then simply
        # covers less
        @warn "precompile serve workload failed - skipping" exception = e
    finally
        close(browser_display)
    end
    return
end

@compile_workload begin
    # Render an app with the common widgets through the same path
    # `display`/`show(io, MIME"text/html"(), app)` takes at runtime.
    app = App(; title = "precompile") do session::Session
        slider = Slider(1:10)
        button = Button("press")
        textfield = TextField("text")
        checkbox = Checkbox(true)
        result = Observable(0.0)
        on(session, slider.value) do value
            result[] = value / 2
        end
        onjs(session, slider.value, js"x => x + 1")
        return DOM.div(
            DOM.h1("Bonito"),
            Bonito.Card(DOM.div(slider, button, textfield, checkbox, result)),
        )
    end
    show(IOBuffer(), MIME"text/html"(), app)

    # Serve the app over a real loopback request and websocket exchange (like
    # HTTP.jl's own workload does): the listener/stream-handler/websocket-
    # decoder task bodies only compile when a request actually arrives.
    serve_workload(app)

    # The binary websocket message path: this is what a live browser
    # connection compiles on its first message exchange. (`sess`, not `session`:
    # the latter shadows Bonito's `session` function, tripping a soft-scope
    # warning inside the `@compile_workload` block.)
    sess = Session()
    payload = Dict{Symbol, Any}(
        :f32 => rand(Float32, 8),
        :f64 => rand(Float64, 8),
        :i32 => Int32[1, 2, 3],
        :u8 => UInt8[0x1, 0x2],
        :str => "hello",
        :bool => true,
        :obs => Observable(rand(Float32, 4)),
        :nested => Dict{Symbol, Any}(:a => 1, :b => [1.0, 2.0], :c => nothing),
        :vec => Any[1, "two", 3.0],
    )
    Bonito.serialize_binary(sess, payload)
    Bonito.serialize_binary(Bonito.SerializedMessage(sess, payload))
    close(sess)

    # Cleanup globals to avoid serializing stale state (servers, sessions,
    # tasks). Also shuts down the Reseau IO poller on HTTP.jl 2.x, without
    # which the precompile process never exits.
    Bonito.cleanup_globals()
    nothing
end

# Electron cannot run while precompiling, so the electron display entry
# point is compiled via a directive (it is the first thing a WGLMakie
# display hits at runtime).
precompile(Base.display, (HTTPServer.ElectronDisplay, App))
