using Markdown
md"""
# What is Bonito?

* a connection between Julia & Javascript
* a reactive DOM
* a server with routing
* can be used for dashboards, wrapping JS libraries & writing webpages
* Similar to React.js in some ways
"""

using Bonito, Observables
using Bonito: @js_str, Session, App, onjs, onload, Button
using Bonito: TextField, Slider, linkjs
Bonito.browser_display()

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

MUI = Bonito.Asset("https://cdn.muicss.com/mui-0.10.1/css/mui.min.css")
sliderstyle = Bonito.Asset(joinpath(@__DIR__, "sliderstyle.css"))
image = Bonito.Asset(joinpath(@__DIR__, "assets", "julia.png"))
s = Bonito.get_server();

app = App() do
    button = Bonito.Button("hi", class="mui-btn mui-btn--primary")
    slider = Bonito.Slider(1:10, class="slider")

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

Bonito.route!(Bonito.get_server(), "/example1" => app)

app = App() do session::Session
    slider = Bonito.Slider(1:10, class="slider m-4")
    squared = map(slider) do slidervalue
        return slidervalue^2
    end
    class = "p-2 rounded border-2 border-gray-600 m-4"
    v1 = DOM.div(slider.value, class=class)
    v2 = DOM.div(squared, class=class)
    dom = DOM.div(Bonito.TailwindCSS, "Hello", slider, sliderstyle, v1, v2)
    # statemap for static serving
    # return dom
    return Bonito.record_states(session, dom)
end;

export_path = joinpath(@__DIR__, "demo")
mkdir(export_path)
routes = Bonito.Routes()
routes["/"] = app
Bonito.export_static(export_path, routes)

# Or just `Bonito.export_static("index.html", app)` to export the app to a single file!

# Then one can use liveserver to host the static export:
using LiveServer
cd(export_path)
LiveServer.serve()
