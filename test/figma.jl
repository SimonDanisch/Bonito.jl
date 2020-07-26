using JSServe
using JSServe.HTTP
using JSServe.JSON3
using JSServe: find_by_attributes
using JSServe.DOM

devToken = ENV["FIGMA_DEV_TOKEN"]
headers = ["X-Figma-Token" => devToken]
file_key = "sTY4qZ7BVlYyFAZCbuGU22"
baseUrl = "https://api.figma.com"
resp = HTTP.get("$(baseUrl)/v1/files/$(file_key)?geometry=paths", headers)
raw_json_str = String(copy(resp.body))
data = JSON3.read(raw_json_str);
BASIC = data.document.children[1].children[1]

figma_layout = JSServe.Asset(JSServe.dependency_path("figma_layout.css"))

function handler(s, r)
    css = JSServe.extract_styles()
    return DOM.div(figma_layout, css, JSServe.to_html(nothing, BASIC))
end

app = JSServe.Application(handler, "0.0.0.0", 8081)
