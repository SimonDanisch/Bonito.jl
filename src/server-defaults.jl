const GLOBAL_SERVER = Ref{Union{Server,Nothing}}(nothing)

const SERVER_CONFIGURATION = (
    # The URL used to which the default server listens to
    listen_url=Ref{Union{String,Nothing}}(nothing),
    # The Port to which the default server listens to
    listen_port=Ref(9384),
    # The url Javascript uses to connect to the websocket.
    # if empty, it will use:
    # `window.location.protocol + "//" + window.location.host`
    proxy_url=Ref(""),
    # Verbosity for logging!
    verbose=Ref(-1)
)

# Should only be called if IJulia is loaded!\

function jupyter_running_servers()
    jupyter = IJulia().JUPYTER
    # Man, whats up with jupyter??
    # They switched between versions from stdout to stderr, and also don't produce valid json as output -.-
    run_cmd(std, err) = run(pipeline(`$jupyter lab list --json`; stderr=err, stdout=std))
    json = sprint(io -> run_cmd(io, IOBuffer()))
    if isempty(json)
        json = sprint(io -> run_cmd(IOBuffer(), io))
        if isempty(json)
            # give up -.-
            return nothing
        end
    end
    json = replace(json, "[JupyterServerListApp] " => "")
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
        if haskey(ENV, "BONITO_JUPYTER_REMOTE_HOST")
            return string(get(ENV, "BONITO_JUPYTER_REMOTE_HOST"), config[1]["base_url"], "proxy/", port)
        elseif hostname == "0.0.0.0" || hostname == "localhost"
            return string("http://", IJulia().profile["ip"], ":", config[1]["port"], config[1]["base_url"], "proxy/", port)
        else
            return ""
        end
    end
end

function find_proxy_in_environment()
    if !isempty(SERVER_CONFIGURATION.proxy_url[])
        return port-> SERVER_CONFIGURATION.proxy_url[]
    elseif haskey(ENV, "JH_APP_URL")
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
    elseif haskey(ENV, "VSCODE_PROXY_URI")
        # If VSCode is proxying ports, default to using that, so that we can
        # work even in environments where we're using `code-server`, and we
        # may not have any port available other than https.
        return port -> replace(ENV["VSCODE_PROXY_URI"], "{{port}}" => port)
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
            proxy_url=nothing,
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

    * proxy_url=nothing
        The url from which the server is reachable.
        If served on "127.0.0.1", this will default to http://localhost:forwarded_port
        if listen_url is "0.0.0.0", this will default to http://\$(Sockets.getipaddr()):forwarded_port
        so that the server is reachable inside the local network.
        If the server should be reachable from some external dns server,
        this needs to be set here.
"""
function configure_server!(;
        listen_url=nothing,
        listen_port::Integer=SERVER_CONFIGURATION.listen_port[],
        forwarded_port::Integer=listen_port,
        proxy_url=nothing,
    )

    if isnothing(listen_url)
        if !isnothing(proxy_url)
            # if we serve to an external url, server must listen to 0.0.0.0
            listen_url = "0.0.0.0"
        else
            listen_url = SERVER_CONFIGURATION.listen_url[]
        end
    end

    if isnothing(proxy_url)
        if listen_url == "0.0.0.0"
            proxy_url = string(Sockets.getipaddr(), ":$forwarded_port")
        elseif listen_url in ("127.0.0.1", "localhost")
            proxy_url = "http://localhost:$forwarded_port"
        else
            error("Trying to listen to $(listen_url), while only \"127.0.0.1\", \"0.0.0.0\" and \"localhost\" are supported")
        end
    end
    # set the config!
    SERVER_CONFIGURATION.listen_url[] = listen_url
    SERVER_CONFIGURATION.proxy_url[] = proxy_url
    SERVER_CONFIGURATION.listen_port[] = listen_port
    return
end



function singleton_server(;
    listen_url = "127.0.0.1",
    listen_port=SERVER_CONFIGURATION.listen_port[],
    verbose=SERVER_CONFIGURATION.verbose[],
    proxy_url=SERVER_CONFIGURATION.proxy_url[])

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
    GLOBAL_SERVER[].proxy_url = proxy_url
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
