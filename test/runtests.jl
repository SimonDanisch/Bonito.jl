# Needs to be done before loading Bonito
include("test-bundles.jl")
using Bonito
using Hyperscript, Markdown, Test, RelocatableFolders
using Observables
using Bonito: Session, evaljs, linkjs, div

using Bonito: onjs, JSString, Asset, jsrender
using Bonito: @js_str, uuid, SerializationContext, serialize_binary
using Bonito.DOM
using Bonito.HTTP
using ElectronCall
using URIs
using Random
using Hyperscript: children
using Bonito.MsgPack
using Bonito.CodecZlib
using Test
using Bonito: jsrender

include("ElectronTests.jl")
include("test_helpers.jl")

function wait_on_test_observable(trigger; timeout=20)
    global test_observable
    test_channel = Channel{Dict{String,Any}}(1)
    f = on(test_observable) do value
        put!(test_channel, value)
    end
    try
        # Fire the round-trip ONLY after the listener is registered. The old
        # `test_value` ran the trigger on the main task while registering this
        # listener in a deferred `@async` — racy: on HTTP@2 the frontend
        # round-trip can complete and fire `test_observable` before the listener
        # attaches, so the value is missed and the test hangs. Triggering here,
        # post-registration, closes that gap.
        trigger()
        t0 = time()
        while !isready(test_channel)
            if time() - t0 > timeout
                # Capture the live deadlock/lost-message state for diagnosis.
                try
                    open("/tmp/widgets_bt.txt", "w") do io
                        redirect_stderr(io) do
                            ccall(:jl_print_task_backtraces, Cvoid, (Cint,), 0)
                        end
                    end
                catch
                end
                error("wait_on_test_observable: no frontend round-trip after $(timeout)s — the browser→server observable notify was lost/never processed (likely threading race). Backtraces -> /tmp/widgets_bt.txt")
            end
            sleep(0.01)
        end
        return take!(test_channel)
    finally
        off(test_observable, f)
    end
end

"""
    test_value(app, statement)
Executes statement (js code, or julia function with 0 args),
And waits on `test_observable` to push a new value!
Returns new value from `test_observable`
"""
function test_value(app, statement)
    return wait_on_test_observable() do
        if statement isa Bonito.JSCode
            Bonito.evaljs(app.session, statement)
        else
            statement()
        end
    end
end


function OfflineSession()
    return Session(NoConnection(); asset_server=NoServer())
end

# Reuse the shared Electron Application for all test windows.
# Devtools stays CLOSED (the window opens with devtools closed; calling
# `toggle_devtools` here would OPEN it, and an open devtools floods the log with
# `devtools://… Autofill.enable failed` protocol errors on every navigation).
# Set BONITO_TEST_DEVTOOLS=1 to open devtools for debugging.
function TestWindow(args...; options=Dict{String, Any}("show" => true, "focusOnWebView" => false))
    win = Bonito.EWindow(args...; app=get_test_app(), options=options)
    get(ENV, "BONITO_TEST_DEVTOOLS", "") == "1" && ElectronCall.toggle_devtools(win.window)
    return win
end


win = TestWindow()

function _rf(f)
    name = replace(basename(f), ".jl" => "")
    printstyled("▶ running tests: $name\n"; color=:cyan, bold=true)
    t = @elapsed include(f)
    printstyled("  ✓ $name ($(round(t; digits=1))s)\n"; color=:light_black)
end
@testset "Bonito" begin
    printstyled("Bonito test suite — NTHREADS=$(Threads.nthreads())\n"; color=:cyan, bold=true)
    global edisplay = Bonito.use_electron_display(; app=get_test_app(), options=Dict{String, Any}("show" => false, "focusOnWebView" => false), devtools=false)
    @testset "Default Connection" begin
        @testset "websocket-closing" begin
            _rf("websocket-closing.jl")
        end
        @testset "components" begin
            _rf("components.jl")
        end
        @testset "styling" begin
            _rf("styling.jl")
        end
        @testset "threading" begin
            _rf("threading.jl")
        end
        @testset "server" begin
            _rf("server.jl")
        end
        @testset "subsessions" begin
            _rf("subsessions.jl")
        end
        @testset "key_not_found_race" begin
            _rf("key_not_found_race.jl")
        end
        @testset "race_conditions_audit" begin
            _rf("race_conditions_audit.jl")
        end
        @testset "connection-serving" begin
            _rf("connection-serving.jl")
        end
        # loading_page must run before serialization, which closes the global
        # Bonito server via testsession() and kills the edisplay window.
        @testset "loading_page" begin
            _rf("loading_page.jl")
        end
        @testset "serialization" begin
            _rf("serialization.jl")
        end
        @testset "protocol_roundtrip" begin
            _rf("protocol_roundtrip.jl")
        end
        @testset "session_io" begin
            _rf("session_io.jl")
        end
        @testset "error_handling" begin
            _rf("error_handling.jl")
        end
        @testset "widgets" begin
            _rf("widgets.jl")
        end
        # @testset "various" begin; _rf("various.jl"); end
        @testset "commonmark" begin
            _rf("commonmark.jl")
        end
        @testset "markdown" begin
            _rf("markdown.jl")
        end
        @testset "basics" begin
            _rf("basics.jl")
        end
        @testset "handlers" begin
            _rf("handlers.jl")
        end
        @testset "export" begin
            _rf("export_tests.jl")
        end
    end
    close(edisplay)
    global edisplay = Bonito.use_electron_display(; app=get_test_app(), options=Dict{String, Any}("show" => false, "focusOnWebView" => false), devtools=false)
    @testset "Compression true + DualWebsocket" begin
        @testset "Compression + DualWebsocket" begin
            Bonito.use_compression!(true)
            Bonito.force_connection!(Bonito.DualWebsocket)
            @testset "components" begin
                _rf("components.jl")
            end
            @testset "threading" begin
                _rf("threading.jl")
            end
            @testset "server" begin
                _rf("server.jl")
            end
            @testset "subsessions" begin
                _rf("subsessions.jl")
            end
            @testset "serialization" begin
                _rf("serialization.jl")
            end
            @testset "widgets" begin
                _rf("widgets.jl")
            end
            @testset "markdown" begin
                _rf("markdown.jl")
            end
        end
    end
    close(edisplay)
    close_test_app()
end
