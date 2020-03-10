const JSModule = (function () {
  var shared_global = 2;

  function get_global(){
    return shared_global;
  }

  function set_global(val){
    shared_global = val;
  }

  return {
    get_global: get_global,
    set_global: set_global
  }
})();
