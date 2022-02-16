# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"
const RegisterObservable = "5"
const JSDoneLoading = "8"
const FusedMessage = "9"

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
