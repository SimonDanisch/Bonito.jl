"""
    get_init_html(html_b64:: String) -> JSCode

Returns JS script that adds head and body of `html_b64` to the document.
"""
function get_init_html(html_b64::String)::JSCode
    return js"""
            (() => {
                // Decode base64 to get clean html (interpolating with json3 or just js''' doesnt work...)
                const html = atob($(html_b64));

                const parser = new DOMParser();
                const doc = parser.parseFromString(html, "text/html");

                const newHead = doc.head;
                if (newHead) {
                    for (const node of Array.from(newHead.children)) {
                        if (node.tagName && node.tagName.toLowerCase() === "script") continue;

                        const already = Array.from(document.head.children)
                            .some(h => h.outerHTML === node.outerHTML);
                        if (!already) {
                            document.head.appendChild(node.cloneNode(true));
                        }
                    }

                    for (const scriptNode of Array.from(newHead.getElementsByTagName("script"))) {
                        const s = document.createElement("script");
                        for (const attr of scriptNode.attributes) {
                            s.setAttribute(attr.name, attr.value);
                        }
                        if (!s.src && scriptNode.textContent) {
                            s.textContent = scriptNode.textContent;
                        }
                        document.head.appendChild(s);
                    }
                }

                const newBody = doc.body;
                
                //append newbody to body
                while (newBody.firstChild) {
                    document.body.appendChild(newBody.firstChild);
                }
            })();
            """
end

"""
    index_html_inject_script(html_path::String) -> JSCode

Read html file in `html_path` and return the content base64 encoded.
"""
function index_html_inject_script(html_path::String)::JSCode
    html_content = read(html_path, String)
    html_b64 = base64encode(html_content)
    return get_init_html(html_b64)
end

"""
    add_observable_script!(
        observables::Dict{Symbol,Observable}, obs::Observable, key::Symbol
    ) -> JSCode

Returns JS script to add observable `obs` to `window.observables[key]`. 
Also adds `obs` to `observables`
"""
function add_observable_script!(
    observables::Dict{Symbol,Observable}, obs::Observable, key::Symbol
)::JSCode
    observables[key] = obs
    return js"""
        (() => {
            window.observables = window.observables || {};
            window.observables[$(key)] = $(observables[key]);
            console.log("Exposed observable: " + $(key));
        })();
        """
end

"""
    add_observables_script!(
        observables::Dict{Symbol,Observable}, obs_dict::Dict{Symbol,Observable}
    ) -> Vector{JSCode}

Returns JS scripts to add values of `obs_dict` to `window.observables[key]` with `key` being the corresponding key.
Also adds them to `observables`.
"""
function add_observables_script!(
    observables::Dict{Symbol,Observable}, obs_dict::Dict{Symbol,Observable}
)::Vector{JSCode}
    scripts::Vector{} = []
    for (key, obs) in obs_dict
        push!(scripts, add_observable_script!(observables, obs, key))
    end
    return scripts
end

"""
    move_plots_script(html_ids::Vector{Pair{String, String}}) -> JSCode

    - `html_ids::Vector{Pair{String, String}}`: <source_div_id, destination_div_id>

Return JS script to move WGLMakie plots from source_div_id to destination_div_id for all entries of `html_ids`.
"""
function move_plots_script(html_ids::Vector{Pair{String,String}})::JSCode
    destinations = [pair[1] for pair in html_ids]
    targets = [pair[2] for pair in html_ids]
    return js"""
                (() => {
                    const checkInterval = setInterval(() => {
                        const htmlPlots = $(targets).map(id => document.getElementById(id));
                        const bonitoPlots = $(destinations).map(id => document.getElementById(id));
                        
                        const allPlotsReady = bonitoPlots.every(plot => plot !== null) && 
                                              htmlPlots.every(plot => plot !== null);
                        
                        if (allPlotsReady) {
                            clearInterval(checkInterval);
                            
                            for (let i = 0; i < htmlPlots.length; i++) {
                                const htmlPlot = htmlPlots[i];
                                const bonitoPlot = bonitoPlots[i];
                                
                                if (htmlPlot && bonitoPlot) {
                                    while (bonitoPlot.firstChild) {
                                        htmlPlot.appendChild(bonitoPlot.firstChild);
                                    }
                                }
                            }

                            //update plots divs so they resize 
                            window.dispatchEvent(new Event('resize'));
                        }
                    }, 50);

                    // Fallback: clear interval after 5 seconds to prevent infinite checking
                    setTimeout(() => clearInterval(checkInterval), 5000);
                })();
                """
end

"""
    plot_to_html_script(
        figs::Vector, target_div_ids::Vector{String}
    ) -> Vector{Union{Hyperscript.Node{Hyperscript.HTMLSVG},JSCode}}

Returns JS script to place figures `figs` into the document at `target_div_ids`.
Creates a temporary placeholder for the plots and then moves them.
"""
function plot_to_html_script(
    fig_id_pairs::Vector{Pair{T,String}}
)::Vector{Union{Hyperscript.Node{Hyperscript.HTMLSVG},JSCode}} where {T}
    uuids = [string(uuid4()) for _ in fig_id_pairs]

    plot_containers = [
        DOM.div(f[1]; id=id, style=Styles(CSS("display" => "none"))) for
        (f, id) in zip(fig_id_pairs, uuids)
    ]

    move_script = move_plots_script(
        map(pair -> pair[1] => pair[2], zip(uuids, map(p -> p[2], fig_id_pairs)))
    )
    return [plot_containers..., move_script]
end