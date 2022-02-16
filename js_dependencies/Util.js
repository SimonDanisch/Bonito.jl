function update_dom_node(dom, html) {
    if (dom) {
        dom.innerHTML = html;
        return true;
    } else {
        //deregister the callback if the observable dom is gone
        return false;
    }
}

function update_node_attribute(node, attribute, value) {
    if (node) {
        if (node[attribute] != value) {
            node[attribute] = value;
        }
        return true;
    } else {
        return false; //deregister
    }
}

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
