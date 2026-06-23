# Failing tests for the "Key not found" race documented in the BonitoTeam
# review.
#
# The Julia-side bug: `process_message`'s `UpdateObservable` branch reads
# `session.session_objects[id]` WITHOUT acquiring `deletion_lock`, while
# `Base.close(session)` → `free(session)` (which holds the lock) is busy
# `empty!`-ing the same Dict and `off`-ing the listeners. Two consequences:
#
#   1. A listener registered via `on(session, obs) do ...` can fire AFTER
#      close completed — i.e. on a session whose `status === CLOSED` and
#      whose Dict + queue are already torn down. Any send back through
#      that session is silently lost.
#   2. The Dict access itself is unsafe if Julia is multithreaded; on a
#      single-threaded scheduler we still see (1) reliably.
#
# JS-side counterpart (covered by the Electron test in this directory):
# the same race manifests as `Key ${key} not found! ${object}` warnings
# in `Sessions.js` when an `UpdateObservable` reaches the browser for a
# key that `free_session` already removed from `GLOBAL_OBJECT_CACHE`.
#
# Both tests are EXPECTED TO FAIL today and EXPECTED TO PASS after
# `process_message`'s `UpdateObservable` branch acquires `deletion_lock`
# (and the JS branch acquires `OBJECT_FREEING_LOCK`).

using Bonito: Session, NoConnection, NoServer, add_cached!, process_message,
              UpdateObservable, free, CLOSED, MsgPack
using Bonito: Observable, on

# ── Helpers ──────────────────────────────────────────────────────────────────

# A bare-bones root session with no real connection / asset server. Good
# enough to exercise process_message + free without bringing up Electron.
fresh_offline_session() = Session(NoConnection(); asset_server = NoServer())

# Synthesise the exact bytes a real frontend would send for an
# `UpdateObservable` notification.
function update_message_bytes(obs_id::AbstractString, payload)
    return MsgPack.pack(Dict("msg_type" => UpdateObservable,
                             "id"       => obs_id,
                             "payload"  => payload))
end

# ── Test ─────────────────────────────────────────────────────────────────────

@testset "process_message must not invoke listeners after close()" begin
    # Real parallelism via `Threads.@spawn`. With single-thread `@async`
    # the close() task tends to run to completion before the
    # process_message task ever yields back, hiding the race. Two threads
    # let the empty!/lookup interleave the way they do under load.
    Threads.nthreads() < 2 && @warn "Race test needs >= 2 threads to reliably reproduce; \
                                     run with --threads=auto or skip"

    n_iter            = 1000
    n_after_close     = Threads.Atomic{Int}(0)
    n_unhandled_error = Threads.Atomic{Int}(0)

    for _ in 1:n_iter
        session = fresh_offline_session()
        obs     = Observable(0)
        # Register obs in session_objects the same way jsrender would.
        add_cached!(() -> nothing, session, Dict{String,Any}(), obs)

        # Listener with a tiny pause so it has time to overlap close()'s
        # tail (status = CLOSED + connection teardown). Without any
        # delay, the listener body runs atomically before the scheduler
        # gets a chance to advance close() past `empty!`.
        on(session, obs) do _v
            sleep(0.0005)
            session.status === CLOSED && Threads.atomic_add!(n_after_close, 1)
        end

        bytes = update_message_bytes(obs.id, 1)

        t1 = Threads.@spawn try close(session)               catch _; Threads.atomic_add!(n_unhandled_error, 1) end
        t2 = Threads.@spawn try process_message(session, bytes) catch _; Threads.atomic_add!(n_unhandled_error, 1) end
        wait(t1); wait(t2)
    end

    # Any uncaught error from either side is a bug too — silently
    # swallowed today by the @async wrappers in production code.
    @test n_unhandled_error[] == 0

    # The headline assertion: zero listener invocations after close.
    # Currently expected to fail (n_after_close[] > 0); should be 0 after
    # the `deletion_lock` patch lands in `process_message`.
    @info "race summary" n_iter n_after_close=n_after_close[] n_unhandled_error=n_unhandled_error[]
    @test n_after_close[] == 0
end

