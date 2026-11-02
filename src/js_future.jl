abstract type JSOutcome end

struct JSSuccess <: JSOutcome
    value::Any
end

struct JSFailure <: JSOutcome
    exception::Exception
end

mutable struct JSFuture
    id::String
    owner::String
    result::Channel{JSOutcome}
    timer::Union{Nothing,Timer}
end

JSFuture(id::String, owner::String) = JSFuture(id, owner, Channel{JSOutcome}(1), nothing)

js_value(outcome::JSSuccess) = outcome.value
js_value(outcome::JSFailure) = throw(outcome.exception)
Base.fetch(future::JSFuture) = js_value(fetch(future.result))
Base.isready(future::JSFuture) = isready(future.result)
Base.wait(future::JSFuture) = (fetch(future); future)

mutable struct JSRequests
    namespace::String
    lock::ReentrantLock
    pending::Dict{String,JSFuture}
    closed::Union{Nothing,Exception}
end

JSRequests(namespace::String) = JSRequests(namespace, ReentrantLock(), Dict{String,JSFuture}(), nothing)
Base.isempty(requests::JSRequests) = lock(() -> isempty(requests.pending), requests.lock)
is_pending(requests::JSRequests, id::String) = lock(() -> haskey(requests.pending, id), requests.lock)

function stop_js_timer!(future::JSFuture)
    future.timer === nothing || close(future.timer)
    future.timer = nothing
    return nothing
end

function complete_js!(requests::JSRequests, id::String, outcome::JSOutcome)
    # Removing the request selects the sole completion, before waking any waiter.
    future = lock(requests.lock) do
        pop!(requests.pending, id, nothing)
    end
    future === nothing && return false
    stop_js_timer!(future)
    put!(future.result, outcome)
    return true
end

function js_request!(requests::JSRequests; timeout::Real=10.0, owner::String=requests.namespace, max_pending::Int=1024)
    timeout >= 0 || throw(ArgumentError("timeout must be nonnegative"))
    future = JSFuture("$(requests.namespace)/$(uuid4())", owner)
    lock(requests.lock) do
        if requests.closed !== nothing
            put!(future.result, JSFailure(requests.closed))
            return
        end
        if timeout == 0
            put!(future.result, JSFailure(InvalidStateException("Timed out", :timed_out)))
            return
        end
        if length(requests.pending) >= max_pending
            put!(future.result, JSFailure(ErrorException("Too many pending JavaScript requests")))
            return
        end
        requests.pending[future.id] = future
        if isfinite(timeout)
            future.timer = Timer(timeout) do _
                complete_js!(requests, future.id, JSFailure(InvalidStateException("Timed out", :timed_out)))
            end
        end
    end
    return future
end

function open_js!(requests::JSRequests)
    lock(requests.lock) do
        requests.closed = nothing
    end
    return nothing
end

function cancel_js!(requests::JSRequests, owner::String, reason::Exception)
    futures = lock(requests.lock) do
        selected = JSFuture[]
        for (id, future) in requests.pending
            future.owner == owner || continue
            push!(selected, future)
        end
        foreach(future -> delete!(requests.pending, future.id), selected)
        return selected
    end
    for future in futures
        stop_js_timer!(future)
        put!(future.result, JSFailure(reason))
    end
    return nothing
end

function close_js!(requests::JSRequests, reason::Exception)
    futures = lock(requests.lock) do
        requests.closed === nothing || return JSFuture[]
        requests.closed = reason
        futures = collect(values(requests.pending))
        empty!(requests.pending)
        return futures
    end
    for future in futures
        stop_js_timer!(future)
        put!(future.result, JSFailure(reason))
    end
    return nothing
end
