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

function record_state_map(session::Session, handler::Function)
    return record_state_map(session, handler(session, nothing))
end

function record_state_map(session::Session, dom::Hyperscript.Node)
    rendered = JSServe.jsrender(session, dom)
    widgets = extract_widgets(dom)
    window = Observable(:window)
    evaljs(session, js"put_on_heap($(uuidstr(window)), window); undefined;")
    window.dont_even_try_to_reconnect = true
    session.fusing[] = true
    msgs = copy(session.message_queue)
    independent = filter(is_independant, widgets)
    dependent = filter((!)∘is_independant, widgets)
    dependent_states = Dict{Any, Dict{Symbol,Any}}()
    independent_states = Dict{String, Any}()
    if !isempty(dependent)
        dependent_observables = observe.(dependent)
        for dependent_state in Iterators.product(value_range.(dependent))
            dependent_states[dependent_state] = record_values(session, widget) do
                update_value!.(dependent, dependent_state)
            end
            JSServe.onjs(session, observe(widget), js"""function (val){
                const state = $(dependent_observables).map(JSServe.get_observable);

                const messages = window.dependent_states[state]
                // not all states trigger events!
                if (messages){
                    process_message(messages)
                }
            }""")
        end
    end

    for widget in independent
        state = Dict{Any, Dict{Symbol,Any}}()
        for value in value_range(widget)
            state[value] = record_values(session, widget) do
                update_value!(widget, value)
            end
        end
        independent_states[observe(widget).id] = state
    end

    session.fusing[] = false
    append!(session.message_queue, msgs)
    for widget in independent
        JSServe.onjs(session, observe(widget), js"""function (val){
            const messages = window.independent_states[$(observe(widget).id)][val]
            // not all states trigger events!
            if (messages){
                process_message(messages)
            }
        }""")
    end
    window.independent_states = DontDeSerialize(independent_states)
    window.dependent_states = DontDeSerialize(dependent_states)
    return (dom=rendered, independent_states=independent_states, dependent_states=dependent_states)
end

"""
export_standalone(dom_handler, folder::String;
        absolute_urls=false, content_delivery_url="file://" * folder * "/",
    )

Exports the app defined by `dom_handler` with all its assets to `folder`.
Will write the main html out into `folder/index.html`.
Overwrites all existing files!
If this gets served behind a proxy, set `absolute_urls=true` and
set `content_delivery_url` to your proxy url.
If `clear_folder=true` all files in `folder` will get deleted before exporting again!
"""
function export_standalone(dom_handler, folder::String;
        clear_folder=false, write_index_html=true,
        absolute_urls=false, content_delivery_url="file://" * folder * "/",
    )
    if clear_folder
        for file in readdir(folder)
            rm(joinpath(folder, file), force=true, recursive=true)
        end
    end
    serializer = UrlSerializer(false, folder, absolute_urls, content_delivery_url)
    # set id to "", since we dont needed, and like this we get nicer file names
    session = Session(url_serializer=serializer)
    html_dom = Base.invokelatest(dom_handler, session, (target="/",))
    html_str = dom2html(session, html_dom)
    if write_index_html
        open(joinpath(folder, "index.html"), "w") do io
            println(io, html_str)
        end
        return html_str, session
    else
        return html_str, session
    end
end
