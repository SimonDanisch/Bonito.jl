# JSServe Introduction

```@setup 1
using JSServe
JSServe.Page()
```

```@example 1
using JSServe
App() do
    DOM.h1("hello world")
end
```


```@example 1
# Javascript & CSS dependencies can be declared locally and
# freely interpolated in the DOM / js string, and will make sure it loads
# Note, that they will be a `Promise` though, so to use them you need to call `module.then(module=> ...)`.
const THREE = ES6Module("https://cdn.esm.sh/v66/three@0.136/es2021/three.js")

app = App() do session, request
    width = 500; height = 500
    dom = DOM.div(width = width, height = height)
    JSServe.onload(session, dom, js"""
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
