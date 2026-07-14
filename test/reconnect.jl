# Realistic WebSocket reconnect tests, driven through a real Electron browser via
# ElectronCall (NO Node, NO mocks). Each scenario opens a live Bonito app, drives
# a bidirectional observable round-trip, then forces real disconnects and asserts
# that the reconnect cluster (JS findings J1–J8) behaves correctly end to end:
#
#   • J1  offline queue is flushed exactly once (never replayed on later reconnects)
#   • J2  a message sent while the client knows its socket is down is queued, not dropped
#   • J3  client recovers after the socket dies (auto-retry)
#   • J4  session objects survive reconnect (no premature free → no "Key not found")
#   • J7  rapid flapping never wedges the retry state machine or duplicates delivery
#
# The trick that makes "the browser acts while Bonito's socket is down" testable:
# `run(win, js)` reaches the page over ElectronCall's OWN IPC channel, which is
# independent of the Bonito WebSocket. So we can `notify()` an observable from the
# browser even while the Bonito connection is closed, and assert it lands in Julia
# after the reconnect.
#
# Reliable-guarantee note: the CLIENT always knows when its own socket is down, so
# client→server updates during an outage are queued deterministically. A server→
# client write landing in the exact socket-swap micro-window is best-effort (Bonito
# has no message-ack/replay protocol), so we assert server→client delivery AFTER the
# reconnect completes — the user-visible "the app keeps working after a blip" rule.
#
# Each scenario runs in a FRESH Electron window (reusing the shared Electron process
# from the runtests `edisplay`): six hard disconnect/reconnect cycles in a single
# long-lived window eventually wedge, which is a test-harness artifact, not a product
# bug — isolating per scenario keeps the suite deterministic.
#
# Requires the global `edisplay` (set up in runtests.jl).

using Bonito: DOM, App, Observable, evaljs, wait_for, root_session, isready, isclosed

# Build a round-trip app and return everything a scenario needs.
#   obs_in  : browser -> Julia   (JS calls `window.__o_in.notify(v)`)
#   obs_out : Julia   -> browser (Julia sets `obs_out[] = v`, JS reads `window.__o_out.value`)
# `recv` accumulates every value Julia received from the browser (under `lk`).
function reconnect_roundtrip_app()
    recv = Int[]
    lk = ReentrantLock()
    obs_in = Observable(0)
    obs_out = Observable(0)
    on(obs_in) do v
        lock(lk) do; push!(recv, v); end
    end
    app = App() do session
        evaljs(session, js"""
            window.__o_in  = $(obs_in);
            window.__o_out = $(obs_out);
            window.__warns = [];
            const __origwarn = console.warn;
            console.warn = (...a) => {
                const m = a.map(String).join(' ');
                if (m.indexOf('not found') !== -1) window.__warns.push(m);
                __origwarn.apply(console, a);
            };
            window.__ready = true;
        """)
        return DOM.div("reconnect", DOM.span(obs_out; dataTestId="out"))
    end
    return (; app, obs_in, obs_out, recv, lk)
end

countrecv(ctx, v) = lock(ctx.lk) do; count(==(v), ctx.recv); end
ws_isopen(win) = run(win, "window.WEBSOCKET.isopen()") === true
force_disconnect(win) = run(win, "window.WEBSOCKET.close()")

# Run `f(ctx, win)` against a fresh Electron window (reusing the shared Electron
# process), connected and with the setup evaljs applied. Always closes the window.
function with_roundtrip(f; timeout=25)
    disp = Bonito.HTTPServer.ElectronDisplay(; app=edisplay.window.app,
        options=Dict{String,Any}("show" => false, "focusOnWebView" => false))
    try
        ctx = reconnect_roundtrip_app()
        display(disp, ctx.app)
        win = disp.window
        ready = wait_for(timeout=timeout) do
            run(win, "window.WEBSOCKET && window.WEBSOCKET.isopen() && window.__ready === true") === true
        end
        @test ready == :success
        f(ctx, win)
    finally
        close(disp)
    end
end

