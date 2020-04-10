using JSServe
using JSServe: JSObject, Slider, onload, @js_str, on

const THREE = JSServe.Dependency(
    :THREE,
    ["https://cdn.jsdelivr.net/gh/mrdoob/three.js/build/three.min.js"]
)

function dom_handler(session, request)
    width, height = 200, 200

    canvas = DOM.um("canvas"; width=width, height=height)

    Three, renderer = JSObject(session, :THREE), JSObject(session, :renderer)

    onload(session, canvas, js"""function (canvas){
        const renderer = new $THREE.WebGLRenderer({
            antialias: true, canvas: canvas
        });
        put_on_heap($(JSServe.uuidstr(Three)), $THREE);
        put_on_heap($(JSServe.uuidstr(renderer)), renderer);
    }""")

    scene = Three.new.Scene()
    # Create a basic perspective camera
    camera = Three.new.PerspectiveCamera(75, width / height, 0.1, 50)
    camera.position.z = 4
    renderer.setSize(width, height)
    renderer.setClearColor("#fff")
    geometry = Three.new.BoxGeometry(2, 2, 2)
    material = Three.new.MeshBasicMaterial(color = "#433F81")
    cube = Three.new.Mesh(geometry, material);
    scene.add(cube)
    renderer.render(scene, camera)

    slider = Slider(LinRange(0.0, 2pi, 200); style="display: block")

    on(slider) do value
        cube.rotation.x = value
        cube.rotation.y = value
        renderer.render(scene, camera)
    end

    return DOM.div(slider, canvas)
end


isdefined(Main, :app) && close(app)

app = JSServe.Application(
    dom_handler,
    "127.0.0.1", 8081, verbose = false
)
