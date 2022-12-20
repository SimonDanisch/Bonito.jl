import Observables: observe

is_independant(x) = true
is_widget(x) = false
function value_range end
function update_value!(x, value) end

function extract_widgets(dom_root)
    result = Base.IdSet()
    walk_dom(dom_root) do x
        is_widget(x) && push!(result, x)
    end
    return result
end

struct Dependant <: WidgetsBase.AbstractWidget{Any}
    value
end
# Implement interface for dependant
jsrender(session::Session, x::Dependant) = jsrender(session, x.value)
is_independant(x::Dependant) = false
is_widget(::Dependant) = true
value_range(x::Dependant) = value_range(x.value)
update_value!(x::Dependant, value) = update_value!(x.value, value)

# Implement interface for slider!
is_widget(::Slider) = true
value_range(slider::Slider) = 1:length(slider.range[])
update_value!(slider::Slider, idx) = (slider[] = slider.range[][idx])
to_watch(slider::Slider) = slider.attributes[:index_observable].id
to_watch(x) = observe(x).id

# Implement interface for Dropdown

is_widget(::Dropdown) = true
value_range(d::Dropdown) = 1:length(d.options[])
update_value!(d::Dropdown, value) = (d.option_index[] = value)
to_watch(d::Dropdown) = d.option_index.id

function record_values(f, session, widget)
    wid = to_watch(widget)
    root = root_session(session)
    function ignore_message(msg)
        if msg[:msg_type] == UpdateObservable
            # Ignore all messages that directly update the observable we watch
            # because otherwise, that will trigger itself recursively, once those messages are applied
            # via `$(wid).on(x=> ....)`
            msg[:id] == wid && return true
        end
        return false
    end
    function do_session(f)
        # if we're recording for a subsession, we need to apply the operations to both sessions
        session !== root && f(root)
        f(session)
    end

    do_session() do s
        s.ignore_message[] = ignore_message
    end

    try
        f()
        messages = SerializedMessage[]
        do_session() do s
            append!(messages, s.message_queue)
        end
        return Dict("msg_type" => FusedMessage, "payload" => messages)
    catch e
        Base.showerror(stderr, e)
    finally
        do_session() do s
            s.ignore_message[] = (msg)-> false
            empty!(s.message_queue) # remove all recorded messages
        end
    end
end

function while_disconnected(f, session::Session)
    if isopen(session)
        error("Session shouldn't be open")
    end
    f()
end

function record_states(session::Session, dom::Hyperscript.Node)
    widgets = extract_widgets(dom)
    rendered = jsrender(session, dom)
    # We'll mess with the message_queue to record the statemap
    # So we copy the current message queue and disconnect the session!
    # we need to serialize the message so that all observables etc are registered
    # TODO, this is a bit of a bad design, since we mixed serialization with session resource registration
    # Which makes sense in most parts, but breaks together, e.g. here
    msg_serialized = SerializedMessage(session, fused_messages!(session))
    independent = filter(is_independant, widgets)

    independent_states = Dict{String, Any}()
    while_disconnected(session) do
        for widget in independent
            state = Dict{Any, Dict{String, Any}}()
            for value in value_range(widget)
                state[value] = record_values(session, widget) do
                    update_value!(widget, value)
                end
            end
            independent_states[to_watch(widget)] = state
        end
    end

    push!(session.message_queue, msg_serialized)
    observable_ids = to_watch.(independent)

    statemap_script = js"""
        const statemap = $(independent_states)
        const observables = $(observable_ids)
        observables.forEach(id => {
            JSServe.lookup_global_object(id).on((val) => {
                // messages to send for this state of that observable
                const messages = statemap[id][val]
                // not all states trigger events
                // so some states won't have any messages recorded
                if (messages){
                    JSServe.process_message(messages)
                }
            })
        })
    """
    evaljs(session, statemap_script)
    return rendered
end

"""
    export_standaloneexport_standalone(
        app::App, folder::String;
        clear_folder=false, write_index_html=true,
        absolute_urls=false, content_delivery_url="file://" * folder * "/",
        single_html=false)

Exports the app defined by `app::Application` with all its assets to `folder`.
Will write the main html out into `folder/index.html`.
Overwrites all existing files!
If this gets served behind a proxy, set `absolute_urls=true` and
set `content_delivery_url` to your proxy url.
If `clear_folder=true` all files in `folder` will get deleted before exporting again!
`single_html=true` will write out a single html instead of writing out JS depencies as separate files.
"""
function export_standalone(app::App, folder::String;
        clear_folder=false, write_index_html=true,
        absolute_urls=false, content_delivery_url="file://" * folder * "/",
        single_html=false
    )
    if clear_folder
        for file in readdir(folder)
            rm(joinpath(folder, file), force=true, recursive=true)
        end
    end
    serializer = UrlSerializer(false, folder, absolute_urls, content_delivery_url, single_html)
    # set id to "", since we dont needed, and like this we get nicer file names
    session = Session(url_serializer=serializer)
    html_str = sprint() do io
        show(io, MIME"text/html"(), Page(offline=true, exportable=true, session=session))
        show(io, MIME"text/html"(), app)
    end
    if write_index_html
        open(joinpath(folder, "index.html"), "w") do io
            println(io, html_str)
        end
        return html_str, session
    else
        return html_str, session
    end
end

function export_static(folder::String, app::App)
    routes = Routes()
    routes["/"] = app
    export_static(folder, routes)
end

function export_static(folder::String, routes::Routes)
    isdir(folder) || mkpath(folder)
    asset_server = NoServer()
    connection = JSServe.NoConnection()
    session = Session(connection; asset_server=asset_server)
    for (route, app) in routes.routes
        if route == "/"
            route = "index"
        end
        html_file = normpath(joinpath(folder, route) * ".html")
        isdir(dirname(html_file)) || mkpath(dirname(html_file))
        open(html_file, "w") do io
            page_html(io, session, app)
        end
    end
end
