mutable struct MessageBudget
    owner::String
    capacity::Int
    received::Int
    released::Int
    credited::Int
    lock::ReentrantLock
end

function MessageBudget(owner::String, capacity::Int)
    capacity > 0 || throw(ArgumentError("message capacity must be positive"))
    return MessageBudget(owner, capacity, 0, 0, 0, ReentrantLock())
end

function admit_message!(budget::MessageBudget, sequence::Int)
    return lock(budget.lock) do
        sequence > 0 || throw(ArgumentError("Invalid event sequence"))
        sequence <= budget.received && return false
        sequence == budget.received + 1 || throw(ArgumentError("Event sequence has a gap"))
        budget.received - budget.released < budget.capacity || throw(ArgumentError("Event capacity exceeded"))
        budget.received = sequence
        return true
    end
end

function release_message!(budget::MessageBudget, sequence::Int)
    lock(budget.lock) do
        sequence == budget.released + 1 || throw(ArgumentError("Events completed out of order"))
        sequence <= budget.received || throw(ArgumentError("Unreceived event completed"))
        budget.released = sequence
    end
    return nothing
end

# Credits are cumulative, so a burst can share them. A release that finds the queue
# empty always reports: any other release has a later one behind it in the queue.
function credit_due!(budget::MessageBudget, drained::Bool)
    return lock(budget.lock) do
        drained || budget.released - budget.credited >= budget.capacity ÷ 4 || return false
        budget.credited = budget.released
        return true
    end
end

function message_budget(budget::MessageBudget)
    return lock(budget.lock) do
        (; owner=budget.owner, capacity=budget.capacity, received=budget.received, released=budget.released)
    end
end
