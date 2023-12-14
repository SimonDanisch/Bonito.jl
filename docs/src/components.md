# Components

Components in JSServe are meant to be re-usable, easily shareable types and functions to create complex JSServe Apps.
We invite everyone to share their Components by turning them into a Julia library.

There are two ways of defining components in JSServe:

1. Write a function which returns `DOM` objects
2. Overload `jsrender` for a type

The first is a very lightweight form of defining reusable components, which should be preferred if possible.

But, for e.g. widgets the second form is unavoidable, since you will want to return a type that the user can register interactions with.
Also, the second form is great for integrating existing types into JSServe like plot objects.
How to do the latter for Plotly is described in [Plotting](@ref).

Let's start with the simple function based components that reuses existing JSServe components:

```@setup 1
using JSServe
JSServe.Page()
```

```@example 1
using Dates
function CurrentMonth(date=now(); style=Styles(), div_attributes...)
    current_day = Dates.day(date)
    month = Dates.monthname(date)
    ndays = Dates.daysinmonth(date)
    current_day_style = Styles(style, "background-color" => "gray", "color" => "white")
    days = map(1:ndays) do day
        if day == current_day
            return Card(Centered(day); style=current_day_style)
        else
            return Card(Centered(day); style=style)
        end
    end
    grid = Grid(days...; columns="repeat(7, 1fr)")
    return DOM.div(DOM.h2(month), grid; style=Styles("width" => "400px", "margin" => "5px"))
end


App(()-> CurrentMonth())
```

Now, we could define the same kind of rendering via overloading `jsrender`, if a date is spliced into a DOM:

```@example 1
function JSServe.jsrender(session::Session, date::DateTime)
    return JSServe.jsrender(session, CurrentMonth(date))
end
App() do
    DOM.div(now())
end
```

Please note, that `jsrender` is not applied recursively on its own, so one needs to apply it manually on the return value.
It's not needed for simple divs and other Hyperscript elements, but e.g. `Styles` requires a pass through `jsrender` to do the deduplication etc.
