
# Should only be called if IJulia is loaded!\

function jupyter_running_servers()
    jupyter = IJulia().JUPYTER
    # Man, whats up with jupyter??
    # They switched between versions from stdout to stderr, and also don't produce valid json as output -.-
    json = replace(sprint(io -> run(pipeline(`$jupyter lab list --json`; stderr=io))), "[JupyterServerListApp] " => "")
    if isempty(json)
        json = read(`$jupyter lab list --json`, String)
        if isempty(json)
            # give up -.-
            return nothing
        end
    end
    json = replace(json, r"[\r\n]+" => "\n")
    configs = IJulia().JSON.parse.(split(json, "\n"; keepempty=false))
    return configs
end

function jupyterlab_proxy_url(port)
    config = jupyter_running_servers()
    if isnothing(config)
        @warn "could not automatically figure out jupyter proxy setup"
        return ""
    else
        # taking first kernel
        # TODO, how to match kernel?
        hostname = config[1]["hostname"]
        # TODO, this seems very fragile
        if hostname == "0.0.0.0"
            return string("http://", IJulia().profile["ip"], ":", config[1]["port"], "/proxy/", port)
        else
            return ""
        end
    end
end

function on_julia_hub()
    return haskey(ENV, "JH_APP_URL")
end

function find_proxy_in_environment()
    if on_julia_hub()
        # JuliaHub & VSCode
        return port-> ENV["JH_APP_URL"] * "proxy/$(port)"
    elseif haskey(ENV, "JULIA_WEBIO_BASEURL")
        # Possibly not working anymore, but used to be used in e.g. nextjournal for the proxy url
        return ENV["JULIA_WEBIO_BASEURL"]
    elseif haskey(ENV, "BINDER_SERVICE_HOST")
        # binder
        return port -> ENV["BINDER_SERVICE_HOST"] * "proxy/$port"
    elseif haskey(ENV, "JPY_SESSION_NAME") && haskey(Base.loaded_modules, IJULIA_PKG_ID)
        # Jupyterhub works differently!
        # TODO, is JPY_SESSION_NAME reliably in the env for Jupyterlab? So far it seems so!
        # It definitely isn't there without Jupyterlab
        # jupyterlab
        return jupyterlab_proxy_url
    else
        # TODO, when to use ip address?
        # Sockets.getipaddr()
        return nothing
    end
end

"""
    configure_server!(;
            listen_url::String=SERVER_CONFIGURATION.listen_url[],
            listen_port::Integer=SERVER_CONFIGURATION.listen_port[],
            forwarded_port::Integer=listen_port,
            external_url=nothing,
            content_delivery_url=nothing
        )

Configures the parameters for the automatically started server.

    Parameters:

    * listen_url=SERVER_CONFIGURATION.listen_url[]
        The address the server listens to.
        must be 0.0.0.0, 127.0.0.1, ::, ::1, or localhost.
        If not set differently by an ENV variable, will default to 127.0.0.1

    * listen_port::Integer=SERVER_CONFIGURATION.listen_port[],
        The Port to which the default server listens to
        If not set differently by an ENV variable, will default to 9384

    * forwarded_port::Integer=listen_port,
        if port gets forwarded to some other port, set it here!

    * external_url=nothing
        The url from which the server is reachable.
        If served on "127.0.0.1", this will default to http://localhost:forwarded_port
        if listen_url is "0.0.0.0", this will default to http://\$(Sockets.getipaddr()):forwarded_port
        so that the server is reachable inside the local network.
        If the server should be reachable from some external dns server,
        this needs to be set here.

    * content_delivery_url=nothing
        You can server files from another server.
        Make sure any file referenced from Julia is reachable at
        content_delivery_url * "/the_file"
"""
function configure_server!(;
        listen_url=nothing,
        # The Port to which the default server listens to
        listen_port::Integer=SERVER_CONFIGURATION.listen_port[],
        # if port gets forwarded to some other port, set it here!
        forwarded_port::Integer=listen_port,
        # The url from which the server is reachable.
        # If served on "127.0.0.1", this will default to
        # if listen_url is "0.0.0.0", this will default to
        # Sockets.getipaddr() so that it's the ip address in the local network.
        # If the server should be reachable from some external dns server,
        # this needs to be set here
        external_url=nothing,
        # deprecated
        content_delivery_url=nothing
    )

    if isnothing(listen_url)
        if !isnothing(external_url)
            # if we serve to an external url, server must listen to 0.0.0.0
            listen_url = "0.0.0.0"
        else
            listen_url = SERVER_CONFIGURATION.listen_url[]
        end
    end

    if isnothing(external_url)
        if listen_url == "0.0.0.0"
            external_url = string(Sockets.getipaddr(), ":$forwarded_port")
        elseif listen_url in ("127.0.0.1", "localhost")
            external_url = "http://localhost:$forwarded_port"
        else
            error("Trying to listen to $(listen_url), while only \"127.0.0.1\", \"0.0.0.0\" and \"localhost\" are supported")
        end
    end
    # set the config!
    SERVER_CONFIGURATION.listen_url[] = listen_url
    SERVER_CONFIGURATION.external_url[] = external_url
    SERVER_CONFIGURATION.listen_port[] = listen_port
    return
end

const GLOBAL_SERVER = Ref{Union{Server, Nothing}}(nothing)

const SERVER_CONFIGURATION = (
    # The URL used to which the default server listens to
    listen_url=Ref{Union{String, Nothing}}(nothing),
    # The Port to which the default server listens to
    listen_port=Ref(9384),
    # The url Javascript uses to connect to the websocket.
    # if empty, it will use:
    # `window.location.protocol + "//" + window.location.host`
    external_url=Ref(""),
    # Verbosity for logging!
    verbose=Ref(-1),
)

function singleton_server(;
    listen_url = "127.0.0.1",
    listen_port=SERVER_CONFIGURATION.listen_port[],
    verbose=SERVER_CONFIGURATION.verbose[])

    from_user = SERVER_CONFIGURATION.listen_url[]
    if !isnothing(from_user) # user set the listen url explicitely
        listen_url = from_user # and we respect that!
    end
    create() = Server(listen_url, listen_port; verbose=verbose)
    if isnothing(GLOBAL_SERVER[])
        GLOBAL_SERVER[] = create()
    elseif istaskdone(GLOBAL_SERVER[].server_task[])
        GLOBAL_SERVER[] = create()
    else
        server = GLOBAL_SERVER[]
        # re-create if parameters have changed
        if server.url != listen_url # && server.port == listen_port # leave out port since it matters listens
            close(server)
            GLOBAL_SERVER[] = create()
        end
    end
    return GLOBAL_SERVER[]
end

get_server() = get_server(find_proxy_in_environment())

function get_server(proxy_callback)
    # we have found nothing, so don't do any fancy setup
    if isnothing(proxy_callback)
        return singleton_server()
    else
        url = proxy_callback(8888) # call it with any port, to see if its empty and therefore no proxy is found/needed
        listen_url = isempty(url) ? "127.0.0.1" : "0.0.0.0" # we only need to serve on 0.0.0.0, if we proxy
        server = singleton_server(; listen_url=listen_url)
        real_port = server.port # can change if already in use
        server.proxy_url = proxy_callback(real_port) # which is why the url needs to be a callbacks
        return server
    end

end
