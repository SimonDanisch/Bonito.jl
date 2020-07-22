
function extract_inputs(dom_root)
    result = []
    JSServe.walk_dom(dom_root) do x
        if x isa Slider
            push!(result, x)
        end
    end
    return result
end

global last_state_map



function record_state_map(session::Session, handler)
    global last_state_map
    dom = handler(session, nothing)
    rendered = JSServe.jsrender(session, dom)
    sliders = extract_inputs(dom)
    state = Dict{Any, Dict{Symbol,Any}}()

    window = JSObject(session, :window)
    evaljs(session, js"put_on_heap($(uuidstr(window)), window); undefined;")
    window.dont_even_try_to_reconnect = true
    session.fusing[] = true
    msgs = copy(session.message_queue)
    for slider in sliders
        for i in slider.range[]
            try
                slider.value[] = i
                yield()
                messages = filter(session.message_queue) do msg
                    # filter out the event that triggers updating the obs
                    # we actually update on js already
                    !(msg[:msg_type] == JSServe.UpdateObservable &&
                        msg[:id] == slider.value.id)
                end
                state[i] = Dict(:msg_type => FusedMessage, :payload => messages)
            catch e
                Base.showerror(stderr, e)
            finally
                empty!(session.message_queue)
            end
        end
    end
    session.fusing[] = false
    append!(session.message_queue, msgs)
    window.offline_state = DontDeSerialize(state)
    for slider in sliders
        JSServe.onjs(session, slider.value, js"""function (val){
            const smap = window.offline_state
            process_message(smap[val])
        }""")
    end
    last_state_map = state
    return rendered
end
