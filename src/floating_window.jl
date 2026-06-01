# Reusable floating-window widget: a `position: fixed` panel with a draggable
# title bar, resizable SE corner, hide/show via Observable, and a close trigger
# the caller can wire to whatever "user dismissed me" should mean (close, return
# DOM to its origin slot, save+park, …).
#
# State is all Observables, so persistence is the caller's responsibility:
#   on(w.x) do _; save_geometry(...); end
# An update from Julia (e.g. restoring saved geometry on mount) flows JS-ward
# automatically.
#
# The body slot can be any DOM. For "movable mount" use cases (Bonito's
# `move_dom_node` re-parenting), give the inner element a stable `id` and JS
# can shuffle child nodes in/out of the window without re-rendering its chrome.

export FloatingWindow

struct FloatingWindow
    body          :: Any
    title         :: Any
    x             :: Observable{Int}
    y             :: Observable{Int}
    width         :: Observable{Int}
    height        :: Observable{Int}
    visible       :: Observable{Bool}
    # Set to `true` on a close-button click. Callers `on(w.close_trigger)`
    # decide the semantics — e.g. BonitoTeam treats close as "minimize back
    # to the bubble". The widget itself never auto-hides.
    close_trigger :: Observable{Bool}
end

"""
    FloatingWindow(body; title="", x=80, y=80, width=640, height=420,
                         visible=true, close_trigger=Observable(false))

A draggable, resizable, fixed-position window component. Geometry, visibility,
and the close trigger are Observables so callers can persist / react to user
gestures and push updates the other way (e.g. restore from disk).

`body` is any DOM-renderable. Move-dom-node use cases should give it a stable
`id` so external JS can re-parent children into the window without disturbing
its chrome.
"""
function FloatingWindow(body;
                        title = "",
                        x::Union{Int,Observable{Int}}            = 80,
                        y::Union{Int,Observable{Int}}            = 80,
                        width::Union{Int,Observable{Int}}        = 640,
                        height::Union{Int,Observable{Int}}       = 420,
                        visible::Union{Bool,Observable{Bool}}    = true,
                        close_trigger::Observable{Bool}          = Observable(false))
    asobs(v::Observable) = v
    asobs(v::Int)        = Observable{Int}(v)
    asobs(v::Bool)       = Observable{Bool}(v)
    FloatingWindow(body, title,
                   asobs(x), asobs(y), asobs(width), asobs(height),
                   asobs(visible), close_trigger)
end

const FloatingWindowStyles = Styles(
    CSS(".bn-floating-window",
        "position"      => "fixed",
        "z-index"       => "9999",
        "background"    => "white",
        "border"        => "1px solid #cbd5e1",
        "border-radius" => "8px",
        "box-shadow"    => "0 10px 30px rgba(0,0,0,0.25)",
        "display"       => "flex", "flex-direction" => "column",
        "overflow"      => "hidden",
        "min-width"     => "240px", "min-height" => "140px",
        "box-sizing"    => "border-box"),
    CSS(".bn-fw-title",
        "display"      => "flex", "align-items" => "center", "gap" => "8px",
        "padding"      => "6px 10px",
        "background"   => "#f8fafc",
        "border-bottom"=> "1px solid #e2e8f0",
        "cursor"       => "move",
        "user-select"  => "none",
        "font"         => "13px/1.2 system-ui, -apple-system, sans-serif",
        "color"        => "#1e293b",
        "flex-shrink"  => "0"),
    CSS(".bn-fw-title-text",
        "flex"          => "1 1 auto", "min-width" => "0",
        "overflow"      => "hidden",
        "text-overflow" => "ellipsis",
        "white-space"   => "nowrap",
        "font-weight"   => "600"),
    CSS(".bn-fw-controls",
        "display" => "flex", "gap" => "4px",
        "cursor"  => "default"),
    CSS(".bn-fw-btn",
        "appearance"    => "none", "border" => "0",
        "background"    => "transparent",
        "padding"       => "2px 8px",
        "border-radius" => "4px",
        "cursor"        => "pointer",
        "color"         => "#64748b",
        "font"          => "14px/1 system-ui, sans-serif",
        "font-weight"   => "500"),
    CSS(".bn-fw-btn:hover",
        "background" => "#e2e8f0", "color" => "#1e293b"),
    CSS(".bn-fw-body",
        "flex"     => "1 1 auto",
        "overflow" => "auto",
        "position" => "relative",
        "padding"  => "8px"),
    # SE-corner resize handle. Pure CSS chevron pattern.
    CSS(".bn-fw-resize",
        "position" => "absolute", "right" => "0", "bottom" => "0",
        "width"    => "14px", "height" => "14px",
        "cursor"   => "nwse-resize",
        "background" =>
            "linear-gradient(135deg, transparent 50%, #cbd5e1 50%, #cbd5e1 60%, " *
            "transparent 60%, transparent 70%, #cbd5e1 70%, #cbd5e1 80%, transparent 80%)"),
)

