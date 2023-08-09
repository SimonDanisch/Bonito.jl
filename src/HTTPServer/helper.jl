function html(body)
    return HTTP.Response(200, ["Content-Type" => "text/html", "charset" => "utf-8"], body=body)
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
