const PLUGIN_NAME = :JSServe
const IJULIA_PKG_ID = Base.PkgId(Base.UUID("7073ff75-c697-5162-941a-fcdaad2a7d2a"), "IJulia")
const IJULIA_REF = Ref{Module}()

function IJulia()
    if !isassigned(IJULIA_REF)
        if !haskey(Base.loaded_modules, IJULIA_PKG_ID)
            error("Trying to setup IJulia state, without IJulia being loaded.")
        end
        IJULIA_REF[] = Base.loaded_modules[IJULIA_PKG_ID]
    end
    return IJULIA_REF[]
end

# IJulia.CommManager.Comm
const IJuliaComm = Any

mutable struct IJuliaConnection <: FrontendConnection
    comm::Union{Nothing, IJuliaComm, WebSocketConnection}
end

function IJuliaConnection()
    # This ENV var gets inserted only for jupyterlab, so we should be on `notebook`
    # Which we can use the IJulia connection for!
    if !haskey(ENV, "JPY_SESSION_NAME")
        # If empty, we can use the IJulia Connection
        return IJuliaConnection(nothing)
    else
        # we fall back to create a websocket connection via a proxy url, figured out in `server-defaults.jl`
        ws_conn = WebSocketConnection()
        return IJuliaConnection(ws_conn)
    end
end

_write(connection::WebSocketConnection, bytes) = Base.write(connection, bytes)
_write(comm, bytes) = IJulia().send_comm(comm, Dict("data" => Base64.base64encode(bytes)))

function Base.write(connection::IJuliaConnection, bytes::AbstractVector{UInt8})
    return _write(connection.comm, bytes)
end

_isopen(connection::WebSocketConnection) = isopen(connection)
_isopen(comm) = haskey(IJulia().CommManager.comms, comm.id)

function Base.isopen(connection::IJuliaConnection)
    isnothing(connection.comm) && return false
    return _isopen(connection.comm)
end

_close(connection::WebSocketConnection) = close(connection)
_close(comm) = IJulia().close_comm(connection.comm)
Base.close(connection::IJuliaConnection) = _close(connection.comm)

function setup_connection(session::Session{IJuliaConnection})
    setup_connection(session, session.connection.comm)
end

# implemented in websocket.jl
# function setup_connection(session::Session, connection::WebSocketConnection)
# end

function setup_connection(session::Session, ::Nothing)
    # For nothing, we open a new IJuliaConnection
    IJulia().eval(quote
        function CommManager.register_comm(comm::CommManager.Comm{$(QuoteNode(PLUGIN_NAME))}, message)
            session = $(session)
            session.connection.comm = comm
            comm.on_msg = function (msg)
                data_b64 = msg.content["data"]
                bytes = $(Base64).base64decode(data_b64)
                $(JSServe).process_message(session, bytes)
            end
            comm.on_close = (args...) -> close(session)
        end
    end)
    id = session.id
    return js"""
        const init_ijulia = () => {
            console.log("setting up IJulia");
            if (!window.Jupyter) {
                throw new Error("Jupyter not loaded");
            }
            const plugin_name = $(JSServe.PLUGIN_NAME);
            const comm_manager = Jupyter.notebook.kernel.comm_manager;
            comm_manager.unregister_target(plugin_name);
            comm_manager.register_target(plugin_name, () => {});
            const comm = comm_manager.new_comm(
                plugin_name, // target_name
                {session_id: $(session.id)}, // data
                undefined, // callbacks
                undefined, // metadata
                undefined, // comm_id
                undefined, // buffers
            );
            comm.on_msg((msg) => {
                JSServe.decode_base64_message(msg.content.data.data, $(session.compression_enabled)).then(JSServe.process_message)
            });

            JSServe.on_connection_open((binary) => {
                JSServe.base64encode(binary).then(x=> comm.send(x))
            }, $(session.compression_enabled));
        }
        init_ijulia();
    """
end
