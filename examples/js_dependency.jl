using Bonito
using Bonito: onload, @js_str, Session, App
using Bonito.DOM

using Deno_jll # If you create your own javascript module, you need to include deno!

# First argument: Name of the Javascript module
# Second argument: Array of dependency. One needs to be the JavaScript file
# containing the module the others can be css files!
const JSModule = ES6Module(joinpath(@__DIR__, "JSModule.js"))

app = App() do session::Session
    hello_div = DOM.div("hello")
    # now, one can just use the module anywhere:
    onload(session, hello_div, js"""function (hello_div){
        $(JSModule).then(Module => {
            Module.set_global(27398);
            hello_div.innerText = Module.get_global();
        })
    }""")
    return hello_div
end
