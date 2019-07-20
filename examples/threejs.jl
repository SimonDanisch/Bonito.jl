using Hyperscript
using JSServe, Observables
using JSServe: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, font, onjs, Button, TextField, Slider, JSString, Dependency, with_session

const THREE = JSServe.Dependency(
    :THREE,
    [
        "https://cdn.jsdelivr.net/gh/mrdoob/three.js/build/three.min.js",
    ]
)

struct ThreeScene
end

function JSServe.jsrender(session::Session, ::ThreeScene)
    dom = div(width = 500, height = 500)
    threejs, renderer = JSObject(session, :THREE), JSObject(session, renderer)
    JSServe.onload(session, dom, js"""
        function (container){
            var renderer = new $(THREE).WebGLRenderer({antialias: true})
            renderer.setSize($width, $height)
            renderer.setClearColor("#ffffff")
            container.appendChild(renderer.domElement);
            set_jso($renderer, renderer)
            set_jso($(THREE), threejs)
        }
    """)
    return dom
end
