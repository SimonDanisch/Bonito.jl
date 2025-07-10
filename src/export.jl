import Observables: observe

is_independant(x) = true
is_widget(x) = false
needs_post_notify(x) = false
function post_notify_callback end
function value_range end
function update_value!(x, value) end

function extract_widgets(dom_root)
    result = Base.IdSet()
    post_notify = Base.IdSet()
    walk_dom(dom_root) do x
        is_widget(x) && push!(result, x)
        needs_post_notify(x) && push!(post_notify, x)
    end
    return collect(result), collect(post_notify)
end

to_watch(x) = observe(x)

# Implement interface for slider!
is_widget(::Slider) = true
value_range(slider::Slider) = slider.values[]
to_watch(slider::Slider) = slider.value

# Implement interface for Dropdown

is_widget(::Dropdown) = true
value_range(d::Dropdown) = 1:length(d.options[])
to_watch(d::Dropdown) = d.option_index

is_widget(::Checkbox) = true
value_range(::Checkbox) = [true, false]
to_watch(d::Checkbox) = d.value

function do_session(f, session)
    s = session
    while !isnothing(s.parent)
        f(s)
        s = s.parent
    end
    f(s)
    # if we're recording for a subsession, we need to apply the operations to both sessions
    for (id, c) in session.children
        f(c)
    end
end

struct IgnoreObsUpdates <: Function
    widget_ids::Set{String}
end

function (ignore::IgnoreObsUpdates)(msg)
    if msg[:msg_type] == UpdateObservable
        # Ignore all messages that directly update the observable we watch
        # because otherwise, that will trigger itself recursively, once those messages are applied
        # via `$(wid).on(x=> ....)`
        msg[:id] in ignore.widget_ids && return true
    end
    return false
end

function record_values(f, session, widget_ids)
    ignore = IgnoreObsUpdates(widget_ids)
    do_session(session) do s
        s.ignore_message[] = ignore
        empty!(s.message_queue)
    end
    try
        f()
        yield()
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
    generate_state_key(values)

Generate a consistent key for state values that works identically in Julia and JavaScript.
Handles Float64 values specially to ensure consistent string representation.
"""
function generate_state_key(v)
    if v isa AbstractFloat
        # Format floats to ensure consistency between Julia and JavaScript
        # Round to 6 significant digits and remove trailing zeros
        if isnan(v)
            return "NaN"
        elseif isinf(v)
            return v > 0 ? "Infinity" : "-Infinity"
        else
            # Format with up to 6 decimal places, removing trailing zeros
            formatted = string(round(v, digits=6))
            # Remove trailing zeros after decimal point
            if occursin(".", formatted)
                formatted = rstrip(rstrip(formatted, '0'), '.')
            end
            return formatted
        end
    else
        # For other types, use string representation
        return string(v)
    end
end

"""
    record_states(session::Session, dom::Hyperscript.Node)

Records the states of all widgets in the dom.
Any widget that implements the following interface will be found in the DOM and can be recorded:

```julia
# Implementing interface for Bonito.Slider!
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
    widgets, post_notify = extract_widgets(dom)
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

    # Record states for each widget independently
    widget_observables = to_watch.(widgets)
    post_notify_callbacks = post_notify_callback.(post_notify)
    widget_statemaps = Dict{String, Dict{String, Vector{SerializedMessage}}}()

    while_disconnected(session) do
        for (widget_idx, (widget, obs)) in enumerate(zip(widgets, widget_observables))
            widget_id = obs.id
            widget_statemap = Dict{String, Vector{SerializedMessage}}()
            widget_id_set = Set([widget_id])

            # Save current states of all widgets

            # Record each state for this widget
            for state in value_range(widget)
                # Set this widget to the state we want to record
                obs.val = state
                # Use generate_state_key for consistency with JavaScript
                key = generate_state_key([state])
                try
                    widget_statemap[key] = record_values(session, widget_id_set) do
                        notify(obs)
                        for f in post_notify_callbacks
                            f()
                        end
                    end
                catch e
                    @warn "Error while recording state $key for widget $widget_id" exception=(e, Base.catch_backtrace())
                    continue
                end
            end

            widget_statemaps[widget_id] = widget_statemap
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
        const widget_statemaps = $(widget_statemaps)
        console.log('Widget statemaps:', widget_statemaps)
        const observables = Bonito.decode_binary(binary, $(session.compression_enabled));

        // Create a map from observable to its index for easy lookup
        const obsToIndex = new Map();
        observables.forEach((obs, idx) => {
            obsToIndex.set(obs, idx);
        });

        // Function to replay all widget states
        function replayAllStates(currentStates) {
            const allMessages = [];

            // Collect messages for each widget's current state
            observables.forEach((obs, idx) => {
                const widgetId = obs.id;
                const widgetStatemap = widget_statemaps[widgetId];
                if (widgetStatemap) {
                    const state = currentStates[idx];
                    // Use Bonito.generate_state_key for consistency
                    const key = Bonito.generate_state_key([state]);
                    const messages = widgetStatemap[key];
                    if (messages) {
                        allMessages.push(...messages);
                    }
                }
            });

            // Process all messages
            allMessages.forEach(msg => Bonito.process_message(msg));
        }

        // Keep track of current states
        let currentStates = observables.map(obs => obs.value);

        // Set up individual listeners for each observable
        observables.forEach((obs, idx) => {
            obs.on(value => {
                // Update current state
                currentStates[idx] = value;
                console.log('Widget', obs.id, 'changed to', value, '- replaying all states:', currentStates);
                // Replay all widget states
                replayAllStates(currentStates);
            });
        });

        // Initial replay to set up the correct state
        replayAllStates(currentStates);
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
