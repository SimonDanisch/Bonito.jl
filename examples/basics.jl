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
using JSServe: TextField, Slider, linkjs, get_server
using JSServe.DOM
using JSServe: JSON3
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
    button = DOM.div("click me", onclick=js"JSServe.update_obs($(color), 'blue')")
    return DOM.div(
        button, DOM.h1("Hello World", style=map(x-> "color: $(x)", color))
    )
end
display(app)

md"""
# Other ways to execute Javascript
"""

app = App() do session::Session
    button = DOM.div("click me", onclick=js"JSServe.update_obs($(color), 'blue')")
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

MUI = JSServe.Asset("//cdn.muicss.com/mui-0.10.1/css/mui.min.css")
sliderstyle = JSServe.Asset(joinpath(@__DIR__, "sliderstyle.css"))
image = JSServe.Asset(joinpath(@__DIR__, "assets", "julia.png"))

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
    button = DOM.div("click me", onclick=js"JSServe.update_obs($(color), 'blue')")
    return DOM.div(
        button, DOM.h1("Hello World", style=map(x-> "color: $(x)", color))
    )
end
display(app)

JSServe.route!(get_server(), "/example1" => app)
#wait(get_server()) # This call will block execution of the script and bring the server event loop to the foreground

app = App() do session::Session
    slider = JSServe.Slider(1:10, class="slider m-4")
    squared = map(slider) do slidervalue
        return slidervalue^2
    end
    class = "p-2 rounded border-2 border-gray-600 m-4"
    v1 = DOM.div(slider.value, class=class)
    v2 = DOM.div(squared, class=class)
    dom = DOM.div(JSServe.TailwindCSS, slider, sliderstyle, v1, v2)
    # statemap for static serving
    return JSServe.record_state_map(session, (s, r)-> dom)
end

export_path = joinpath(@__DIR__, "demo")
mkdir(export_path)
JSServe.export_standalone(app, export_path, clear_folder=true)

using LiveServer
cd(export_path)
LiveServer.serve()
