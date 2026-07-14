// Browser-side manager for Bonito's KeyedList primitive. Two input
// channels from Julia: dom_in_js-shipped widget subtrees (each ends up
// in insertItem) and an ops_obs carrying remove/move records.

class KeyedList {
    #container;
    #byKey = new Map();

    constructor(container, opsObs) {
        this.#container = container;
        opsObs.on((batch) => this.#applyBatch(batch));
    }

    insertItem(key, after_key, elem) {
        if (!elem) return;
        const ref = after_key != null ? this.#byKey.get(after_key) : null;
        const before = ref ? ref.nextSibling : this.#container.firstChild;
        this.#container.insertBefore(elem, before);
        this.#byKey.set(key, elem);
    }

    removeItem(key) {
        const node = this.#byKey.get(key);
        if (!node) return;
        node.remove();
        this.#byKey.delete(key);
    }

    moveItem(key, after_key) {
        const node = this.#byKey.get(key);
        if (!node) return;
        const ref = after_key != null ? this.#byKey.get(after_key) : null;
        const before = ref ? ref.nextSibling : this.#container.firstChild;
        // Atomic reorder; falls back to a subsession-status defer that
        // keeps the cleanup observer from tearing down the moving subtree.
        window.Bonito.Sessions.move_dom_node(node, this.#container, before);
    }

    #applyBatch(batch) {
        if (!Array.isArray(batch)) return;
        // Removes first so they free keys before any in-batch reinsertion.
        // Inserts already landed as separate dom_in_js messages.
        for (const op of batch) {
            if (!op || !op.type) continue;
            switch (op.type) {
                case 'remove': this.removeItem(op.key); break;
                case 'move':   this.moveItem(op.key, op.after_key); break;
            }
        }
    }

    keys() { return [...this.#byKey.keys()]; }
    size() { return this.#byKey.size; }
}

// Replace the inline pre-init stub with a real KeyedList and replay any
// inserts that landed while this module was still importing.
export function attach(container, opsObs) {
    const stub = container.bonitoKeyedList;
    const pending = (stub && Array.isArray(stub.pending)) ? stub.pending : [];
    const kl = new KeyedList(container, opsObs);
    container.bonitoKeyedList = kl;
    for (const op of pending) {
        kl.insertItem(op.key, op.after_key, op.elem);
    }
    return kl;
}
