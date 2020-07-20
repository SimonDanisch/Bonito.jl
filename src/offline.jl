
function extract_inputs(dom_root)
    result = []
    JSServe.walk_dom(dom_root) do x
        if x isa Slider
            push!(result, x)
        end
    end
    return result
end

function record_state_map(session::Session, handler)
    dom = test_handler(session, nothing)
    rendered = JSServe.jsrender(session, dom)
    sliders = extract_inputs(dom)
    global state = Dict{Any, Vector{Dict{Symbol,Any}}}()
    session.fusing[] = true
    msgs = copy(session.message_queue)
    for slider in sliders
        for i in slider.range[]
            slider.value[] = i
            yield()
            state[base64encode(JSServe.MsgPack.pack(i))] = filter(session.message_queue) do msg
                # filter out the event that triggers updating the obs
                # we actually update on js already
                msg[:msg_type] == JSServe.UpdateObservable &&
                    msg[:id] != slider.value.id
            end
            empty!(session.message_queue)
        end
    end
    session.fusing[] = false
    append!(session.message_queue, msgs)
    JSServe.evaljs(session, js"window.dont_even_try_to_reconnect = true")
    for slider in sliders
        JSServe.onjs(session, slider.value, js"""function (val){
            const smap = $(state)
            const key =  msgpack.encode(val);
            const key_str = btoa(String.fromCharCode.apply(null, key))
            const messages = smap[key_str]
            for(const mg in messages){
                process_message(messages[mg]);
            }
        }""")
    end
    return rendered
end
