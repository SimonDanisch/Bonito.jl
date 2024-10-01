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

## Managing your own WebSocket server

You should also extend `Bonito.FrontendConnection` in case you would like to make a WebSocket-based connection, but manage the server yourself, e.g. by registering a websocket route using a web framework. In this case, you can reuse some of Bonito's websocket handling code as long as your websocket is internally using `HTTP.WebSockets.WebSocket` objects.

You can do this using the `WebSocketHandler` type and forwarding your connection type's `isopen`, `write`, and `close` methods to it. You can then use the `setup_websocket_connection_js` to return the correct Javascript snippet in your `setup_connection` method and run the main I/O loop by calling `run_connection_loop` from your websocket handler. You will need to take care of saving the session in your `setup_connection` method and routing to the session in your handler, as well as cleaning up websocket sessions. You may need to use locks to accomplish some of these steps in a thread-safe manner.


```Julia
mutable struct MyWebSocketConnection <: Bonito.FrontendConnection
    # TODO: your implementation here
    blabla
    ...
    handler::WebSocketHandler
end

Base.isopen(ws::MyWebSocketConnection) = isopen(ws.handler)
Base.write(ws::MyWebSocketConnection, binary) = write(ws.handler, binary)
Base.close(ws::MyWebSocketConnection) = close(ws.handler)

function setup_connection(session::Session{MyWebSocketConnection})
    return setup_connection(session, session.connection)

    # TODO: Register the `session.id` as a route, and save it so it can be retrived in the handler
    # You could alternatively register a single route and multiplex using a dictionary
    # TODO: Start a cleanup task to remove routes/saved sessions when they are no longer open

    external_url = # TODO: Get the external URL, which session IDs will be appended to
    return setup_websocket_connection_js(external_url, session)
end

function my_web_framework_websocket_handler(my_web_framework_request)
    session = # TODO: retrieve the session based upon the session ID in the URL in `my_web_framework_request`
    websocket = # TODO: set up the websocket or retrive it from `my_web_framework_request`
    connection = session.connection

    try
        run_connection_loop(session, connection.handler, websocket)
    finally
        # TODO: Option 1: Immediately end the session with `close(session)`
        # You will also need to clean up the route/saved session
        
        # TODO: Option 2: Use `soft_close(session)`
        # This may allow for a temporary disconnected client to reconnect
        # You may have to prevent your webframework from trying to close the websocket
        # You will need to clean up the soft closed session and its route/saved session after some timeout in the cleanup task
    end
end

# Here is the cleanup task. You might choose to arrange for exactly one of these to be started at some appropriate time.
# You may like to handle errors so that it always remains running.
@async while true
    sleep(1)
    # Iterate through the sessions and routes that have been set up in `setup_connection`
    for (session, route) in my_route_data_structure
        # Apply some cleanup policy to closed or soft closed sessions
        if should_cleanup(session)
            # mark route for removeal
        end
    end
    # remove marked routes
end
```

You can get further details to guide your implementation by looking at Bonito's own implementation in `Bonito/src/connections/websocket.jl`.

Please read the next section for information about how to make use of Bonito's websocket cleanup policy in your cleanup task.

## Customising the websocket cleanup policy

You can create a custom cleanup policy by subclassing `CleanupPolicy`. For example, you may like to choose to evict sessions based upon the resources they are using, or whether users are authenticated or not or some other criteria.

Implementing the `should_cleanup` and `allow_soft_close` methods is required.

```julia
struct MyCleanupPolicy <: Bonito.CleanupPolicy end

function Bonito.should_cleanup(policy::MyCleanupPolicy, session::Session)
    ...
end

function Bonito.allow_soft_close(policy::MyCleanupPolicy)
    ...
end

Bonito.set_cleanup_policy!(MyCleanupPolicy())
```

You can also make use of cleanup policies including `DefaultCleanupPolicy()` if you manage your own websocket server as outlined in the previous section.

You can get further details to guide your implementation by looking at Bonito's own implementation in `Bonito/src/connections/websocket.jl`.
