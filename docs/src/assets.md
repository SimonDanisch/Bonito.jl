# Assets

Assets in Bonito represent external resources like JavaScript libraries, CSS files, images, and other files. They handle loading, bundling, and serving these resources efficiently across different deployment ways (Server/Plotpane/Notebooks/Static Site/Documenter).

## Basic Usage

Assets can reference local files or remote URLs and are automatically served with the appropriate URLs:

```@setup 1
using Bonito
Page()
```

```@example 1
using Bonito

# Load a local image
dashi_logo = Asset(joinpath(@__DIR__, "dashi.png"))

# Create an app that displays the image
app = App() do
    # Use CSS class selector to style child images of this specific container
    img_styles = Styles(CSS(".asset-container > img", "width" => "400px"))
    DOM.div(
        img_styles,
        DOM.div(
            DOM.h2("Asset Example"),
            DOM.p("Assets render automatically as the appropriate DOM element:"),
            dashi_logo,  # Automatically becomes DOM.img(src=url_to_asset)
            DOM.p("Or use assets as src attributes for more control:"),
            DOM.img(src=dashi_logo; width="400px");  # Asset URL is inserted as src
            class="asset-container"
        )
    )
end
```

## JavaScript Assets

JavaScript assets come in two flavors: ES6 modules and traditional scripts.

### ES6 Modules

ES6 modules are bundled with their dependencies and loaded as modules:

```julia
# ES6Module creates an Asset with es6module=true
jsmodule = ES6Module("path/to/local/module.js")

# Interpolating in JS code returns a Promise with the module exports
js"""
$(jsmodule).then(module => {
    module.someFunction();
})
"""
# Works with CDN sources too
THREE = ES6Module("https://unpkg.com/three@0.136.0/build/three.js")
# Convenient CDN helper (uses esm.sh):
THREE = CDNSource("three"; version="0.137.5")
```

### Traditional Scripts (Non-module)

For traditional JavaScript libraries that expose global variables (like jQuery, ACE editor, etc.):

```julia
# The Asset automatically infers the global name from the filename
ace = Asset("https://cdn.jsdelivr.net/ace-builds/src-min/ace.js")
# name is automatically set to "ace"

# Interpolating returns a Promise that resolves with the global object
js"""
$(ace).then(ace => {
    const editor = ace.edit(element);
})
"""
# Override the global name if needed
custom = Asset("https://example.com/library.js"; name="MyLib")
```

### Binary Assets

Non-JavaScript assets are loaded as raw bytes when interpolated into javascript:

```julia
image = Asset("path/to/image.png")

js"""
$(image).then(bytes => {
    // bytes is a Uint8Array
})
"""
```

Full ES6Module example creating a THREEJS visualization:

```@example 1
# Javascript & CSS dependencies can be declared locally and
# freely interpolated in the DOM / js string, and will make sure it loads
# Note, that they will be a `Promise` though, so to use them you need to call `module.then(module=> ...)`.
const THREE = ES6Module("https://cdn.esm.sh/v66/three@0.136/es2021/three.js")

app = App() do session, request
    width = 500; height = 500
    dom = DOM.div(width = width, height = height)
    Bonito.onload(session, dom, js"""
        function (container){
            $(THREE).then(THREE=> {
                var renderer = new THREE.WebGLRenderer({antialias: true});
                renderer.setSize($width, $height);
                renderer.setClearColor("#ffffff");
                container.appendChild(renderer.domElement);
                var scene = new THREE.Scene();
                var camera = new THREE.PerspectiveCamera(75, $width / $height, 0.1, 1000);
                camera.position.z = 4;
                var ambientLight = new THREE.AmbientLight(0xcccccc, 0.4);
                scene.add(ambientLight);
                var pointLight = new THREE.PointLight(0xffffff, 0.8);
                camera.add(pointLight);
                scene.add(camera);
                var geometry = new THREE.SphereGeometry(1.0, 32, 32);
                var material = new THREE.MeshPhongMaterial({color: 0xffff00});
                var sphere = new THREE.Mesh(geometry, material);
                scene.add(sphere);
                renderer.render(scene, camera);
            })
        }
    """)
    return dom
end
```
