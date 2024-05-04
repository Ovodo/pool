# Print 
To print out a value in the move language, you can use the print method from the debug module in the move standard library (`std::debug::print`)

```move
module example::print_method {

\\ Import necessary dependencies
use std::debug

\\ Function to print value
fun print_val(value:u64){
debug::print(&value)
}

}```

This function above will print any value passed into the print_val function
