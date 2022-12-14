using Markdown
md"""
# What is JSServe?

* a connection between Julia & Javascript
* a reactive DOM
* a server with routing
* can be used for dashboards, wrapping JS libraries & writing webpages
* Similar to React.js in some ways
"""

using JSServe, Observables
using JSServe: @js_str, Session, App, onjs, onload, Button
using JSServe: TextField, Slider, linkjs
JSServe.browser_display()

app = App(DOM.h1("Hello World"))
display(app)


md"""
# Interaction with observables
"""

color = Observable("red")
color_css = map(x-> "color: $(x)", color)

app = App() do
    return DOM.h1("Hello World", style=map(x-> "color: $(x)", color))
end
display(app)

color[] = "green"

app = App() do
    color = Observable("red")
    on(println, color)
    button = DOM.div("click me", onclick=js"""(e)=> {
        const color = '#' + ((1<<24)*Math.random() | 0).toString(16)
        console.log(color)
        $(color).notify(color)
    }""")
    style = map(x-> "color: $(x)", color)
    return DOM.div(
        button, DOM.h1("Hello World", style=style)
    )
end
display(app)

md"""
# Other ways to execute Javascript
"""

app = App() do session::Session
    color = Observable("red")
    button = DOM.div("click me", onclick=js"e=> $(color).notify('blue')")
    onload(session, button, js"""function load(button){
        window.alert('Hi from JavaScript');
    }""")

    onjs(session, color, js"""function update(value){
        window.alert(value);
        // throw "heey!"
    }""")

    return DOM.div(
        button, DOM.h1("Hello World", style=map(x-> "color: $(x)", color))
    )
end
display(app)

md"""
# Including assets & Widgets
"""

MUI = JSServe.Asset("https://cdn.muicss.com/mui-0.10.1/css/mui.min.css")
sliderstyle = JSServe.Asset(joinpath(@__DIR__, "sliderstyle.css"))
image = JSServe.Asset(joinpath(@__DIR__, "assets", "julia.png"))
s = JSServe.HTTPServer.get_server();

JSServe.url(Session(asset_server=JSServe.HTTPAssetServer(s)).asset_server, MUI)

app = App() do
    button = JSServe.Button("hi", class="mui-btn mui-btn--primary")
    slider = JSServe.Slider(1:10, class="slider")

    on(button) do click
        @show click
    end

    on(slider) do slidervalue
        @show slidervalue
    end
    link = DOM.a(href="/example1", "GO TO ANOTHER WORLD")
    return DOM.div(MUI, sliderstyle, link, button, slider, DOM.img(src=image))
end
display(app)

md"""
# Can also use regex here!
# ctx contains route, match,
"""

app = App() do
    color = Observable("red")
    on(println, color)
    button = DOM.div("click me", onclick=js"""(e)=> {
        const color = '#' + ((1<<24)*Math.random() | 0).toString(16)
        console.log(color)
        $(color).notify(color)
    }""")
    style = map(x-> "color: $(x)", color)
    return DOM.div(
        button, DOM.h1("Hello World", style=style)
    )
end
display(app)

JSServe.route!(JSServe.get_server(), "/example1" => app)

begin
    app = App() do session::Session
        slider = JSServe.Slider(1:10, class="slider m-4")
        squared = map(slider) do slidervalue
            return slidervalue^2
        end
        class = "p-2 rounded border-2 border-gray-600 m-4"
        v1 = DOM.div(slider.value, class=class)
        v2 = DOM.div(squared, class=class)
        dom = DOM.div(JSServe.TailwindCSS, "meep11", slider, sliderstyle, v1, v2)
        # statemap for static serving
        return dom
    end;
end

export_path = joinpath(@__DIR__, "demo")
mkdir(export_path)
routes = JSServe.Routes()
routes["/"] = app
JSServe.export_static(export_path, routes)

using LiveServer
cd(export_path)
LiveServer.serve()


using WGLMakie


scatter(rand(Point2f, 10))
