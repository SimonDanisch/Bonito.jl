# Styling

## Basics

```@setup 1
using JSServe
Page()
```

The main type to style the DOM via css is `Style`:


```@docs; canonical=false
Styles
```

## Using CSS and pseudo classes

The `CSS` object allows to specify a selector, which will be used to apply the styling to a specific DOM node.
Since the main usage is to apply the `Style` object to a `DOM` node, the selector is usually empty and we use it mainly for pseudo classes like `:hover`:

```@example 1
App() do session
    return DOM.div(
        "This turns red on hover",
        style=Styles(
            CSS(":hover", "color" => "red", "text-size" => "2rem")
        )
    )
end
```

A more involved example is the style we use for `Button`:

```@example 1
App() do
    style = Styles(
        CSS(
            "font-weight" => 600,
            "border-width" => "1px",
            "border-color" => "#9CA3AF",
            "border-radius" => "0.25rem",
            "padding-left" => "0.75rem",
            "padding-right" => "0.75rem",
            "padding-top" => "0.25rem",
            "padding-bottom" => "0.25rem",
            "margin" => "0.25rem",
            "cursor" => "pointer",
            "min-width" => "8rem",
            "font-size" => "1rem",
            "background-color" => "white",
            "box-shadow" => "rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.1) 0px 1px 3px 0px, rgba(0, 0, 0, 0.1) 0px 1px 2px -1px";
        ),
        CSS(
            ":hover",
            "background-color" => "#F9FAFB",
            "box-shadow" => "rgba(0, 0, 0, 0) 0px 0px 0px 0px",
        ),
        CSS(
            ":focus",
            "outline" => "1px solid transparent",
            "outline-offset" => "1px",
            "box-shadow" => "rgba(66, 153, 225, 0.5) 0px 0px 0px 1px",
        ),
    )
    return DOM.div("Hello", style=style)
end
```
If we merged a complex `Style` like the above with a user given `Styles` object, it will merge all CSS objects with the same selector, allowing to easily overwrite all styling attributes.

This is how one can style a Button:

```@example 1
App() do
    style = Styles(
        CSS("font-weight" => "500"),
        CSS(":hover", "background-color" => "silver"),
        CSS(":focus", "box-shadow" => "rgba(0, 0, 0, 0.5) 0px 0px 5px"),
    )
    button = Button("Click me"; style=style)
    return button
end
```


## Using Styles as global Stylesheet

One can also define a global stylesheet with `Styles` using selectors to style parts of an HTML document.
This can be handy to set some global styling, but please be careful, since this will affect the whole document. That's also why we need to set a specific attribute selector for all, to not affect the whole documentation page.
This will not happen when assigning a style to `DOM.div(style=Styles(...))`, which will always just apply to that particular div and any other div assigned to.
Note, that a style object directly inserted into the DOM will be rendered exactly where it occurs without deduplication!

```@example 1
App() do
    style = Styles(
        CSS("*[our-style]", "font-style" => "italic"),
        CSS("p[our-style]", "color" => "red"),
        CSS(".myClass[our-style]", "text-decoration" => "underline"),
        CSS("#myId[our-style]", "font-family" => "monospace"),
        CSS("p.myClass#myId[our-style]", "font-size" => "1.5rem")
    )
    return DOM.div(
        style,
        DOM.div(ourStyle=1,
            DOM.p(class="myClass", id="myId", "I match everything.", ourStyle=1),
            DOM.p("I match the universal and type selectors only.", ourStyle=1)
        )
    )
end
```
