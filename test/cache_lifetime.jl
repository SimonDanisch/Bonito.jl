# MWE for the "Observable popped from root cache while still alive in Julia" bug.
#
# The app interpolates a long-lived Observable `target` into JS only via
# transient sub-sessions, then auto-fires several re-render patterns via
# @async tasks so the bug surfaces *just by displaying* the app — no clicks
# required. A "Re-run churn" button is also included so the same sequence
# can be re-driven through a Bonito.Button → Julia callback round-trip
# (which mirrors how the BonitoTeam "Discover" click flows).
#
# Failure shape (what we are trying to reproduce):
#   Key <N> not found! undefined
#   Cannot read properties of null (reading 'notify')
# in the JS console, plus an exception when JS tries to use `target`.
#
# Usage:
#   julia> include("test/cache_lifetime.jl")     # defines mwe_app
#   julia> ed = Bonito.use_electron_display()
#   julia> display(ed, mwe_app)
#
# Watch the JS console + the green "Julia saw:" status line. If healthy,
# all four phases land their notifications cleanly.

using Bonito

function churn!(flip_inplace, flip_conditional, results, target)
    flip_inplace[] = flip_inplace[] + 1
    sleep(0.15)
    flip_inplace[] = flip_inplace[] + 1
    sleep(0.15)
    flip_conditional[] = false
    sleep(0.15)
    flip_conditional[] = true
    sleep(0.15)
    results[] = ["a", "b", "c"]
    sleep(0.15)
    results[] = ["x", "y"]
    sleep(0.15)
    results[] = String[]
    sleep(0.15)
    results[] = ["z"]
    sleep(0.15)
    target[] = "after-churn ping " * string(time_ns())
    return
end

const mwe_app = App() do session
    target = Observable("idle")

    received = map(target) do v
        DOM.div("Julia saw: $(v)"; id = "received",
            style = Styles("color" => "green", "margin-top" => "12px"))
    end

    # Shape A — same-shape re-render: new sub registers `target` *before*
    # old sub closes. owners briefly = {old, new} → {new}.
    flip_inplace = Observable(0)
    inplace = map(flip_inplace) do n
        DOM.button("inplace #$n"; id = "btn-inplace-$n",
            onclick = js"event => $(target).notify('inplace ' + $(n))")
    end

    # Shape B — conditional drop / re-add: target leaves the conditional
    # sub's owners during the hidden phase, then gets re-added on flip-back.
    flip_conditional = Observable(true)
    conditional = map(flip_conditional) do show
        if show
            DOM.button("conditional"; id = "btn-conditional",
                onclick = js"event => $(target).notify('conditional')")
        else
            DOM.div("(hidden)"; id = "placeholder")
        end
    end

    # Shape C — outer/inner cascade (the dashboard "Discover results" pattern):
    # outer Observable updates from Julia, inner map renders many entries
    # that each interpolate the long-lived `target`.
    results = Observable(String[])
    cascade = map(results) do rs
        if isempty(rs)
            DOM.div("(no results yet)"; id = "cascade-empty")
        else
            DOM.div(map(rs) do r
                DOM.button("open $r"; id = "btn-cascade-$r",
                    onclick = js"event => $(target).notify('cascade ' + $(r))")
            end...; id = "cascade-list")
        end
    end

    # Auto-driver: exercise each shape after the page is alive.
    @async begin
        sleep(0.5)
        try
            churn!(flip_inplace, flip_conditional, results, target)
        catch err
            @error "MWE auto-driver failed" exception=(err, catch_backtrace())
        end
    end

    # Manual re-trigger via a Bonito.Button — same churn sequence, but
    # driven from the on(button.value) callback so it goes through Bonito's
    # task scheduler (as the BonitoTeam Discover button does).
    rerun_btn = Bonito.Button("Re-run churn"; class = "drv-rerun")
    on(rerun_btn.value) do c
        c || return
        try
            churn!(flip_inplace, flip_conditional, results, target)
        catch err
            @error "Re-run churn failed" exception=(err, catch_backtrace())
        end
    end

    return DOM.div(
        DOM.h2("cache_lifetime MWE"),
        DOM.p("Auto-driver runs once on load. If the bug is present, you'll see 'Key N not found' in the JS console."),
        DOM.div(rerun_btn, style = Styles("margin-bottom" => "12px")),
        DOM.div(inplace, conditional, cascade,
            style = Styles("display" => "flex", "gap" => "8px",
                "margin-bottom" => "12px")),
        received,
    )
end