function jsrender(session::Session, w::FloatingWindow)
    title_node = DOM.span(w.title; class = "bn-fw-title-text")
    close_btn  = DOM.span("×"; class = "bn-fw-btn", title = "Close")

    title_bar = DOM.div(
        title_node,
        DOM.div(close_btn; class = "bn-fw-controls");
        class = "bn-fw-title")

    resize_handle = DOM.div(""; class = "bn-fw-resize", title = "Drag to resize")

    container = DOM.div(
        title_bar,
        DOM.div(w.body; class = "bn-fw-body"),
        resize_handle;
        class = "bn-floating-window",
        # Initial inline styles so first paint is at the right place even
        # before the JS onload runs.
        style = Styles(
            "left"    => string(w.x[], "px"),
            "top"     => string(w.y[], "px"),
            "width"   => string(w.width[], "px"),
            "height"  => string(w.height[], "px"),
            "display" => w.visible[] ? "flex" : "none"))

    onload(session, container, js"""
        (el) => {
            const titleBar  = el.querySelector('.bn-fw-title');
            const handle    = el.querySelector('.bn-fw-resize');
            const closeBtn  = el.querySelector('.bn-fw-controls .bn-fw-btn');

            const xObs = $(w.x),       yObs = $(w.y);
            const wObs = $(w.width),   hObs = $(w.height);
            const visObs = $(w.visible), closeObs = $(w.close_trigger);

            const applyGeom = () => {
                el.style.left   = xObs.value + 'px';
                el.style.top    = yObs.value + 'px';
                el.style.width  = wObs.value + 'px';
                el.style.height = hObs.value + 'px';
            };
            const applyVis = () => { el.style.display = visObs.value ? 'flex' : 'none'; };
            xObs.on(applyGeom); yObs.on(applyGeom);
            wObs.on(applyGeom); hObs.on(applyGeom);
            visObs.on(applyVis);
            applyGeom(); applyVis();

            // Drag from the title bar (but not its control buttons).
            titleBar.addEventListener('pointerdown', (ev) => {
                if (ev.target.closest('.bn-fw-controls')) return;
                const offX = ev.clientX - el.offsetLeft;
                const offY = ev.clientY - el.offsetTop;
                let lastX = el.offsetLeft, lastY = el.offsetTop;
                const onMove = (e2) => {
                    lastX = Math.max(0, e2.clientX - offX);
                    lastY = Math.max(0, e2.clientY - offY);
                    el.style.left = lastX + 'px';
                    el.style.top  = lastY + 'px';
                };
                const onUp = (e2) => {
                    window.removeEventListener('pointermove', onMove);
                    window.removeEventListener('pointerup',   onUp);
                    xObs.notify(lastX); yObs.notify(lastY);
                };
                window.addEventListener('pointermove', onMove);
                window.addEventListener('pointerup',   onUp);
                ev.preventDefault();
            });

            // SE-corner resize.
            handle.addEventListener('pointerdown', (ev) => {
                const startW = el.offsetWidth,  startH = el.offsetHeight;
                const startX = ev.clientX,      startY = ev.clientY;
                let lastW = startW, lastH = startH;
                const onMove = (e2) => {
                    lastW = Math.max(240, startW + (e2.clientX - startX));
                    lastH = Math.max(140, startH + (e2.clientY - startY));
                    el.style.width  = lastW + 'px';
                    el.style.height = lastH + 'px';
                };
                const onUp = (e2) => {
                    window.removeEventListener('pointermove', onMove);
                    window.removeEventListener('pointerup',   onUp);
                    wObs.notify(lastW); hObs.notify(lastH);
                };
                window.addEventListener('pointermove', onMove);
                window.addEventListener('pointerup',   onUp);
                ev.preventDefault(); ev.stopPropagation();
            });

            // Close: just flip the trigger. Callers decide what to do.
            closeBtn.addEventListener('click', (ev) => {
                ev.stopPropagation();
                closeObs.notify(true);
            });
        }
    """)

    return jsrender(session, DOM.div(FloatingWindowStyles, container))
end
