"""
    jsrender([::Session], x::Any)

Internal render method to create a valid dom. Registers used observables with a session
And makes sure the dom only contains valid elements. Overload jsrender(::YourType)
To enable putting YourType into a dom element/div.
You can also overload it to take a session as first argument, to register
messages with the current web session (e.g. via onjs).
"""
jsrender(::Session, value::Union{String,Symbol,Number}) = string(value)
jsrender(::Nothing) = DOM.span()
jsrender(@nospecialize(x)) = x

function render_mime(session::Session, m::MIME"text/html", @nospecialize(value))
    html = Base.invokelatest(repr, m, value)
    return HTML(html)
end

function render_mime(session::Session, m::Union{MIME"image/png", MIME"image/jpeg", MIME"image/svg+xml"}, @nospecialize(value))
    io = IOBuffer()
    show(io, m, value)
    bindeps = BinaryAsset(take!(io), mime_string(m))
    return DOM.img(src=url(session, bindeps))
end

function render_mime(session::Session, m::MIME"text/plain", @nospecialize(value))
    return DOM.p(Base.invokelatest(repr, m, value))
end

function jsrender(session::Session, @nospecialize(value))
    rendered = jsrender(value)
    if rendered === value
        mime = richest_mime(value)
        return render_mime(session, mime, value)
    else
        return rendered
    end
end
