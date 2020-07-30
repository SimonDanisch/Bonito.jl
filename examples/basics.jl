md"""
# What is JSServe?

* a connection between Julia & Javascript
* a reactive DOM
* a server with routing
* can be used for dashboards, wrapping JS libraries & writing webpages
* Similar to React.js in some ways
"""

using JSServe, Observables
using JSServe: @js_str, onjs, with_session, onload, Button, TextField, Slider, linkjs, serve_dom
using JSServe.DOM

function dom_handler(session, request)
    return DOM.h1("Hello World")
end

isdefined(Main, :app) && close(app)
app = JSServe.Application(dom_handler, "127.0.0.1", 8081)

md"""
# Interaction with observables
"""

color = Observable("red")
color_css = map(x-> "color: $(x)", color)
function dom_handler(session, request)
    return DOM.h1("Hello World", style=map(x-> "color: $(x)", color))
end

color[] = "red"


function dom_handler(session, request)
    button = DOM.div("click me", onclick=js"update_obs($(color), 'blue')")
    return DOM.div(
        button, DOM.h1("Hello World", style=map(x-> "color: $(x)", color))
    )
end

md"""
# Other ways to execute Javascript
"""

function dom_handler1(session, request)
    button = DOM.div("click me", onclick=js"update_obs($(color), 'blue')")
    onload(session, button, js"""function load(button){
        console.log("button")
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

md"""
# Including assets & Widgets
"""

MUI = JSServe.Asset("//cdn.muicss.com/mui-0.10.1/css/mui.min.css")
sliderstyle = JSServe.Asset(joinpath(@__DIR__, "sliderstyle.css"))
image = JSServe.Asset(joinpath(@__DIR__, "assets", "julia.png"))

function dom_handler(session, request)
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
md"""
# Can also use regex here!
# ctx contains route, match,
"""

JSServe.route!(app, "/example1" => ctx-> serve_dom(ctx, dom_handler1))
