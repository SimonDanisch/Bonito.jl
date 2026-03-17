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

function wait_on_test_observable()
    global test_observable
    test_channel = Channel{Dict{String,Any}}(1)
    f = on(test_observable) do value
        put!(test_channel, value)
    end
    val = take!(test_channel)
    off(test_observable, f)
    return val
end

"""
    test_value(app, statement)
Executes statement (js code, or julia function with 0 args),
And waits on `test_observable` to push a new value!
Returns new value from `test_observable`
"""
function test_value(app, statement)
    val_t = @async wait_on_test_observable()
    if statement isa Bonito.JSCode
        Bonito.evaljs(app.session, statement)
    else
        statement()
    end
    return fetch(val_t)
end

function OfflineSession()
    return Session(NoConnection(); asset_server=NoServer())
end

# Reuse the shared ElectronCall Application for all test windows
function TestWindow(args...; options=Dict{String, Any}("show" => false, "focusOnWebView" => false))
    return Bonito.EWindow(args...; app=get_test_app(), options=options)
end

@testset "Bonito" begin
    global edisplay = Bonito.use_electron_display(; app=get_test_app(), options=Dict{String, Any}("show" => false, "focusOnWebView" => false), devtools=false)
    @testset "Default Connection" begin
        @testset "websocket-closing" begin
            include("websocket-closing.jl")
        end
        @testset "components" begin
            include("components.jl")
        end
        @testset "styling" begin
            include("styling.jl")
        end
        @testset "threading" begin
            include("threading.jl")
        end
        @testset "server" begin
            include("server.jl")
        end
        @testset "subsessions" begin
            include("subsessions.jl")
        end
        @testset "connection-serving" begin
            include("connection-serving.jl")
        end
        # loading_page must run before serialization, which closes the global
        # Bonito server via testsession() and kills the edisplay window.
        @testset "loading_page" begin
            include("loading_page.jl")
        end
        @testset "serialization" begin
            include("serialization.jl")
        end
        @testset "widgets" begin
            include("widgets.jl")
        end
        @testset "markdown" begin
            include("markdown.jl")
        end
        @testset "basics" begin
            include("basics.jl")
        end
        @testset "handlers" begin
            include("handlers.jl")
        end
        @testset "export" begin
            include("export_tests.jl")
        end
    end
    close(edisplay)
    global edisplay = Bonito.use_electron_display(; app=get_test_app(), options=Dict{String, Any}("show" => false, "focusOnWebView" => false), devtools=false)
    @testset "Compression true + DualWebsocket" begin
        @testset "Compression + DualWebsocket" begin
            Bonito.use_compression!(true)
            Bonito.force_connection!(Bonito.DualWebsocket)
            @testset "components" begin
                include("components.jl")
            end
            @testset "threading" begin
                include("threading.jl")
            end
            @testset "server" begin
                include("server.jl")
            end
            @testset "subsessions" begin
                include("subsessions.jl")
            end
            @testset "serialization" begin
                include("serialization.jl")
            end
            @testset "widgets" begin
                include("widgets.jl")
            end
            @testset "markdown" begin
                include("markdown.jl")
            end
        end
    end
    close(edisplay)
    close_test_app()
end
