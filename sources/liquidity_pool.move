module example::print_method {

//  Import necessary dependencies
use std::debug;

/* declare constants if necessary */
const EZeroValueNotAllowed:u64 = 1;


public fun print_val (value:u64){
    assert!(value > 0,EZeroValueNotAllowed);
    debug::print(&value)
}


#[test]
fun test_print(){
    print_val(0)
}

}