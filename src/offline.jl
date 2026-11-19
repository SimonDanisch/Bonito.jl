import Observables: observe

is_independant(x) = true
is_widget(x) = false
function value_range end
function update_value!(x, value) end

function extract_widgets(dom_root)
    result = []
    walk_dom(dom_root) do x
        if is_widget(x)
            push!(result, x)
        end
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
value_range(slider::Slider) = slider.range[]
update_value!(slider::Slider, value) = (slider.value[] = value)

function record_values(f, session, widget)
    empty!(session.message_queue)
    try
        f()
        messages = filter(session.message_queue) do msg
            # filter out the event that triggers updating the obs
            # we actually update on js already
            !(msg[:msg_type] == UpdateObservable &&
                msg[:id] == observe(widget).id)
        end
        return Dict(:msg_type => FusedMessage, :payload => messages)
    catch e
        Base.showerror(stderr, e)
    end
end

function while_disconnected(f, session::Session)
    connection = session.connection[]
    session.connection[] = nothing
    f()
    session.connection[] = connection
end


function record_states(session::Session, dom::Hyperscript.Node)
    widgets = extract_widgets(dom)
    rendered = jsrender(session, dom)
    # We'll mess with the message_queue to record the statemap
    # So we copy the current message queue and disconnect the session!

    msgs = copy(session.message_queue)
    empty!(session.message_queue)
    independent = filter(is_independant, widgets)
    independent_states = Dict{String, Any}()
    while_disconnected(session) do
        for widget in independent
            state = Dict{Any, Dict{Symbol,Any}}()
            for value in value_range(widget)
                state[value] = record_values(session, widget) do
                    update_value!(widget, value)
                end
            end
            independent_states[observe(widget).id] = state
        end
    end

    append!(session.message_queue, msgs)
    observable_ids = Observables.obsid.(observe.(independent))

    statemap_script = js"""
        const statemap = $(independent_states)
        const observables = $(observable_ids)
        observables.forEach(id => {
            console.log(id)
            JSServe.on_update(id, function (val) {
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
