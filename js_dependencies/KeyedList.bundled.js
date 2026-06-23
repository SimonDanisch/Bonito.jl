// dev/Bonito/js_dependencies/KeyedList.js
var KeyedList = class {
  #container;
  #byKey = /* @__PURE__ */ new Map();
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
    window.Bonito.Sessions.move_dom_node(node, this.#container, before);
  }
  #applyBatch(batch) {
    if (!Array.isArray(batch)) return;
    for (const op of batch) {
      if (!op || !op.type) continue;
      switch (op.type) {
        case "remove":
          this.removeItem(op.key);
          break;
        case "move":
          this.moveItem(op.key, op.after_key);
          break;
      }
    }
  }
  keys() {
    return [...this.#byKey.keys()];
  }
  size() {
    return this.#byKey.size;
  }
};
function attach(container, opsObs) {
  const stub = container.bonitoKeyedList;
  const pending = stub && Array.isArray(stub.pending) ? stub.pending : [];
  const kl = new KeyedList(container, opsObs);
  container.bonitoKeyedList = kl;
  for (const op of pending) {
    kl.insertItem(op.key, op.after_key, op.elem);
  }
  return kl;
}
export {
  attach
};
