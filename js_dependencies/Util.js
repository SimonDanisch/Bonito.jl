
function resize_iframe_parent(session_id) {
    const body = document.body;
    const html = document.documentElement;
    const height = Math.max(
        body.scrollHeight,
        body.offsetHeight,
        html.clientHeight,
        html.scrollHeight,
        html.offsetHeight
    );
    const width = Math.max(
        body.scrollWidth,
        body.offsetWidth,
        html.clientWidth,
        html.scrollHeight,
        html.offsetWidth
    );
    if (parent.postMessage) {
        parent.postMessage([session_id, width, height], "*");
    }
}
