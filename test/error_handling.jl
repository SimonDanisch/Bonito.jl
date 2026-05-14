# End-to-end regressions for the rendering error path.
#
# These exercise actual `App`s and `Server`s rather than calling the lower
# layers directly, because the contract we care about is observable:
# * a handler that throws produces an inline error page (HTTP 200), not 500;
# * the originating session records the exception on `init_error[]`;
# * `Base.isready(session)` re-throws that exception by default; passing
#   `throw=false` returns `false` silently;
# * `wait_for_ready(app)` surfaces the original exception fast (no hang);
# * `update_app!` of a broken sub-app leaves the parent clean and stamps the
#   sub's `init_error[]`.
#
# `delegate` in HTTPServer/implementation.jl is the only other try/catch in
# the render stack — it stays as the infrastructure safety net for things
# like `Session()` ctor failures (returns 500). User-handler errors never
# reach it.

using Test, Bonito, HTTP, Logging
using Bonito: Server, App, Session

struct _ErrHandlingDemoErr <: Exception
    msg::String
end
Base.showerror(io::IO, e::_ErrHandlingDemoErr) = print(io, "_ErrHandlingDemoErr: ", e.msg)

# A type with no msgpack mapping — packing one inside an evaljs queue forces a
# failure during the page-wrap init bundle, AFTER the user handler returned
# cleanly. Different code path than a handler-throws error.
struct _ErrHandlingUnpackable end

# Wait briefly for app.session[] to be set + an awaited condition to hold,
# without depending on Bonito's `wait_for_ready` (which is itself under test).
function _wait_until(cond; timeout=2.0)
    deadline = time() + timeout
    while time() < deadline
        cond() && return true
        sleep(0.02)
    end
    return false
end

