function iframe_html(server::Server, session::Session, route::String)
    # Display the route we just added in an iframe inline:
    url = online_url(server, route)
    remote_origin = online_url(server, "")
    style = "position: relative; display: block; width: 100%; height: 100%; padding: 0; overflow: hidden; border: none"
    style = "position: relative; display: block; width: 100%; height: 100%; padding: 0; overflow: hidden; border: none"
    return DOM.div(
        js"""
            function register_resize_handler(remote_origin) {
                function resize_callback(event) {
                    if (event.origin !== remote_origin) {
                        return;
                    }
                    const uuid = event.data[0];
                    const width = event.data[1];
                    const height = event.data[2];
                    const iframe = document.getElementById($(session.id));
                    if (iframe) {
                        iframe.style.width = width + "px";
                        iframe.style.height = height + "px";
                    }
                }
                if (window.addEventListener) {
                    window.addEventListener("message", resize_callback, false);
                } else if (window.attachEvent) {
                    window.attachEvent("onmessage", resize_callback);
                }
            }
            register_resize_handler($(remote_origin))
        """,
        DOM.iframe(src=url, id=session.id, style=style, scrolling="no")
    )
end

function show_in_iframe(server, session, app)
    session_route = "/$(session.id)"
    # Our default is to display the app in an IFrame, which is a bit complicated
    # we need to resize the iframe based on its content, which is a bit complicated
    # because we can't directly access it. So we sent a message here
    # to the parent iframe, for which we register an
    # event handler via resize_iframe_parent, which then
    # resizes the parent iframe accordingly
    app_wrapped = App() do session::Session, request
        on_document_load(session, js"JSServe.resize_iframe_parent($(session.id))")
        return Base.invokelatest(app.handler, session, request)
    end
    route!(server, session_route => app_wrapped)
    return jsrender(session, iframe_html(server, session, session_route))
end
