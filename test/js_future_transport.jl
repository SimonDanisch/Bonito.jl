using Bonito, Test

mutable struct FutureConnection <: Bonito.FrontendConnection
    online::Bool
    fail_write::Bool
    writes::Vector{Any}
end

FutureConnection() = FutureConnection(true, false, Any[])
Base.isopen(connection::FutureConnection) = connection.online
Base.close(connection::FutureConnection) = (connection.online = false; nothing)
Bonito.open!(connection::FutureConnection) = (connection.online = true; nothing)
function Base.write(connection::FutureConnection, message::Bonito.SerializedMessage)
    connection.online || error("disconnected")
    connection.fail_write && error("send failed")
    push!(connection.writes, message.data)
    return nothing
end

request_writes(connection::FutureConnection) = filter(message -> haskey(message,"request_id"), connection.writes)

function future_session(; n_inbox=8)
    connection = FutureConnection()
    session = Bonito.Session(connection; asset_server=Bonito.NoServer(), n_inbox, compression_enabled=false)
    session.status = Bonito.OPEN
    put!(session.connection_ready, true)
    return session, connection
end

struct FutureHolder
    session::Bonito.Session
end
Bonito.session(holder::FutureHolder) = holder.session

function future_reply(session, id, value)
    frame = Bonito.MsgPack.pack(Dict("msg_type"=>Bonito.JavascriptResult, "id"=>id, "result"=>value))
    Bonito.receive!(session, frame)
end

@testset "JavaScript request transport contract" begin
    api = (:evaljs_async, :receive!, :JavascriptResult)
    for name in api
        @test isdefined(Bonito, name)
    end
    if all(name -> isdefined(Bonito, name), api)
        @testset "one send path and one receive path" begin
            session, connection = future_session()
            try
                future = Bonito.evaljs_async(session, js"42"; timeout=5)
                @test !isready(future)
                @test length(request_writes(connection)) == 1
                @test only(request_writes(connection))["request_id"] == future.id
                future_reply(session, future.id, 42)
                @test fetch(future) == 42
                future_reply(session, future.id, "duplicate")
                @test fetch(future) == 42
            finally
                close(session)
            end
        end

        @testset "a malformed frame does not lose pending replies" begin
            session, _ = future_session()
            try
                future = evaljs_async(session, js"42"; timeout=5)
                @test_logs (:warn, "error while decoding received msg") Bonito.receive!(session, UInt8[0xc1])
                @test !isready(future)
                future_reply(session, future.id, 42)
                @test fetch(future) == 42
            finally
                close(session)
            end
        end

        @testset "disconnected submission is never replayed" begin
            session, connection = future_session()
            try
                connection.online = false
                future = Bonito.evaljs_async(session, js"window.counter++"; timeout=5)
                @test isready(future)
                @test_throws "not open" fetch(future)
                @test isempty(session.message_queue)
                Bonito.open!(connection)
                Bonito.init_session(session)
                @test isempty(request_writes(connection))
            finally
                close(session)
            end
        end

        @testset "uncertain sends fail without automatic retry" begin
            session, connection = future_session()
            try
                connection.fail_write = true
                future = Bonito.evaljs_async(session, js"window.counter++"; timeout=5)
                @test isready(future)
                @test_throws "send failed" fetch(future)
                @test isempty(session.message_queue)
                connection.fail_write = false
                Bonito.init_session(session)
                @test isempty(request_writes(connection))
            finally
                close(session)
            end
        end

        @testset "disconnect completes requests and old replies stay old" begin
            session, connection = future_session()
            try
                old = Bonito.evaljs_async(session, js"window.counter++"; timeout=5)
                sent = copy(request_writes(connection))
                Bonito.soft_close(session)
                @test isready(old)
                @test_throws "disconnected" fetch(old)
                Bonito.init_session(session)
                @test request_writes(connection) == sent
                fresh = Bonito.evaljs_async(session, js"42"; timeout=5)
                @test fresh.id != old.id
                future_reply(session, old.id, "late")
                @test !isready(fresh)
                future_reply(session, fresh.id, 42)
                @test fetch(fresh) == 42
            finally
                close(session)
            end
        end

        @testset "expiry while waiting to submit does not execute JavaScript" begin
            session, connection = future_session()
            try
                task = lock(session.deletion_lock) do
                    submitted = @async evaljs_async(session, js"window.counter++"; timeout=0.02)
                    @test Bonito.wait_for(() -> !isempty(Bonito.root_data(session).js_requests); timeout=2) == :success
                    @test Bonito.wait_for(() -> isempty(Bonito.root_data(session).js_requests); timeout=2) == :success
                    submitted
                end
                future = fetch(task)
                @test_throws "Timed out" fetch(future)
                @test isempty(request_writes(connection))
            finally
                close(session)
            end
        end

        @testset "root reuse cancels old requests" begin
            session, connection = future_session()
            try
                old = evaljs_async(session, js"42"; timeout=5)
                empty!(session)
                @test isready(old)
                @test_throws "reset" fetch(old)
                fresh = evaljs_async(session, js"43"; timeout=5)
                future_reply(session, old.id, 42)
                @test !isready(fresh)
                future_reply(session, fresh.id, 43)
                @test fetch(fresh) == 43
            finally
                close(session)
            end
        end

        @testset "synchronous closure compatibility" begin
            session, connection = future_session()
            task = @async evaljs_value(session, js"42"; timeout=5)
            @test Bonito.wait_for(() -> !isempty(request_writes(connection)); timeout=2) == :success
            close(session)
            @test fetch(task) === nothing
            @test evaljs_value(session, js"42"; error_on_closed=false) === nothing
            @test_throws "not open" evaljs_value(session, js"42")
        end

        @testset "a closed child returns nothing without submitting" begin
            session, connection = future_session()
            try
                child = Bonito.Session(session)
                close(child)
                @test evaljs_value(child, js"42") === nothing
                @test_throws "closed" fetch(evaljs_async(child, js"42"))
                @test isempty(request_writes(connection))
            finally
                close(session)
            end
        end

        @testset "a recorded session error surfaces instead of a generic failure" begin
            session, connection = future_session()
            try
                Bonito.record_session_error!(session, ErrorException("render failed"))
                @test_throws "render failed" evaljs_value(session, js"42")
                @test isempty(request_writes(connection))
            finally
                close(session)
            end
        end

        @testset "objects holding a session keep their longer default timeout" begin
            session, connection = future_session()
            try
                task = @async evaljs_value(FutureHolder(session), js"42")
                @test timedwait(() -> istaskdone(task), 10.5) === :timed_out
                future_reply(session, only(request_writes(connection))["request_id"], 42)
                @test fetch(task) == 42
            finally
                close(session)
            end
        end

        @testset "a loading child uses its ready root transport" begin
            session, connection = future_session()
            try
                child = Bonito.Session(session)
                @test !Bonito.isready(child)
                future = evaljs_async(child, js"42"; timeout=5)
                @test length(request_writes(connection)) == 1
                @test isempty(child.message_queue)
                future_reply(session, future.id, 42)
                @test fetch(future) == 42
            finally
                close(session)
            end
        end

        @testset "session closure releases requests" begin
            session, _ = future_session()
            futures = [Bonito.evaljs_async(session, js"42"; timeout=5) for _ in 1:3]
            close(session)
            @test all(isready, futures)
            for future in futures
                @test_throws "closed" fetch(future)
            end
        end
    end
end
