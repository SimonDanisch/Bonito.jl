using JSServe
using JSServe: Dependency, onload, @js_str, Session
using JSServe.DOM

# First argument: Name of the Javascript module
# Second argument: Array of dependency. One needs to be the JavaScript file
# containing the module the others can be css files!
const JSModule = Dependency(:JSModule, [joinpath(@__DIR__, "JSModule.js")])

app = App() do session::Session
    hello_div = DOM.div("hello")
    # now, one can just use the module anywhere:
    onload(session, hello_div, js"""function (hello_div){
        $(JSModule).set_global(27398);
        hello_div.innerText = $(JSModule).get_global();
    }""")

    return hello_div
end

display(app)
