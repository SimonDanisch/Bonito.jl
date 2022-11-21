using JSServe, Observables, Test
JSServe.browser_display()

global_obs = JSServe.Retain(Observable{Any}("hiii"))
dom_obs1 = Observable{Any}(DOM.div("12345", js"$(global_obs).notify('hello')"))

begin
    p = JSServe.dependency_path("JSServe.bundled.js")
    isfile(p) && rm(p)
    p = JSServe.dependency_path("Websocket.bundled.js")
    isfile(p) && rm(p)

    app = App() do s
        global session = s
        DOM.div(dom_obs1)
    end
end
@test global_obs.value[] == "hello"
@test haskey(session.session_cache, global_obs.value.id)

dom_obs1[] = DOM.div("95384", js"""
    $(global_obs).notify('melo')
""")

@test global_obs.value[] == "melo"

# Sessions should be closed!
@test isempty(sub1.session_cache)
@test isempty(sub2.session_cache)
@test !isopen(sub1)
@test !isopen(sub2)
@test length(session.children) == 2
@test !haskey(session.session_cache, global_obs.id)

dom_obs1[] = DOM.div(js"$(global_obs).notify('lolo')")

@test haskey(session.session_cache, global_obs.id)
@test length(session.children) == 2
sub1, sub2 = collect(values(session.children))

# one of them will now
@test !haskey(sub1.session_cache, global_obs.id) || !haskey(sub2.session_cache, global_obs.id)


using WGLMakie
obs = Observable{Any}(1)
App() do
    DOM.div(obs)
end
obs[] = DOM.div(scatter(rand(Point2f, 10)));
