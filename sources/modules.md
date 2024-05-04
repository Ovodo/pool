# Module
A Module is the base unit of code organization in Move. Modules are used to group and isolate code, and all of the members of the module are private to the module by default.

## Module declaration
Modules are declared using the **module** keyword followed by the package address, module name and the module body inside the curly braces **{}**. The module name should be in snake_case - all lowercase letters with underscores between words. Modules names must be unique in the package.

Usually, a single file in the **sources/** */ folder contains a single module. The file name should match the module name - for example, a **donut_shop** module should be stored in the **donut_shop.move** file. You can read more about coding conventions in the [Coding Conventions](https://move-book.com/special-topics/coding-conventions.html) section.

Structs, functions, constants and imports all part of the module:

* Structs
* Functions
* Constants
* Imports
* Struct Methods

## Module Members
Module members are declared inside the module body. To illustrate that, let's define a simple module with a struct, a function and a constant:

```move
module book::my_module_with_members {
    // import
    use book::my_module;

    // a constant
    const CONST: u8 = 0;

    // a struct
    public struct Struct {}

    // function
    fun function(_: &Struct) { /* function body */ }
}
 ```