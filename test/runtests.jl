using Hyperscript
using JSServe, Observables
using JSServe: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session

d = with_session() do session
    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
    t = TextField("lol")
    linkjs(session, s1.value, s2.value)
    onjs(session, s1.value, js"(v)=> console.log(v)")
    on(t) do text
        println(text)
    end
    return JSServe.DOM.div(s1, s2, b, t)
end

route!(app, ("/", Greed(isnumber, 5))) do ctx, request, matches
    id = matches[2]

end


module Static

struct Interceptor{Fenter, Fleave, Ferror}
    # all need to be callable
    enter::Fenter
    leave::Fleave
    error::Ferror
end

function Interceptor(enter)
    Interceptor(enter, nothing, nothing)
end


function (interceptor::Interceptor)(context)
    enter = interceptor.enter
    leave = interceptor.leave
    error = interceptor.error
    new_context = context
    try
        new_context = enter(context)
        if leave !== nothing
            new_context = leave(context)
        end
    catch e
        if error !== nothing
            new_context = error(context, e)
        end
    finally
        return new_context
    end
end

struct Chain{T}
    stack::T
end

function Chain(args::Function...)
    Chain(Interceptor.(args))
end

function (c::Chain)(context)
    for interceptor in context.stack
        context = interceptor(context)
    end
end
end
