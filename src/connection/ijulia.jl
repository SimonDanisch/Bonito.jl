const PLUGIN_NAME = :JSServe

# IJulia.CommManager.Comm
const IJuliaComm = Any

mutable struct IJuliaConnection <: FrontendConnection
    comm::Union{Nothing, IJuliaComm}
end

function send_message(session::Session{IJuliaConnection}, data)
    comm = session.connection[].comm
    IJulia.send_comm(comm, data)
end

Base.isopen(c::IJuliaConnection) = haskey(IJulia.CommManager.comms, c.comm.id)

function init_connection(session::Session{IJuliaConnection})
    @eval begin
        function IJulia.CommManager.register_comm(comm::IJulia.CommManager.Comm{PLUGIN_NAME}, message)
            session = look_up_session(comm["data"]["session_id"])
            comm.on_msg = function (msg)
                data_uint8 = Base64.base64decode(msg.content["data"])
                process_message(session, data_uint8)
            end
        end
    end
    id = session.id
    return js"""

    if (!window.IJulia) {
        throw "IJulia not loaded"
    }
    const plugin_name = $(PLUGIN_NAME)
    const comm_manager = Jupyter.notebook.kernel.comm_manager
    comm_manager.unregister_target(plugin_name)
    comm_manager.register_target(plugin_name, () => {})

    const comm = comm_manager.new_comm(
        plugin_name, // target_name
        {session_id: $(id)}, // data
        undefined, // callbacks
        undefined, // metadata
        undefined, // comm_id
        undefined, // buffers
    )

    comm.on_msg((msg) => {
        $(JSServeLib).process_message(msg.content.data)
    });

    $(JSServeLib).set_message_callback((binary) => {
        const decoder = new TextDecoder('utf8');
        const b64encoded = btoa(decoder.decode(binary));
        comm.send(b64encoded)
    })
    """
end