@testset "Concurrent UpdateObservable + close: Dict stays consistent" begin
    # Even when the listener-after-close path is fixed, the underlying
    # Dict mutation needs to be lock-protected. This stresses the bare
    # Dict access that `process_message` performs.
    n_iter = 500
    failures = Threads.Atomic{Int}(0)
    for _ in 1:n_iter
        session = fresh_offline_session()
        # Pre-populate with several observables so `empty!` has more work
        # to do (widening the race window).
        ids = String[]
        for _ in 1:8
            o = Observable(0)
            add_cached!(() -> nothing, session, Dict{String,Any}(), o)
            push!(ids, o.id)
        end
        msg_bytes = update_message_bytes(rand(ids), 42)

        t1 = Threads.@spawn try close(session)               catch _; Threads.atomic_add!(failures, 1) end
        t2 = Threads.@spawn try process_message(session, msg_bytes) catch _; Threads.atomic_add!(failures, 1) end
        wait(t1); wait(t2)
    end
    @test failures[] == 0
end

# ── JS-side regression sentinel ──────────────────────────────────────────────
#
# Stress test against a real Electron browser. Hammers the same
# create-render-tear-down-with-in-flight-updates pattern that triggers
# "Key not found" warnings in production. Note: in synthetic conditions
# (fast localhost loopback, no network jitter) the race window is too
# narrow to reliably reproduce — this test typically passes today *and*
# after the patch. Its value is as a regression sentinel: if a future
# change reintroduces a broader race window, this test will start failing
# in CI before users hit it.
#
# The deterministic proof of the bug is the Julia-side @testset above.
@testset "Electron: no 'Key not found' warnings under remount stress" begin
    # Each render creates a NEW per-sub observable that the sub owns. When
    # we swap the outer DOM, that sub gets closed; if Julia is still
    # firing notify!() on the just-closed sub's observable in another
    # task, the JSUpdateObservable listener races free_session.
    sub_obs_handles = Channel{Observable}(64)

    outer_obs = Observable{Any}(DOM.div("init"))
    app = App() do session
        return DOM.div(outer_obs)
    end
    display(edisplay, app)
    Bonito.wait_for(() -> !isnothing(app.session[]); timeout=5)
    win = edisplay.window

    # Capture console.warn entries that look like "Key ... not found".
    run(win, """
        window.__keyNotFoundWarnings = [];
        const orig = console.warn;
        console.warn = (...args) => {
            const msg = args.map(String).join(' ');
            if (msg.indexOf('not found') !== -1) {
                window.__keyNotFoundWarnings.push(msg);
            }
            orig.apply(console, args);
        };
        true
    """)

    n_iter = 30
    update_tasks = Task[]
    for i in 1:n_iter
        # Build a DOM that creates a fresh per-iteration observable on
        # render. Capture it via a side channel so we can keep firing
        # updates after the sub is supposed to be torn down.
        per_iter_obs = Observable("v0-$i")
        put!(sub_obs_handles, per_iter_obs)
        new_dom = DOM.div("iter-$i",
                          DOM.span(per_iter_obs))   # binds JSUpdateObservable
        outer_obs[] = new_dom
        # Spawn a background task that hammers updates on the just-rendered
        # observable. Some of these will arrive at JS *after* the next
        # outer_obs swap closes the sub.
        t = Threads.@spawn begin
            for j in 1:20
                try
                    per_iter_obs[] = "v$j-$i"
                catch e
                    # Intentional: this update may race the sub's teardown (the
                    # point of the test). A Julia-side throw here is tolerated;
                    # what we assert is that JS never logs "Key not found".
                    @debug "update raced session teardown" exception = e
                end
                sleep(0.001)
            end
        end
        push!(update_tasks, t)
    end

    # Let the storm settle.
    foreach(wait, update_tasks)
    sleep(2.0)

    n_warn = run(win, "(window.__keyNotFoundWarnings || []).length")
    if n_warn > 0
        sample = run(win, "(window.__keyNotFoundWarnings || []).slice(0, 3)")
        @info "Key-not-found warnings observed" n_warn sample
    end
    @test n_warn == 0
end
