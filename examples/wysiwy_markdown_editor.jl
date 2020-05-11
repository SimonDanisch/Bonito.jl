using JSServe, Observables
using JSServe.DOM

using JSServe: Application, evaljs, linkjs, CodeEditor
using JSServe: @js_str, onjs, Dependency, with_session, string_to_markdown

# Javascript & CSS dependencies can be declared locally and
# freely interpolated in the DOM / js string, and will make sure it loads
stylesheet = JSServe.Asset(joinpath(@__DIR__, "assets", "wysiwyg_stylesheet.css"))

struct DragItem
    content::Any
    index::Int
    parent::Symbol
end

function JSServe.jsrender(dragitem::DragItem)
    text = "\$($(dragitem.parent)[$(dragitem.index)])"
    dragfun = js"""event.dataTransfer.setData("text", $(text))"""
    div = DOM.div(dragitem.content; class="list-item", draggable=true, ondragstart=dragfun)
    return div
end

struct Draggable
end

function JSServe.jsrender(session::JSServe.Session, test::Draggable)
    div = DOM.div("henlo")
    JSServe.onload(session, div, js"""function (div){
        console.log("HEYY");
    }""")
    JSServe.evaljs(session, js"console.log('yoooooooo');")
    return div
end


initial_code = """
# Markdown test

```julia
scatter(1:4)
```

"""
using WGLMakie, AbstractPlotting

observable = Observable(DOM.div("hi"))
global sess
function dom_handler(session, request)
    return scatter(1:4)
end

function dom_handler(session, request)
    editor = CodeEditor("markdown"; initial_source=initial_code)
    context = (
        drag_drop_list = DragItem.(["hey", "hoho"], 1:2, :drag_drop),
        drag_drop = ["hey", "hoho"]
    )
    markdown = map(x-> string_to_markdown(x, context, eval_julia_code=Main), editor.onchange)
    md_preview = DOM.div(markdown; class="page")
    list = DOM.div(context.drag_drop_list...; class="drag-list")
    return DOM.div(JSServe.MarkdownCSS, stylesheet, editor, list, md_preview)
end

set_theme!(resolution=(600, 400))

app = Application(dom_handler, "127.0.0.1", 8083)


# If you want to edit a template with your local editor, you can also do:

# function dom_handler(session, request)
#     template_path = "path/to/template.md"
#     source = Observable(read(template_path, String))
#     make sure we breakt the previous while loop on reload
#     SINGLETON_WATCH[] += 1
#     id = SINGLETON_WATCH[]
#     @async while true
#         result = FileWatching.watch_file(template_path)
#         id != SINGLETON_WATCH[] && break
#         if result.changed
#             source[] = read(template_path, String)
#         end
#     end
#     markdown = map(x-> string_to_markdown(x, context; eval_julia_code=Main), source)
#     return DOM.div(stylesheet, markdown; class="page")
# end
