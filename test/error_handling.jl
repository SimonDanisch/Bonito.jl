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

using Test, Bonito, HTTP
using Bonito: Server, App, Session

struct _ErrHandlingDemoErr <: Exception
    msg::String
end
Base.showerror(io::IO, e::_ErrHandlingDemoErr) = print(io, "_ErrHandlingDemoErr: ", e.msg)

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

    @testset "Base.isready surfaces init_error by default; throw=false silent" begin
        app = App(_ -> throw(_ErrHandlingDemoErr("hi")))
        server = Server(app, "127.0.0.1", 0)
        try
            HTTP.get("http://127.0.0.1:$(server.port)/";
                     readtimeout=15, retry=false, status_exception=false)
            @test _wait_until(() -> !isnothing(app.session[]) &&
                                    !isnothing(app.session[].init_error[]))
            sess = app.session[]
            # Default: isready throws + consumes (sticky-once).
            @test_throws _ErrHandlingDemoErr Base.isready(sess)
            # After the throw consumed init_error, the second call returns false.
            @test Base.isready(sess; throw=false) == false
            @test Base.isready(sess) == false  # session is now closed; no more error to throw

            # Re-stamp and confirm `throw=false` returns false without throwing.
            sess.init_error[] = _ErrHandlingDemoErr("again")
            @test Base.isready(sess; throw=false) == false
            @test sess.init_error[] isa _ErrHandlingDemoErr  # not consumed by throw=false
        finally
            close(server)
        end
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
end
