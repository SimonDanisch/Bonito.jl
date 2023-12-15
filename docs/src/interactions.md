# Interactions

Animations in JSServe are done via Observables.jl, much like it's the case for Makie.jl, so the same docs apply:

* [observables](https://docs.makie.org/stable/documentation/nodes/index.html)
* [animation](https://docs.makie.org/stable/documentation/animation/index.html)

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
    # Record states is an experimental feature to record all states generated in the Julia session and allow the slider to stay interactive in the statically hosted docs!
    return JSServe.record_states(session, DOM.div(s, value))
end
```

The `s.value` is an `Observable` which can be `mapp'ed` to take on new values, and one can insert observables as an input to `DOM.tag` or as any attribute.
The value of the `observable` will be rendered via `jssrender(session, observable[])`, and then updated whenever the value changes.
So anything that supports being inserted into the `DOM` can be inside an observable, and the fallback is to use the display system (so plots etc. work as well).
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

Likes this one create interactive examples like this:

```@example 1
import JSServe.TailwindDashboard as D

function create_svg(sl_nsamples, sl_sample_step, sl_phase, sl_radii, color)
    width, height = 900, 300
    cxs_unscaled = [i*sl_sample_step + sl_phase for i in 1:sl_nsamples]
    cys = sin.(cxs_unscaled) .* height/3 .+ height/2
    cxs = cxs_unscaled .* width/4pi
    rr = sl_radii
    # DOM.div/svg/etc is just a convenience in JSServe for using Hyperscript, but circle isn't wrapped like that yet
    geom = [SVG.circle(cx=cxs[i], cy=cys[i], r=rr, fill=color(i)) for i in 1:sl_nsamples[]]
    return SVG.svg(SVG.g(geom...);
        width=width, height=height
    )
end

app = App() do session
    colors = ["black", "gray", "silver", "maroon", "red", "olive", "yellow", "green", "lime", "teal", "aqua", "navy", "blue", "purple", "fuchsia"]
    color(i) = colors[i%length(colors)+1]
    sl_nsamples = D.Slider("nsamples", 1:200, value=100)
    sl_sample_step = D.Slider("sample step", 0.01:0.01:1.0, value=0.1)
    sl_phase = D.Slider("phase", 0.0:0.1:6.0, value=0.0)
    sl_radii = D.Slider("radii", 0.1:0.1:60, value=10.0)
    svg = map(create_svg, sl_nsamples.value, sl_sample_step.value, sl_phase.value, sl_radii.value, color)
    return DOM.div(D.FlexRow(D.FlexCol(sl_nsamples, sl_sample_step, sl_phase, sl_radii), svg))
end
```

As you notice, when exporting this example to the docs which get statically hosted, all interactions requiring Julia cease to exist.
One way to create interactive examples that stay active is to move the parts that need Julia to Javascript:

```@example 1
app = App() do session
    colors = ["black", "gray", "silver", "maroon", "red", "olive", "yellow", "green", "lime", "teal", "aqua", "navy", "blue", "purple", "fuchsia"]
    nsamples = D.Slider("nsamples", 1:200, value=100)
    nsamples.widget[] = 100
    sample_step = D.Slider("sample step", 0.01:0.01:1.0, value=0.1)
    sample_step.widget[] = 0.1
    phase = D.Slider("phase", 0.0:0.1:6.0, value=0.0)
    radii = D.Slider("radii", 0.1:0.1:60, value=10.0)
    radii.widget[] = 10
    svg = DOM.div()
    evaljs(session, js"""
        const [width, height] = [900, 300]
        const colors = $(colors)
        const observables = $([nsamples.value, sample_step.value, phase.value, radii.value])
        function update_svg(args) {
            const [nsamples, sample_step, phase, radii] = args;
            const svg = (tag, attr) => {
                const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
                for (const key in attr) {
                    el.setAttributeNS(null, key, attr[key]);
                }
                return el
            }
            const color = (i) => colors[i % colors.length]
            const svg_node = svg('svg', {width: width, height: height});
            for (let i=0; i<nsamples; i++) {
                const cxs_unscaled = (i + 1) * sample_step + phase;
                const cys = Math.sin(cxs_unscaled) * (height / 3.0) + (height / 2.0);
                const cxs = cxs_unscaled * width / (4 * Math.PI);
                const circle = svg('circle', {cx: cxs, cy: cys, r: radii, fill: color(i)});
                svg_node.appendChild(circle);
            }
            $(svg).replaceChildren(svg_node);
        }
        JSServe.onany(observables, update_svg)
        update_svg(observables.map(x=> x.value))
        """)
    return DOM.div(D.FlexRow(D.FlexCol(nsamples, sample_step, phase, radii), svg))
end
```

This works, because the Javascript side of JSServe, will still update the observables in Javascript (which are mirrored from Julia), and therefore keep working without a running Julia process.
You can use `js_observable.on(value=> ....)` and `JSServe.onany(array_of_js_observables, values=> ...)` to create interactions, pretty similar to how you would work with Observables in Julia.
