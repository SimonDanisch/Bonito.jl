const PLUGIN_NAME = :JSServe

# IJulia.CommManager.Comm
const IJuliaComm = Any

mutable struct IJuliaConnection <: FrontendConnection
    comm::Union{Nothing, IJuliaComm}
end

function send_to_julia(session::Session{IJuliaConnection}, data)
    comm = session.connection[].comm
    IJulia.send_comm(comm, data)
end

Base.isopen(c::IJuliaConnection) = haskey(IJulia.CommManager.comms, c.comm.id)

function setup_connect(session::Session{IJuliaConnection})
    @eval begin
        function IJulia.CommManager.register_comm(comm::IJulia.CommManager.Comm{PLUGIN_NAME}, message)
            comm.on_msg = function (msg)
                data = msg.content["data"]
                data_uint8 = Base64.base64decode(data)
                JSServe.process_message(session, data_uint8)
            end
            comm.on_close = (args...)-> begin
                close(session)
            end
        end
    end
    id = session.id
    return js"""
        (async () => {
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
                JSServe.process_message(msg.content.data)
            });

            JSServe.on_connection_open(async (binary) => {
                const b64encoded = await JSServe.base64encode(binary);
                comm.send(b64encoded)
            })
        })()
    """
end
