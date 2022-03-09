struct NoConnection <: FrontendConnection end


function send_to_julia(session::Session{NoConnection}, data)
    error("Can't communicate with Frontend with no Connection")
end

Base.isopen(::NoConnection) = false

function setup_connect(session::Session{NoConnection})
    return nothing
end
