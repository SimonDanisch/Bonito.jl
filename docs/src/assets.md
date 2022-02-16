# Assets


```julia
some_file = Asset("path/to/local/file")
# ES6Module creates an Asset with the flags set appropriately to
# treat it as a module
jsmodule = ES6Module("path/to/local/es6module.js")::Asset

# These assets can be interpolated into DOM elements and js strings:
js"""
// this will result in importing jsmodule
// Doing this in many places will only import jsmodule once
const {the, funcs, you, want} = $(jsmodule)
// This will give you the raw bytes as a Uint8Array
const raw_file_bytes = $(some_file)
"""

# This will resolve to a valid URL depending on the used asset server
DOM.img(src=some_file)

# This will also resolve to a valid URL and load jsmodule as an es6 module
DOM.sript(src=jsmodule, type="module")

# Assets also work with online sources, which is great for online dependencies!
# Usage is exactly the same as when using local files
THREE = ES6Module("https://unpkg.com/three@0.136.0/build/three.js")
# Also offer an easy way to use packages from a CDN (currently esm.sh):
THREE = CDNSource("three"; version="0.137.5")
```