@testset "WebSocket reconnect (Electron, realistic)" begin

    @testset "baseline round-trip + auto-reconnect keeps the session alive" begin
        with_roundtrip() do ctx, win
            session = ctx.app.session[]
            # both directions work before any disconnect
            run(win, "window.__o_in.notify(1)")
            @test wait_for(() -> countrecv(ctx, 1) == 1; timeout=5) == :success
            ctx.obs_out[] = 7
            @test wait_for(() -> run(win, "window.__o_out.value") == 7; timeout=5) == :success

            # kill the socket; it must auto-reconnect and the session must survive
            force_disconnect(win)
            @test ws_isopen(win) == false
            @test wait_for(() -> ws_isopen(win); timeout=15) == :success
            @test isopen(session)
            @test isready(root_session(session))

            # round-trip still works after reconnect (J4: objects not freed)
            ctx.obs_out[] = 8
            @test wait_for(() -> run(win, "window.__o_out.value") == 8; timeout=5) == :success
            run(win, "window.__o_in.notify(2)")
            @test wait_for(() -> countrecv(ctx, 2) == 1; timeout=5) == :success
        end
    end

    @testset "J2: browser updates during the outage are delivered after reconnect" begin
        with_roundtrip() do ctx, win
            force_disconnect(win)
            # The browser keeps working while the Bonito socket is down — these
            # notifies must be QUEUED (not dropped) and flushed on reconnect.
            run(win, "window.__o_in.notify(101); window.__o_in.notify(102); window.__o_in.notify(103);")
            @test wait_for(() -> ws_isopen(win); timeout=15) == :success
            @test wait_for(timeout=10) do
                countrecv(ctx, 101) == 1 && countrecv(ctx, 102) == 1 && countrecv(ctx, 103) == 1
            end == :success
        end
    end

    @testset "J1: the offline queue is flushed exactly once, never replayed" begin
        with_roundtrip() do ctx, win
            # First outage: queue one update, reconnect, it arrives once.
            force_disconnect(win)
            run(win, "window.__o_in.notify(777)")
            @test wait_for(() -> ws_isopen(win); timeout=15) == :success
            @test wait_for(() -> countrecv(ctx, 777) == 1; timeout=10) == :success

            # Second outage with NO new updates: the old 777 must NOT be replayed
            # (the J1 bug flushed the queue without clearing it, re-sending forever).
            force_disconnect(win)
            @test wait_for(() -> ws_isopen(win); timeout=15) == :success
            run(win, "window.__o_in.notify(778)")   # prove we're fully back
            @test wait_for(() -> countrecv(ctx, 778) == 1; timeout=10) == :success
            @test countrecv(ctx, 777) == 1           # still exactly one — not replayed
        end
    end

    @testset "session stays fully bidirectional across an outage" begin
        with_roundtrip() do ctx, win
            force_disconnect(win)
            run(win, "window.__o_in.notify(201)")          # client -> server during outage
            @test wait_for(() -> ws_isopen(win); timeout=15) == :success
            @test wait_for(() -> countrecv(ctx, 201) == 1; timeout=10) == :success

            ctx.obs_out[] = 999                            # server -> client after reconnect
            @test wait_for(() -> run(win, "window.__o_out.value") == 999; timeout=10) == :success
        end
    end

    @testset "J7: rapid flapping never wedges retry nor duplicates delivery" begin
        with_roundtrip() do ctx, win
            session = ctx.app.session[]
            # Slam the socket closed repeatedly; the retry state machine must not
            # get stuck (#is_retrying) and must not leave duplicate live sockets.
            for _ in 1:6
                force_disconnect(win)
                sleep(0.08)
            end
            @test wait_for(() -> ws_isopen(win); timeout=20) == :success
            @test isready(root_session(session))

            # A single notify must be received exactly once — duplicate sockets or
            # duplicated handlers would deliver it more than once.
            run(win, "window.__o_in.notify(55)")
            @test wait_for(() -> countrecv(ctx, 55) >= 1; timeout=8) == :success
            sleep(0.5)                      # let any duplicate delivery land
            @test countrecv(ctx, 55) == 1
        end
    end

    @testset "J4/J8: no 'Key not found' warnings across reconnect" begin
        with_roundtrip() do ctx, win
            force_disconnect(win)
            run(win, "window.__o_in.notify(11); window.__o_in.notify(12);")
            @test wait_for(() -> ws_isopen(win); timeout=15) == :success
            @test wait_for(() -> countrecv(ctx, 11) == 1 && countrecv(ctx, 12) == 1; timeout=10) == :success
            # A server->client update after reconnect must still resolve the same
            # cached observable (not a freed/re-looked-up one).
            ctx.obs_out[] = 33
            @test wait_for(() -> run(win, "window.__o_out.value") == 33; timeout=10) == :success

            # The reconnect must not have transiently freed and re-looked-up session
            # objects (J4 refcount / J8 resurrection) — that surfaces as console
            # "Key N not found!" warnings on the page.
            @test run(win, "window.__warns.length") == 0
        end
    end

end
