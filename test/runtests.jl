using Hyperscript, Markdown, Test, RelocatableFolders
using JSServe, Observables
using JSServe: Session, evaljs, linkjs, div
using JSServe: onjs, JSString, Asset, Dependency, jsrender
using JSServe: @js_str, js_type, pointer_identity, uuid, serialize_js, SerializationContext, serialize_binary
using JSServe.DOM
using JSServe.HTTP
using Electron
using ElectronDisplay
using URIParser
using Random
using Hyperscript: children
using JSServe.MsgPack
using JSServe.CodecZlib
using Test
using JSServe: jsrender

include("ElectronTests.jl")

function wait_on_test_observable()
    global test_observable
    test_channel = Channel{Dict{String, Any}}(1)
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
    if statement isa JSServe.JSCode
        JSServe.evaljs(app.session, statement)
    else
        statement()
    end
    fetch(val_t) # fetch the value!
end

JSServe.JSSERVE_CONFIGURATION.listen_port[] = 8555

@testset "JSServe" begin
    @testset "serialization" begin; include("serialization.jl"); end
    @testset "checkbox" begin; include("checkbox.jl"); end
    @testset "various" begin; include("various.jl"); end
    @testset "markdown" begin; include("markdown.jl"); end
    @testset "basics" begin; include("basics.jl"); end
end
