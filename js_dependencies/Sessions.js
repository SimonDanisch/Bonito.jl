const session_dom_nodes = new Set();

export function register_sub_session(session_id) {
    session_dom_nodes.add(session_id);
}

export function track_deleted_sessions(delete_session) {
    const observer = new MutationObserver(function (mutations) {
        // observe the dom for deleted nodes,
        // and push all found removed session doms to the observable `delete_session`
        let removal_occured = false;
        const to_delete = new Set();
        mutations.forEach((mutation) => {
            mutation.removedNodes.forEach((x) => {
                if (x.id && session_dom_nodes.has(x.id)) {
                    to_delete.add(x.id);
                } else {
                    removal_occured = true;
                }
            });
        });
        // removal occured from elements not matching the id!
        if (removal_occured) {
            session_dom_nodes.forEach((id) => {
                if (!document.getElementById(id)) {
                    to_delete.add(id);
                }
            });
        }
        to_delete.forEach((id) => {
            session_dom_nodes.delete(id);
            update_obs(delete_session, id);
        });
    });

    observer.observe(document, {
        attributes: false,
        childList: true,
        characterData: false,
        subtree: true,
    });
}
