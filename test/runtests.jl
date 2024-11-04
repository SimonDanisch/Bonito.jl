using Bonito
# ENV["JULIA_DEBUG"] = Bonito

using Deno_jll
using Hyperscript, Markdown, Test, RelocatableFolders
using Observables
using Bonito: Session, evaljs, linkjs, div

using Bonito: onjs, JSString, Asset, jsrender
using Bonito: @js_str, uuid, SerializationContext, serialize_binary
using Bonito.DOM
using Bonito.HTTP
using Electron
using URIs
using Random
using Hyperscript: children
using Bonito.MsgPack
using Bonito.CodecZlib
using Test
using Bonito: jsrender
include("ElectronTests.jl")

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
Executes statemen (js code, or julia function with 0 args),
And waits on `test_observable` to push a new value!
Returns new value from `test_observable`
"""
function test_value(app, statement)
    # First start waiting on the test communication channel
    # We do this async before scheduling the js, since otherwise there is a
    # chance, that the event gets triggered before we have a chance to wait for it
    # which would make use wait forever
    val_t = @async wait_on_test_observable()
    # eval our js expression that is supposed to write something to test_observable
    if statement isa Bonito.JSCode
        Bonito.evaljs(app.session, statement)
    else
        statement()
    end
    return fetch(val_t) # fetch the value!
end

function OfflineSession()
    return Session(NoConnection(); asset_server=NoServer())
end

edisplay = Bonito.use_electron_display(; devtools=true)

@testset "Bonito" begin
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
    @testset "serialization" begin
        include("serialization.jl")
    end
    @testset "widgets" begin
        include("widgets.jl")
    end
    # @testset "various" begin; include("various.jl"); end
    @testset "markdown" begin
        include("markdown.jl")
    end
    @testset "basics" begin
        include("basics.jl")
    end
end
