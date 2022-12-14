function html(body)
    return HTTP.Response(200, ["Content-Type" => "text/html", "charset" => "utf-8"], body=body)
end

function response_404(body="Not Found")
    return HTTP.Response(404, ["Content-Type" => "text/html", "charset" => "utf-8"], body=body)
end
