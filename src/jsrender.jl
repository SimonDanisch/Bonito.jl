"""
    jsrender([::Session], x::Any)

Internal render method to create a valid dom. Registers used observables with a session
And makes sure the dom only contains valid elements. Overload jsrender(::YourType)
To enable putting YourType into a dom element/div.
You can also overload it to take a session as first argument, to register
messages with the current web session (e.g. via onjs).
"""
jsrender(::Session, @nospecialize(x)) = jsrender(x)
jsrender(value::Union{String, Symbol}) = string(value)
jsrender(::Nothing) = DOM.span()

function render_mime(m::MIME"text/html", @nospecialize(value))
    html = repr(m, value)
    return HTML(html)
end

function render_mime(m::MIME"image/png", @nospecialize(value))
    img = repr(m, value)
    src = "data:image/png;base64," * Base64.base64encode(img)
    return DOM.img(src=src)
end

function render_mime(m::MIME"image/svg+xml", @nospecialize(value))
    img = repr(m, value)
    src = "data:image/svg+xml;base64," * Base64.base64encode(img)
    return DOM.img(src=src)
end

function render_mime(m::MIME"text/plain", @nospecialize(value))
    return DOM.p(repr(m, value))
end

function jsrender(@nospecialize(value))
    mime = richest_mime(value)
    return render_mime(mime, value)
end
