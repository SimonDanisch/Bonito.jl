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
    JSServe.onload(session, dom, js"""
        function three_div(container){
            console.log(container)
            var scene = new $(THREE).Scene()
            var width = 500
            var height = 500
            // Create a basic perspective camera
            var camera = new $(THREE).PerspectiveCamera(75, width / height, 0.1, 1000)
            camera.position.z = 4
            var renderer = new $(THREE).WebGLRenderer({antialias: true})
            renderer.setSize(width, height)
            renderer.setClearColor("#ffffff")
            var geometry = new $(THREE).BoxGeometry(1.0, 1.0, 1.0)
            var material = new $(THREE).MeshBasicMaterial({color: "#433F81"})
            var cube = new $(THREE).Mesh(geometry, material);
            scene.add(cube)
            container.appendChild(renderer.domElement);
            // var controls = new $THREE.OrbitControls(camera, renderer.domElement);
            // controls.addEventListener( 'change', render );
            renderer.render(scene, camera)
        }
    """)
    return dom
end

using JSServe, Observables
using JSServe: Dependency, div, @js_str, font, onjs, Button, TextField, Slider, JSString, with_session, linkjs

global data = Observable(rand(1000))

function dom_handler(session, request)
    global data

    onjs(session, data, js"""
    function (data){
        console.log(data[0])
        console.log(data[data.length-1])
    }
    """)
    return JSServe.div("hi")
end

function test()
    data[] = rand(10^7)
    yield()
    yield()
end

MsgPack.pack(rand(10^1))


@time for i in 1:100
    data[] = rand(Float32, 128 ^ 3)
    yield()
end

using MsgPack, MsgPack2, CBOR
CBOR.enc

@profiler test()

sizeof(data[]) / 10^6
data[][1]
data[][end]

# id, session = last(active_sessions(app))
app = JSServe.Application(
    dom_handler,
    get(ENV, "WEBIO_SERVER_HOST_URL", "127.0.0.1"),
    parse(Int, get(ENV, "WEBIO_HTTP_PORT", "8081")),
    verbose = false
)


d = with_session() do session
    dom = div(width = 500, height = 500)
    JSServe.onload(session, dom, js"""
        function three_div(container){
            console.log(container)
            var scene = new $(THREE).Scene()
            var width = 500
            var height = 500
            // Create a basic perspective camera
            var camera = new $(THREE).PerspectiveCamera(75, width / height, 0.1, 1000)
            camera.position.z = 4
            var renderer = new $(THREE).WebGLRenderer({antialias: true})
            renderer.setSize(width, height)
            renderer.setClearColor("#ffffff")
            var geometry = new $(THREE).BoxGeometry(1.0, 1.0, 1.0)
            var material = new $(THREE).MeshBasicMaterial({color: "#433F81"})
            var cube = new $(THREE).Mesh(geometry, material);
            scene.add(cube)
            container.appendChild(renderer.domElement);
            // var controls = new $THREE.OrbitControls(camera, renderer.domElement);
            // controls.addEventListener( 'change', render );
            renderer.render(scene, camera)
        }
    """)
    return dom
end
