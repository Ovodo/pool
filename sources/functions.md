# Print 
To print out a value in the move language, you can use the **print** method from the debug module in the move standard library (`std::debug`)


```move
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
    print_val(4)
}

}
```

This function above will print any value passed into the print_val function. Run `sui move test` to run the code