const PLUGIN_NAME = :JSServe
const IJULIA_PKG_ID = Base.PkgId(Base.UUID("7073ff75-c697-5162-941a-fcdaad2a7d2a"), "IJulia")
const IJulia = Ref{Module}()
# IJulia.CommManager.Comm
const IJuliaComm = Any

mutable struct IJuliaConnection <: FrontendConnection
    comm::Union{Nothing, IJuliaComm}
end

function Base.write(connection::IJuliaConnection, bytes::AbstractVector{UInt8})
    comm = connection.comm
    IJulia[].send_comm(comm, Dict("data" => Base64.base64encode(bytes)))
end

function Base.isopen(c::IJuliaConnection)
    isnothing(c.comm) && return false
    return haskey(IJulia[].CommManager.comms, c.comm.id)
end

function setup_connect(session::Session{IJuliaConnection})
    IJulia[] = Base.loaded_modules[IJULIA_PKG_ID]
    expr = quote
        function IJulia.CommManager.register_comm(comm::CommManager.Comm{$(QuoteNode(PLUGIN_NAME))}, message)
            session = $(session)
            session.connection.comm = comm
            comm.on_msg = function (msg)
                data_b64 = msg.content["data"]
                bytes = $(Base64).base64decode(data_b64)
                $(JSServe).process_message(session, bytes)
            end
            comm.on_close = (args...)-> close(session)
        end
    end

    IJulia[].eval(expr)

    id = session.id
    return js"""
        (() => {
            console.log("setting up IJulia")
            if (!window.Jupyter) {
                throw "Jupyter not loaded"
            }
            const plugin_name = $(JSServe.PLUGIN_NAME)
            const comm_manager = Jupyter.notebook.kernel.comm_manager
            comm_manager.unregister_target(plugin_name)
            comm_manager.register_target(plugin_name, () => {})
            const comm = comm_manager.new_comm(
                plugin_name, // target_name
                {session_id: $(session.id)}, // data
                undefined, // callbacks
                undefined, // metadata
                undefined, // comm_id
                undefined, // buffers
            )
            comm.on_msg((msg) => {
                JSServe.decode_base64_message(msg.content.data.data).then(JSServe.process_message)
            });

            JSServe.on_connection_open((binary) => {
                JSServe.base64encode(binary).then(x=> comm.send(x))
            })
        })()
    """
end
