using Hyperscript, Markdown, Test, RelocatableFolders
using JSServe, Observables
using JSServe: Session, evaljs, linkjs, div
using JSServe: onjs, JSString, Asset, jsrender
using JSServe: @js_str, uuid, SerializationContext, serialize_binary
using JSServe.DOM
using JSServe.HTTP
using Electron
using URIs
using Random
using Hyperscript: children
using JSServe.MsgPack
using JSServe.CodecZlib
using Test
using JSServe: jsrender
rm(JSServe.bundle_path(JSServe.JSServeLib))
include("ElectronTests.jl")

using Electron.FilePaths


@testset "Electron" begin

    @testset "Core" begin

        testpagepath = joinpath(Electron.@__PATH__, p"test.html")

        w = Window(URI(testpagepath))

        a = applications()[1]

        @test isa(w, Window)

        @test length(applications()) == 1
        @test length(windows(a)) == 1

        res = run(w, "Math.log(Math.exp(1))")

        @test res == 1

        @test_throws ErrorException run(w, "syntaxerror")

        res = run(a, "Math.log(Math.exp(1))")

        @test res == 1

        close(w)
        @test length(applications()) == 1
        @test isempty(windows(a))

        w2 = Window(joinpath(@__PATH__, p"test.html"))

        toggle_devtools(w2)

        close(a)
        @test length(applications()) == 1
        @test length(windows(a)) == 0

        sleep(1)
        @test isempty(applications())
        @test isempty(windows(a))

        w3 = Window(Dict("url" => string(URI(testpagepath))))

        w4 = Window(URI(testpagepath), options=Dict("title" => "Window title"))

        w5 = Window("<body></body>", options=Dict("title" => "Window title"))

        a2 = applications()[1]

        w6 = Window(a2, "<body></body>", options=Dict("title" => "Window title"))

        w7 = Window(a2)

        run(w7, "sendMessageToJulia('foo')")

        @test take!(msgchannel(w7)) == "foo"

        load(w7, "<body>bar</body>")

        run(w7, "sendMessageToJulia(window.document.documentElement.innerHTML)")

        @test occursin("bar", take!(msgchannel(w7)))

        load(w7, joinpath(@__PATH__, p"test.html"))
        load(w7, URI(joinpath(@__PATH__, p"test.html")))

        close(w7)

        close(w3)
        close(w4)
        close(w5)
        close(w6)
        close(a2)

    end # testset "Core"

    @testset "ElectronAPI" begin
        win = Window()

        @test (ElectronAPI.setBackgroundColor(win, "#000"); true)
        @test ElectronAPI.isFocused(win) isa Bool

        bounds = ElectronAPI.getBounds(win)
        boundskeys = ["width", "height", "x", "y"]
        @test Set(boundskeys) <= Set(keys(bounds))
        @test all(isa.(get.(Ref(bounds), boundskeys, nothing), Real))

        close(win)
    end

    for app in applications()
        close(app)
    end
end



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

@testset "JSServe" begin
    @testset "connection-serving" begin; include("connection-serving.jl"); end
    @testset "serialization" begin; include("serialization.jl"); end
    @testset "widgets" begin; include("widgets.jl"); end
    # @testset "various" begin; include("various.jl"); end
    @testset "markdown" begin; include("markdown.jl"); end
    @testset "basics" begin; include("basics.jl"); end
end
