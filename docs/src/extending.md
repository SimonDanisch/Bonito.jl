# Extending Bonito

## Connection

By default, Bonito uses its own WebSocket server to create the connection between Julia and JavaScript. By extending `Bonito.FrontendConnection`, you can create a new type of connection, e.g. using WebRTC to connect Julia and JavaScript.

Your new connection type should support bidirectional messages of binary data. 

```@setup 1
using Bonito
Bonito.Page()
```

```Julia
mutable struct MyConnection <: Bonito.FrontendConnection
    # TODO: your implementation here
    isopen::Bool
    socket
    blabla
    ...
end

function MyConnection()
    # If you need to do something like start an HTTP server, you can do it here, synchronously.
    
    
    return new(
        true,
        ...
    )
end

function Base.write(connection::MyConnection, binary)
    # TODO: send the data to JavaScript
    write(connection.socket, binary)
end

Base.isopen(connection::MyConnection) = connection.isopen
Base.close(connection::MyConnection) = (connection.isopen = false)
open!(connection::MyConnection) = (connection.isopen = true)

function setup_connection(session::Session{MyConnection})
    # If you need to do something specific for this new session, you can do it here.

    return js"""
    // TODO: create a connection
    create_connection(...).then((conn) => {
        
        // TODO: when your connection receives a message from Julia, relay the message to `Bonito.process_message(msg)`.
        conn.on_msg((msg) => {
            Bonito.process_message(msg)
        });
        
        // TODO: you need to define a JavaScript function that sends a given `binary_data` to Julia. On the Julia side, this should call `Bonito.process_message(connection.parent, binary_data)`.
        const send_to_julia = (binary_data) => conn.send(binary)
        
        // TODO: does your connection use Pako compression on its incoming and outgoing messages?
        const compression_enabled = false
        
        // Register your new connection
        Bonito.on_connection_open(send_to_julia, compression_enabled);
    })
    """
end
```


You can test your new connection like so:

```Julia
Bonito.register_connection!(MyConnection) do
    # you can make this registration conditional, e.g. only use the new connection type on Thursdays...
    if i_want_to_use_it
        return MyConnection()
    else
        return nothing
    end
end
```
