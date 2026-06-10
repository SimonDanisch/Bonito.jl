using PrecompileTools

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

    # The binary websocket message path: this is what a live browser
    # connection compiles on its first message exchange.
    session = Session()
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
    Bonito.serialize_binary(session, payload)
    Bonito.serialize_binary(Bonito.SerializedMessage(session, payload))
    close(session)

    # Cleanup globals to avoid serializing stale state (servers, sessions,
    # tasks). Also shuts down the Reseau IO poller on HTTP.jl 2.x, without
    # which the precompile process never exits.
    Bonito.cleanup_globals()
    nothing
end
