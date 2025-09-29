// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

var shared_global = 2;
function get_global() {
    return shared_global;
}
function set_global(val) {
    shared_global = val;
}
export { get_global as get_global };
export { set_global as set_global };

