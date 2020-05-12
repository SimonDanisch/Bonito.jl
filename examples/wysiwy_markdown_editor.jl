using JSServe, Observables
using JSServe.DOM
using StatsMakie
using JSServe: Application, evaljs, linkjs, CodeEditor
using JSServe: @js_str, onjs, Dependency, with_session, string_to_markdown
set_theme!(resolution=(600, 400))
using JSServe: Slider
using WGLMakie, AbstractPlotting
using AbstractPlotting: Pixel
using JSServe: Table
using RDatasets
# Some items we can show off:
iris = RDatasets.dataset("datasets", "iris")
img1 = DOM.img(src="https://i.ytimg.com/vi/lUaNo_L7AKU/hqdefault.jpg")

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

initial_code = """
# Markdown test

# Try dragging any item of the list to the right here:


# Or drag the iris dataset into the julia code

```julia
iris =
iris[1:3, :]
```

```julia
scatter(Data(iris), Group(:Species), :SepalLength, :SepalWidth);
```

Sliders also work (although are completely unstyled at this point):

```julia
markersize = Slider(5:20)
markersize_px = map(Pixel, markersize)
markersize
```

```julia
scatter(Data(iris), Group(:Species), :SepalLength, :SepalWidth, markersize=markersize_px);
```

"""

function dom_handler(session, request)
    editor = CodeEditor("markdown"; initial_source=initial_code)
    context = (
        drag_drop_list = DragItem.(["picture", "some text", "iris dataset"], 1:3, :drag_drop),
        drag_drop = [img1, "oh, this is text?!", iris]
    )
    markdown = map(editor.onchange) do x
        md = string_to_markdown(x, context, eval_julia_code=Main)
        return md
    end
    md_preview = DOM.div(markdown; class="page")
    list = DOM.div(context.drag_drop_list...; class="drag-list")
    return DOM.div(WGLMakie.THREE, JSServe.MarkdownCSS, stylesheet, editor, list, md_preview)
end

# close(app)
# app = Application(dom_handler, "127.0.0.1", 8083)


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
