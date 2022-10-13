struct NoConnection <: FrontendConnection end


function send_to_julia(session::Session{NoConnection}, data)
    error("Can't communicate with Frontend with no Connection")
end

Base.isopen(::NoConnection) = false

function setup_connect(session::Session{NoConnection})
    return js"""
        JSServe.on_connection_open((w)=> undefined)
    """
end
