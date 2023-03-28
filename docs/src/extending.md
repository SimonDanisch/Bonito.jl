# Extending JSServe

## Connection

```@setup 1
using JSServe
JSServe.Page()
```

```Julia

struct MyConnection <: JSServe.FrontendConnection
    ...
end

function MyConnection(parent::Session)
    return MyConnection(parent.connection, false)
end

function Base.write(connection::MyConnection, binary)
    write(connection.connection, binary)
end

Base.isopen(connection::MyConnection) = connection.isopen
Base.close(connection::MyConnection) = (connection.isopen = false)
open!(connection::MyConnection) = (connection.isopen = true)

function setup_connection(session::Session{MyConnection})
    return js"""
    // Javascript needed to connect to
    const conn = create_connection(...) // implemented by your framework
    conn.on_msg((msg) => {
        JSServe.process_message(msg)
    });
    // register sending message
    JSServe.on_connection_open((binary) => {
        comm.send(binary)
    }, $(session.compression_enabled));
    """
end
```
