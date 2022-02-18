

function html(body)
    return HTTP.Response(200, ["Content-Type" => "text/html", "charset" => "utf-8"], body=body)
end

function response_404(body="Not Found")
    return HTTP.Response(404, ["Content-Type" => "text/html", "charset" => "utf-8"], body=body)
end

function replace_url(match_str)
    key_regex = r"(/assetserver/[a-z0-9]+-.*?):([\d]+):[\d]+"
    m = match(key_regex, match_str)
    key = m[1]
    path = assetserver_to_localfile(string(key))
    return path * ":" * m[2]
end

const ASSET_URL_REGEX = r"http://.*/assetserver/([a-z0-9]+-.*?):([\d]+):[\d]+"
