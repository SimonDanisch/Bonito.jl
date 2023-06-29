@testset "serialization" begin

    xx = "hey"; some_js = js"var"; x = [1f0, 2f0]

    js_str = js"console.log($xx); $x; $((2, 4)); $(some_js) hello = 1;"

    expect = "console.log('hey'); JSServe.deserialize_js({\"__javascript_type__\":\"TypedVector\",\"payload\":[1.0,2.0]}); JSServe.deserialize_js([2,4]); var hello = 1;"
    @test string(js_str) == expect

    asset = JSServe.Asset("file.dun_exist"; check_isfile=false)
    test_throw() = JSServe.include_asset(JSServe.Asset("file.dun_exist"))
    Test.@test_throws ErrorException("Unrecognized asset media type: dun_exist") test_throw()

    function test_handler(session, request)
        obs1 = Observable(Float16(2.0))
        obs2 = Observable(DOM.div("Data: ", obs1, dataTestId="hey"))
        return DOM.div(obs2)
    end
    testsession(test_handler, port=8555) do app
        hey = query_testid("hey")
        @test evaljs(app, js"$(hey).innerText") == "Data: 2.0"
        float16_obs = children(children(app.dom)[1][])[2]
        float16_obs[] = Float16(77)
        @test evaljs(app, js"$(hey).innerText") == "Data: 77"
    end
end

@testset "http" begin
    @test_throws ErrorException("Invalid sessionid: lol") JSServe.request_to_sessionid((target="lol",))
    @test JSServe.request_to_sessionid((target="lol",), throw=false) === nothing
end

@testset "hyperscript" begin
    function handler(session, request)
        the_script = DOM.script("window.testglobal = 42")
        s1 = Hyperscript.Style(css("p", fontWeight="bold"), css("span", color="red"))
        the_style = DOM.style(Hyperscript.styles(s1))
        return DOM.div(:hello, the_style, the_script, dataTestId="hello")
    end

    testsession(handler) do app
        @test evaljs(app, js"window.testglobal")  == 42
        hello_div = query_testid("hello")
        @test evaljs(app, js"$(hello_div).innerText")  == "hello"
        @test evaljs(app, js"$(hello_div).children.length") == 3
        @test evaljs(app, js"$(hello_div).children[0].tagName") == "P"
        @test evaljs(app, js"$(hello_div).children[1].tagName") == "STYLE"
        @test evaljs(app, js"$(hello_div).children[2].tagName") == "SCRIPT"
    end
end

@testset "async messages" begin
    obs = Observable(0); counter = Observable(0)
    testing_started = Ref(false)
    function handler(session, request)
        # Dont start this!
        testing_started[] && return DOM.div()
        onjs(session, obs, js"""function (v) {
            var t = $(counter).notify($(counter).value + 1);
        }""")

        for i in 1:2
            obs[] += 1
        end
        @async begin
            yield()
            for i in 1:2
                obs[] += 1
                yield()
            end
        end
        @async begin
            yield()
            for i in 1:2
                obs[] += 1
                yield()
            end
        end
        return DOM.div(obs, counter)
    end
    # Ugh, ElectronTests loads the handler multiple times to make sure it works
    # and doesn't get stuck, so we need to do this manually
    @isdefined(app) && close(app)
    app = JSServe.Server(handler, "0.0.0.0", 8558)
    try
        eapp = Electron.Application()
        window = Electron.Window(eapp)
        try
            @test obs[] == 0
            @test counter[] == 0
            testing_started[] = true
            Electron.load(window, URI(string("http://localhost:", 8558)))
            @wait_for counter[] == obs[]
        finally
            close(eapp)
        end
    finally
        close(app)
    end
end

@testset "Dependencies" begin
    jss = js"""function (v) {
        console.log($(JSServe.JSServeLib));
    }"""
    app = App() do
        DOM.div(onclick=jss)
    end
    s = JSServe.Session()
    dom = sess
    JSServe.serialize_binary(s, div)
    @test JSTest in values(s.session_objects)
end

@testset "relocatable" begin
    deps = [
        JSServe.MsgPackLib => "js",
        JSServe.PakoLib => "js",
        JSServe.JSServeLib => "js",
        JSServe.MarkdownCSS => "css",
        JSServe.TailwindCSS => "css",
        JSServe.Styling => "css",
    ]
    for (asset, ext) in deps
        @test asset isa Asset
        @test isempty(asset.online_path)
        @test getfield(asset, :local_path) isa RelocatableFolders.Path
        @test asset.local_path isa String
        @test ispath(asset.local_path)
        @test asset.media_type == Symbol(ext)
    end

    # make sure that assets with `String` or with `RelocatableFolders.Path` behave consistently
    libpath1 = JSServer.Styling.local_path
    libpath2 = @path libpath1
    asset1, asset2 = Asset(libpath1), Asset(libpath2)
    for key in (:media_type, :online_path, :local_path, :onload)
        @test getproperty(asset1, key) == getproperty(asset2, key)
    end
end

@testset "range slider" begin
    function test_handler(session, req)
        rslider = JSServe.RangeSlider(1:100; value=[10, 80])
        start = map(first, rslider)
        stop = map(last, rslider)
        return DOM.div(rslider, start, stop, id="rslider")
    end
    testsession(test_handler, port=8555) do app
        # Lets not be too porcelainy about this ...
        rslider = getfield(app.dom, :children)[1]
        @test rslider[] == [10, 80]
        rslider_html = js"document.getElementById('rslider')"
        @test evaljs(app, js"$(rslider_html).children.length") == 3
        @test evaljs(app, js"$(rslider_html).children[1].innerText") == "10"
        @test evaljs(app, js"$(rslider_html).children[2].innerText") == "80"
        rslider[] = [20, 70]
    end
end
