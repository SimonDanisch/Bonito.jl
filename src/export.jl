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

to_watch(x) = observe(x)

# Implement interface for slider!
is_widget(::Slider) = true
value_range(slider::Slider) = 1:length(slider.values[])
to_watch(slider::Slider) = slider.index

# Implement interface for Dropdown

is_widget(::Dropdown) = true
value_range(d::Dropdown) = 1:length(d.options[])
to_watch(d::Dropdown) = d.option_index

is_widget(::Checkbox) = true
value_range(::Checkbox) = [true, false]
to_watch(d::Checkbox) = d.value

function do_session(f, session)
    s = session
    while s.parent != nothing
        f(s)
        s = s.parent
    end
    f(s)
    # if we're recording for a subsession, we need to apply the operations to both sessions
    for (id, c) in session.children
        f(c)
    end
end

struct IgnoreObsUpdates2 <: Function
    widget_ids::Set{String}
end

function (ignore::IgnoreObsUpdates2)(msg)
    if msg[:msg_type] == UpdateObservable
        # Ignore all messages that directly update the observable we watch
        # because otherwise, that will trigger itself recursively, once those messages are applied
        # via `$(wid).on(x=> ....)`
        msg[:id] in ignore.widget_ids && return true
    end
    return false
end

function record_values(f, session, widget_ids)
    ignore = IgnoreObsUpdates2(widget_ids)
    do_session(session) do s
        s.ignore_message[] = ignore
        empty!(s.message_queue)
    end
    try
        f()
        messages = SerializedMessage[]
        do_session(session) do s
            append!(messages, s.message_queue)
        end
        return messages
    catch e
        Base.showerror(stderr, e)
    finally
        do_session(session) do s
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

"""
    record_states(session::Session, dom::Hyperscript.Node)

Records the states of all widgets in the dom.
Any widget that implements the following interface will be found in the DOM and can be recorded:

```julia
# Implementing interface for JSServe.Slider!
is_widget(::Slider) = true
value_range(slider::Slider) = 1:length(slider.values[])
to_watch(slider::Slider) = slider.index # the observable that will trigger JS state change
```

!!! warn
    This is experimental and might change in the future!
    It can also create really large HTML files, since it needs to record all combinations of widget states.
    It's also not well optimized yet and may create a lot of duplicated messages.
"""
function record_states(session::Session, dom::Hyperscript.Node)
    widgets = extract_widgets(dom)
    rendered = jsrender(session, dom)
    # We'll mess with the message_queue to record the statemap
    # So we copy the current message queue and disconnect the session!
    # we need to serialize the message so that all observables etc are registered
    # TODO, this is a bit of a bad design, since we mixed serialization with session resource registration
    # Which makes sense in most parts, but breaks together, e.g. here
    session_states = Dict{String, SerializedMessage}()
    do_session(session) do s
        session_states[s.id] = SerializedMessage(s, fused_messages!(s))
    end
    all_states = Iterators.product(value_range.(widgets)...)
    statemap = Dict{String, Vector{SerializedMessage}}()
    widget_observables = to_watch.(widgets)
    widget_id_set = Set([obs.id for obs in widget_observables])
    while_disconnected(session) do
        for state_array in all_states
            key = join(state_array, ",") # js joins all elements in an array as a dict key -.-
            # TODO, somehow we must set + reset the observables before recording...
            # Makes sense, to bring them to the correct state first, but we should be able to do this more efficiently
            for (state, obs) in zip(state_array, widget_observables)
                obs[] = state
            end
            statemap[key] = record_values(session, widget_id_set) do
                foreach(notify, widget_observables)
            end
        end
    end

    do_session(session) do s
        if haskey(session_states, s.id)
            push!(s.message_queue, session_states[s.id])
        end
    end
    asset = BinaryAsset(session, widget_observables)
    statemap_script = js"""
    $(asset).then(binary => {
        const statemap = $(statemap)
        console.log(statemap)
        const observables = JSServe.decode_binary(binary, $(session.compression_enabled));
        JSServe.onany(observables, (states) => {
            console.log(states)
            // messages to send for this state of that observable
            const messages = statemap[states]
            // not all states trigger events
            // so some states won't have any messages recorded
            if (messages){
                messages.forEach(JSServe.process_message)
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
    error("export_standalone is deprecated, please use export_static")
end

"""
    export_static(html_file::Union{IO, String}, app::App)
    export_static(folder::String, routes::Routes)

Exports the app defined by `app` with all its assets a single HTML file.
Or exports all routes defined by `routes` to `folder`.
"""
function export_static(html_file::String, app::App;
        asset_server=NoServer(),
        connection=NoConnection(),
        session=Session(connection; asset_server=asset_server))
    open(html_file, "w") do io
        export_static(io, app; session=session)
    end
end

function export_static(html_io::IO, app::App;
        asset_server=NoServer(),
        connection=NoConnection(),
        session=Session(connection; asset_server=asset_server))

    session.title = app.title
    page_html(html_io, session, app)
    return session
end

function export_static(folder::String, routes::Routes; connection=NoConnection(), asset_server= AssetFolder(folder, ""))
    isdir(folder) || mkpath(folder)
    for (route, app) in routes.routes
        startswith(route, "/") && (route = route[2:end])
        dir = joinpath(folder, route)
        html_file = normpath(joinpath(dir, "index.html"))
        isdir(dirname(html_file)) || mkpath(dirname(html_file))
        asset_server.current_dir = dir
        export_static(html_file, app; session=Session(connection; asset_server=asset_server))
    end
end
