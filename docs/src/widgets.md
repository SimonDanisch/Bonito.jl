# Widgets

## Editor

This editor works in pure Javascript, so feel free to try out editing the Javascript and clicking `eval` to see how the output changes.
In `JSServe/examples/editor.jl`, you will find a version that works with Julia code, but that requires a running Julia server of course.

```@setup 1
using JSServe
Page()
```

```@example 1
using JSServe, Observables
src = """
(() => {
    const canvas = document.createElement("canvas");
    const context = canvas.getContext('2d');
    const width = 500
    const height = 400
    canvas.width = width;
    canvas.height = height;
    const gradient = context.createRadialGradient(200, 200, 0, 200, 200, 200);
    gradient.addColorStop("0", "magenta");
    gradient.addColorStop(".25", "blue");
    gradient.addColorStop(".50", "green");
    gradient.addColorStop(".75", "yellow");
    gradient.addColorStop("1.0", "red");
    context.fillStyle = gradient;
    context.fillRect(0, 0, width, height);
    return canvas;
})();
"""
App() do session::Session
    editor = CodeEditor("javascript"; initial_source=src, width=800, height=300)
    eval_button = Button("eval")
    output = DOM.div(DOM.span())
    JSServe.onjs(session, eval_button.value, js"""function (click){
        const js_src = $(editor.onchange).value;
        const result = new Function("return " + (js_src))()
        let dom;
        if (typeof result === 'object' && result.nodeName) {
            dom = result
        } else {
            const span = document.createElement("span")
            span.innerText = result;
            dom = span
        }
        JSServe.update_or_replace($(output), dom, false);
        return
    }
    """)
    notify(eval_button.value)
    return DOM.div(editor, eval_button, output)
end
```
