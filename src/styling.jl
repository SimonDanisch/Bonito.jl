columns(args...; class="") = DOM.div(args..., class=class * " flex flex-col")

rows(args...; class="") = DOM.div(args..., class=class * " flex flex-row")

function styled_slider(slider, value; class="")
    return rows(slider,
                DOM.span(value, class="p-1");
                class="w-64 p-2 items-center " * class)
end
