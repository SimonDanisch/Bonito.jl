# Animating things

Animations in JSServe are done via Observables.jl, much like it's the case for Makie.jl, so the same docs apply:

https://docs.makie.org/stable/documentation/nodes/index.html
https://docs.makie.org/stable/documentation/animation/index.html

But lets quickly get started with a JSServe specific example:

```@setup 1
using JSServe
Page()
```

```@example 1
App() do session
    s = Slider(1:3)
    value = map(s.value) do x
        return x ^ 2
    end
    return JSServe.record_states(session, DOM.div(s, value))
end
```

The `s.value` is an `Observable` which can be `mapp'ed` to take on new values, and one can insert observables as an input to `DOM.tag` or as any attribute.
The value of the `observable` will be renedered via `jssrender(session, observable[])`, and then updated whenever the value changes.
So anything that supports being inserted into the `DOM` can be inside an observable, and the fallback is to use the display system (so plots etc work as well).
This way, one can also return `DOM` elements as the result of an observable:

```@example 1
App() do session
    s = Slider(1:3)
    # use map!(result_observable, ...)
    # To use any as the result type, otherwise you can't return
    # different types from the map callback
    value = map!(Observable{Any}(), s.value) do x
        if x == 1
            return DOM.h1("hello from slider: $(x)")
        elseif x == 2
            return DOM.img(src="https://docs.makie.org/stable/assets/makie_logo_transparent.svg", width="200px")
        else
            return x^2
        end
    end
    return JSServe.record_states(session, DOM.div(s, value))
end
```

In other words, the whole app can just be one big observable:

```@example 1
import JSServe.TailwindDashboard as D
App() do session
    s = D.Slider("Slider: ", 1:3)
    checkbox = D.Checkbox("Chose:", true)
    menu = D.Dropdown("Menu: ", [sin, tan, cos])
    app = map(checkbox.widget.value, s.widget.value, menu.widget.value) do checkboxval, sliderval, menuval
        DOM.div(checkboxval, sliderval, menuval)
    end
    return JSServe.record_states(session, D.FlexRow(
        D.Card(D.FlexCol(checkbox, s, menu)),
        D.Card(app)
    ))
end
```
