# Time ONLY the loading_page testset (sd/v5 harness). Run from this test/ dir.
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
include("ElectronTests.jl")
include("test_helpers.jl")

function wait_on_test_observable()
    global test_observable
    test_channel = Channel{Dict{String,Any}}(1)
    f = on(test_observable) do value; put!(test_channel, value); end
    val = take!(test_channel); off(test_observable, f); return val
end
function test_value(app, statement)
    val_t = @async wait_on_test_observable()
    statement isa Bonito.JSCode ? Bonito.evaljs(app.session, statement) : statement()
    return fetch(val_t)
end
function TestWindow(args...; options=Dict{String, Any}("show" => false, "focusOnWebView" => false))
    return Bonito.EWindow(args...; app=get_test_app(), options=options)
end

println(">>> HTTP=", pkgversion(Bonito.HTTP), " threads=", Threads.nthreads()); flush(stdout)
global edisplay = Bonito.use_electron_display(; app=get_test_app(), options=Dict{String, Any}("show" => false, "focusOnWebView" => false), devtools=false)
t = @elapsed @testset "loading_page" begin
    include("loading_page.jl")
end
println(">>> LOADING_PAGE (sd/v5, HTTP1) TOOK $(round(t; digits=1))s"); flush(stdout)
close(edisplay)
close_test_app()
