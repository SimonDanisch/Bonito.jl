var shared_global = 2;

export function get_global(){
  return shared_global;
}

export function set_global(val){
  shared_global = val;
}