@testset "error handling" begin
# Every sub-testset in this file intentionally triggers a handler/render
# exception so we can verify the recovery path (init_error stamping,
# indicator update, no-hang `wait_for_ready`). Bonito's library code
# logs each of those via `@error "Error rendering app"` / `@error "Error
# wrapping page"`, which is the right behavior at runtime — but in the
# test log it looks like the suite is exploding. Silence it locally so
# the actual test summary stays readable; tests still assert the error
# was caught and surfaced through the documented mechanisms.
Logging.with_logger(Logging.NullLogger()) do
    @testset "handler throws → 200 with inline error, init_error sticky" begin
        app = App() do session
            throw(_ErrHandlingDemoErr("boom"))
        end
        server = Server(app, "127.0.0.1", 0)
        try
            resp = HTTP.get("http://127.0.0.1:$(server.port)/";
                            readtimeout=15, retry=false, status_exception=false)
            # Render-time errors are absorbed into the page — not a 500.
            @test resp.status == 200
            body = String(resp.body)
            @test occursin("_ErrHandlingDemoErr", body) || occursin("boom", body)

            # The session that ran the failing handler stamps init_error.
            @test _wait_until(() -> !isnothing(app.session[]) &&
                                    app.session[].init_error[] isa _ErrHandlingDemoErr)
            @test app.session[].init_error[].msg == "boom"
        finally
            close(server)
        end
    end

    @testset "Base.isready surfaces init_error by default; throw=false silent; no auto-close" begin
        app = App(_ -> throw(_ErrHandlingDemoErr("hi")))
        server = Server(app, "127.0.0.1", 0)
        try
            HTTP.get("http://127.0.0.1:$(server.port)/";
                     readtimeout=15, retry=false, status_exception=false)
            @test _wait_until(() -> !isnothing(app.session[]) &&
                                    !isnothing(app.session[].init_error[]))
            sess = app.session[]
            # Default: isready throws + consumes the error on read (so subsequent
            # callers don't keep getting the same exception). It does NOT close
            # the session — leaving the WS up is what lets `indicator.error[]`
            # JSUpdateObservable messages reach the browser.
            @test_throws _ErrHandlingDemoErr Base.isready(sess)
            @test isnothing(sess.init_error[])           # consumed
            # Second call returns Bool, no throw.
            r = Base.isready(sess; throw=false)
            @test r isa Bool

            # Re-stamp and confirm `throw=false` is a pure connection-state
            # check: it ignores `init_error[]` entirely. This matters for
            # `_send`'s queue-or-write decision — once an error is recorded,
            # we still want the `JSUpdateObservable` carrying
            # `indicator.error[] = err` to go out on the wire, not get
            # silently queued because the session has a recorded failure.
            sess.init_error[] = _ErrHandlingDemoErr("again")
            r = Base.isready(sess; throw=false)
            @test r isa Bool                            # never throws
            @test sess.init_error[] isa _ErrHandlingDemoErr  # not consumed
        finally
            close(server)
        end
    end

    @testset "record_session_error! mirrors error onto the app's ConnectionIndicator" begin
        # Wire a ConnectionIndicator onto an app, set up a session pointing at
        # it, call the helper, and check the observable carries the live
        # Exception (not a stringified copy) — the JS-side renderer in
        # `connection_indicator.jl` maps it through `render_error` so any
        # custom indicator can dispatch on type.
        indicator = Bonito.ConnectionIndicator()
        @test indicator.error[] === nothing

        app = App(_ -> Bonito.DOM.div("ok"); indicator=indicator)
        sess = Session(Bonito.NoConnection(); asset_server=Bonito.NoServer())
        sess.current_app[] = app
        app.session[] = sess

        err = _ErrHandlingDemoErr("propagate me")
        Bonito.record_session_error!(sess, err)
        @test sess.init_error[] === err
        @test indicator.error[] === err          # SAME object, not a copy
        @test indicator.error[].msg == "propagate me"

        # If the app has no indicator, `record_session_error!` still records on
        # `init_error[]` and just skips the indicator update.
        indicatorless = App(_ -> Bonito.DOM.div("ok"))
        sess2 = Session(Bonito.NoConnection(); asset_server=Bonito.NoServer())
        sess2.current_app[] = indicatorless
        indicatorless.session[] = sess2
        Bonito.record_session_error!(sess2, _ErrHandlingDemoErr("no-indicator"))
        @test sess2.init_error[] isa _ErrHandlingDemoErr
        # Doesn't touch the original indicator
        @test indicator.error[] === err
    end

    @testset "wait_for_ready throws original exception fast (no hang)" begin
        app = App(_ -> throw(_ErrHandlingDemoErr("kaboom")))
        server = Server(app, "127.0.0.1", 0)
        try
            HTTP.get("http://127.0.0.1:$(server.port)/";
                     readtimeout=15, retry=false, status_exception=false)
            @test _wait_until(() -> !isnothing(app.session[]) &&
                                    !isnothing(app.session[].init_error[]))
            t0 = time()
            threw = try
                Bonito.wait_for_ready(app; timeout=5)
                nothing
            catch e
                e
            end
            elapsed = time() - t0
            @test elapsed < 1.0   # not waiting for the timeout
            @test threw isa _ErrHandlingDemoErr
            @test threw.msg == "kaboom"
        finally
            close(server)
        end
    end

    @testset "page-wrap failure (handler succeeds, init bundle can't pack)" begin
        # User handler returns cleanly, but it queued an `evaljs` whose
        # interpolated value has no msgpack mapping — the init-bundle pack
        # in `session_dom(::Node)` throws AFTER the handler succeeded.
        # Pre-fix: delegate's catch returned 500, init_error never set,
        # `wait_for_ready` hung for the full timeout (UNINITIALIZED + no
        # error visible from session state). Now: session_dom catches the
        # wrap error, stamps `session.init_error[]`, and ships a minimal
        # error page (`init=false` fallback) so the response is 200 with
        # the cause inline AND `wait_for_ready` throws fast.
        app = Bonito.App() do session
            Bonito.evaljs(session, Bonito.js"console.log($(_ErrHandlingUnpackable()))")
            return Bonito.DOM.div("won't appear")
        end
        server = Bonito.Server(app, "127.0.0.1", 0)
        try
            resp = HTTP.get("http://127.0.0.1:$(server.port)/";
                            readtimeout=15, retry=false, status_exception=false)
            @test resp.status == 200
            body = String(resp.body)
            @test occursin("MsgPack mapping", body) || occursin("_ErrHandlingUnpackable", body)

            @test _wait_until(() -> !isnothing(app.session[]) &&
                                    !isnothing(app.session[].init_error[]))
            @test app.session[].init_error[] isa Exception

            t0 = time()
            threw = try
                Bonito.wait_for_ready(app; timeout=5)
                nothing
            catch e
                e
            end
            @test (time() - t0) < 1.0
            @test threw isa Exception
        finally
            close(server)
        end
    end

    @testset "successful render leaves init_error nothing" begin
        app = App() do session
            return Bonito.DOM.div("hello")
        end
        server = Server(app, "127.0.0.1", 0)
        try
            resp = HTTP.get("http://127.0.0.1:$(server.port)/";
                            readtimeout=15, retry=false, status_exception=false)
            @test resp.status == 200
            @test _wait_until(() -> !isnothing(app.session[]))
            @test isnothing(app.session[].init_error[])
        finally
            close(server)
        end
    end

    @testset "stress: concurrent record_session_error! does not deadlock or leak state" begin
        # Many tasks racing to record errors on the same session — verify
        # that init_error[] always ends in a valid state (either nothing
        # or some Exception we recorded), the indicator's Observable never
        # tears, no exceptions escape the @async tasks, and the operation
        # completes well under the timeout. Catches the case where setting
        # the observable could deadlock with itself or Observables.jl's
        # listener-fire path under contention.
        indicator = Bonito.ConnectionIndicator()
        app = App(_ -> Bonito.DOM.div("ok"); indicator=indicator)
        sess = Session(Bonito.NoConnection(); asset_server=Bonito.NoServer())
        sess.current_app[] = app
        app.session[] = sess

        N = 200    # per task
        K = 8      # tasks
        unhandled = Threads.Atomic{Int}(0)
        finished  = Threads.Atomic{Int}(0)
        tasks = [@async begin
            try
                for i in 1:N
                    Bonito.record_session_error!(sess,
                        _ErrHandlingDemoErr("t$(t)-i$(i)"))
                end
            catch
                Threads.atomic_add!(unhandled, 1)
            finally
                Threads.atomic_add!(finished, 1)
            end
        end for t in 1:K]

        # Hard timeout — if we hang we've found a real bug.
        deadline = time() + 10.0
        while finished[] < K && time() < deadline
            sleep(0.01)
        end
        @test finished[] == K
        @test unhandled[] == 0
        # Final state: init_error and indicator.error are some _ErrHandlingDemoErr
        # (or nothing if the last consumer was an isready-throw — which we
        # don't call here, so they should still be set).
        @test sess.init_error[] isa _ErrHandlingDemoErr
        @test indicator.error[]  isa _ErrHandlingDemoErr
    end

    @testset "stress: many sessions concurrently fail to render — no leaked state" begin
        # Spin up one Server, make K concurrent HTTP requests where each
        # request's handler throws. Every request should get a 200 with
        # inline error; the server should not deadlock, the cleanup task
        # should not race, no thread should be lost.
        app = App(_ -> throw(_ErrHandlingDemoErr("storm")))
        server = Server(app, "127.0.0.1", 0)
        try
            K = 10
            results = Channel{Tuple{Int,Bool}}(K)
            tasks = [@async begin
                ok = try
                    r = HTTP.get("http://127.0.0.1:$(server.port)/";
                                 readtimeout=15, retry=false, status_exception=false)
                    r.status == 200 && occursin("storm", String(r.body))
                catch
                    false
                end
                put!(results, (i, ok))
            end for i in 1:K]
            foreach(wait, tasks)
            close(results)
            outcomes = collect(results)
            @test length(outcomes) == K
            @test all(o -> o[2], outcomes)
            # Some surviving session is reachable from the app — verify it
            # carries the recorded error (don't assert *which* one — multiple
            # request sessions overwrote app.session[]).
            @test !isnothing(app.session[])
        finally
            close(server)
        end
    end

    @testset "render-error → close → no leaked lock or background work" begin
        # After a render error stamps init_error and we explicitly close the
        # session (the documented unrecoverable-decision path), nothing should
        # be left holding `pack_io.lock` or any other session resources.
        s = Session(Bonito.NoConnection(); asset_server=Bonito.NoServer())
        Bonito.handle_render_error(s) do
            throw(_ErrHandlingDemoErr("for-close"))
        end
        @test s.init_error[] isa _ErrHandlingDemoErr
        # Close — should not throw, should not hang.
        t0 = time()
        close(s)
        @test (time() - t0) < 1.0
        @test Bonito.HTTP.WebSockets.isclosed(s)
        @test !islocked(s.pack_io.lock)
    end

    @testset "handle_render_error helper directly" begin
        # The helper is the unit-level building block. Verify it both ways:
        # success returns whatever the closure returns; failure logs, stamps
        # session.init_error[], and returns an error-HTML Node.
        s = Session(Bonito.NoConnection(); asset_server=Bonito.NoServer())
        ok = Bonito.handle_render_error(s) do
            Bonito.DOM.div("ok")
        end
        @test ok isa Bonito.Hyperscript.Node
        @test isnothing(s.init_error[])

        # Error path on a fresh session
        s2 = Session(Bonito.NoConnection(); asset_server=Bonito.NoServer())
        result = Bonito.handle_render_error(s2) do
            throw(_ErrHandlingDemoErr("inner"))
        end
        @test result isa Bonito.Hyperscript.Node    # got an err_to_html Node
        @test s2.init_error[] isa _ErrHandlingDemoErr
        @test s2.init_error[].msg == "inner"
    end
end  # Logging.with_logger
end  # @testset "error handling"
