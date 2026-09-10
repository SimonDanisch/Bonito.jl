function html(body)
    return HTTP.Response(200, [
        "Content-Type" => "text/html",
        "charset" => "utf-8",
        # The session id and its object tree are baked into the HTML, so a
        # cached copy revives a fresh page against a dead session (blank DOM,
        # "double freeing session from Julia!"). This also opts out of the
        # bfcache, so back/forward and tab duplication get a fresh session.
        "Cache-Control" => "no-store",
    ], body=body)
end

function response_404(body="Not Found")
    return HTTP.Response(404, [
        "Content-Type" => "text/html",
        "charset" => "utf-8",
        # Avoids throwing lots of errors in the devtools console when
        # VSCode tries to load non-existent resources from the plots pane.
        "Access-Control-Allow-Origin" => "*",
    ], body=body)
end

function response_500(html)
    return HTTP.Response(500, [
        "Content-Type" => "text/html",
        "charset" => "utf-8",
        # Avoids throwing lots of errors in the devtools console when
        # VSCode tries to load non-existent resources from the plots pane.
        "Access-Control-Allow-Origin" => "*",
        ];
        body=html,
    )
end

# TODO, how to do this without pircay? THis happens inside HTTP, so we can't just use try & catch in our own code
# WIthout this overload, we'll get a `cant convert Exception to HTTP.Response` error, without seeing the error.
Base.convert(::Type{HTTP.Response}, s::Exception) = response_500(s)
