using JSServe, AssetRegistry

function create_link(parent, file)
    url = AssetRegistry.register(joinpath(parent, file))
    return JSServe.DOM.a(href=url, file)
end

function test_handler(session, req)
    path = pwd()

    dom = JSServe.DOM.div([JSServe.DOM.div(create_link(path, file)) for file in readdir(path)]...)

    return JSServe.DOM.div(dom)
end

app = JSServe.Application(test_handler, "0.0.0.0", 8081)
