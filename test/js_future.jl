using Bonito, Test

@testset "JavaScript future contract" begin
    api = (:JSFuture, :JSRequests, :js_request!, :complete_js!, :close_js!, :JSSuccess, :JSFailure)
    for name in api
        @test isdefined(Bonito, name)
    end
    if all(name -> isdefined(Bonito, name), api)
        @testset "cached result and multiple waiters" begin
            requests = Bonito.JSRequests("page")
            future = Bonito.js_request!(requests; timeout=5)
            @test future isa Bonito.JSFuture
            @test !isready(future)
            first_waiter = @async fetch(future)
            second_waiter = @async fetch(future)
            @test Bonito.complete_js!(requests, future.id, Bonito.JSSuccess(42))
            @test fetch(first_waiter) == fetch(second_waiter) == 42
            @test isready(future)
            @test wait(future) === future
            @test fetch(future) == 42
            @test isempty(requests)
        end

        @testset "result and error are distinct" begin
            requests = Bonito.JSRequests("page")
            for value in (nothing, false, Dict("error"=>"ordinary data"))
                future = Bonito.js_request!(requests; timeout=5)
                @test Bonito.complete_js!(requests, future.id, Bonito.JSSuccess(value))
                @test fetch(future) == value
            end
            future = Bonito.js_request!(requests; timeout=5)
            failure = ErrorException("JavaScript rejected")
            @test Bonito.complete_js!(requests, future.id, Bonito.JSFailure(failure))
            @test isready(future)
            @test_throws "JavaScript rejected" fetch(future)
            @test_throws "JavaScript rejected" fetch(future)
            @test isempty(requests)
        end

        @testset "first terminal transition wins" begin
            for first in (:reply, :timeout, :close), second in (:reply, :timeout, :close)
                requests = Bonito.JSRequests("page")
                future = Bonito.js_request!(requests; timeout=5)
                transition(action) = action == :close ? Bonito.close_js!(requests, ErrorException("close")) :
                    Bonito.complete_js!(requests, future.id, action == :reply ? Bonito.JSSuccess(42) : Bonito.JSFailure(ErrorException("timeout")))
                transition(first)
                transition(second)
                @test isready(future)
                if first == :reply
                    @test fetch(future) == 42
                else
                    @test_throws String(first) fetch(future)
                end
                @test isempty(requests)
            end
        end

        @testset "concurrent completions" begin
            for _ in 1:30
                requests = Bonito.JSRequests("page")
                future = Bonito.js_request!(requests; timeout=5)
                contenders = [Threads.@spawn Bonito.complete_js!(requests, future.id, Bonito.JSSuccess(i)) for i in 1:8]
                won = fetch.(contenders)
                @test count(won) == 1
                @test fetch(future) == only(findall(won))
                @test isempty(requests)
            end
        end

        @testset "deadline expires without a fetch" begin
            requests = Bonito.JSRequests("page")
            future = Bonito.js_request!(requests; timeout=0.02)
            @test Bonito.wait_for(() -> isready(future); timeout=2) == :success
            @test_throws "Timed out" fetch(future)
            @test isempty(requests)
            @test !Bonito.complete_js!(requests, future.id, Bonito.JSSuccess("late"))
            @test_throws "Timed out" fetch(future)
        end

        @testset "closure releases waiters and rejects new requests" begin
            requests = Bonito.JSRequests("page")
            futures = [Bonito.js_request!(requests; timeout=5) for _ in 1:4]
            waiters = [@async try fetch(future) catch err; err end for future in futures]
            Bonito.close_js!(requests, ErrorException("connection closed"))
            @test all(isready, futures)
            @test all(err -> err isa ErrorException && err.msg == "connection closed", fetch.(waiters))
            @test isempty(requests)
            after = Bonito.js_request!(requests; timeout=5)
            @test isready(after)
            @test_throws "connection closed" fetch(after)
            @test isempty(requests)
        end

        @testset "bounded pending requests and timer cleanup" begin
            requests = Bonito.JSRequests("page")
            first = Bonito.js_request!(requests; timeout=5, max_pending=2)
            second = Bonito.js_request!(requests; timeout=5, max_pending=2)
            excess = Bonito.js_request!(requests; timeout=5, max_pending=2)
            @test isready(excess)
            @test_throws "Too many pending" fetch(excess)
            @test excess.timer === nothing
            @test length(requests.pending) == 2
            @test Bonito.complete_js!(requests, first.id, Bonito.JSSuccess(1))
            @test first.timer === nothing
            replacement = Bonito.js_request!(requests; timeout=5, max_pending=2)
            @test !isready(replacement)
            Bonito.close_js!(requests, ErrorException("closed"))
            @test second.timer === replacement.timer === nothing
            expired = Bonito.js_request!(Bonito.JSRequests("other"); timeout=0)
            @test isready(expired)
            @test_throws "Timed out" fetch(expired)
        end

        @testset "closing a child cancels only its own requests" begin
            requests = Bonito.JSRequests("page")
            first = Bonito.js_request!(requests; owner="first", timeout=5)
            second = Bonito.js_request!(requests; owner="second", timeout=5)
            Bonito.cancel_js!(requests, "first", InvalidStateException("Session closed", :closed))
            @test_throws InvalidStateException fetch(first)
            @test first.timer === nothing
            @test !isready(second)
            @test Bonito.complete_js!(requests, second.id, Bonito.JSSuccess(2))
            @test fetch(second) == 2
            @test isempty(requests)
        end

        @testset "request identities survive closure without reuse" begin
            first = Bonito.JSRequests("page")
            old = Bonito.js_request!(first; timeout=5)
            Bonito.close_js!(first, ErrorException("disconnected"))
            next = Bonito.JSRequests("page")
            fresh = Bonito.js_request!(next; timeout=5)
            @test old.id != fresh.id
            @test !Bonito.complete_js!(next, old.id, Bonito.JSSuccess("stale"))
            @test !isready(fresh)
            @test Bonito.complete_js!(next, fresh.id, Bonito.JSSuccess("fresh"))
            @test fetch(fresh) == "fresh"
            @test_throws "disconnected" fetch(old)
        end
    end
end
