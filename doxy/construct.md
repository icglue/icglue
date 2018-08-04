# ICGlue construction scripts

## File
An ICGlue construction script is a Tcl script run in an encapsulating namespace by ICGlue.
Besides all Tcl commands, ICGlue commands for hierarchy, codesection and regfile generation are provided.

## Module hierarchy
For creating the module hierarchy the command `M` is provided.
It creates a unit/module hierarchy.

### Example
```tcl
M -unit "abc" -tree {
    tb_abc .................. (tb)
    |
    +-- abc ................. (rtl,ilm)
    |   |
    |   +-- res1<inst1..4> .. (res)
    |   +-- res2<a,b> ....... (res)
    |
    +-- verifip<tb> ......... (res)
}
```

The example will create a unit `abc` with a testbench (`tb`) `tb_abc`,
an rtl module `abc` and an instance of a non-generated resource (`res`)
`verifip` with instance identifier `tb`.
The Module `abc` will contain multiple instances of two other non-generated
resources `res1` (instance identifiers `inst1`, ..., `inst4`) and `res2`
(instance identifiers `a` and `b`).

### Design unit
The design unit for the generated hierarchy can be specified via the `-unit` switch.
Alternatively sub hierarchies can be part of a different unit by specifying `unit=<unitname>`
in the modules properties in parentheses at the end of the module's specification line.

### Hierarchy tree
The hierarchy is specified as a tree block after the `-tree` argument.
Variables and Tcl commands in brackets will be evaluated inside the specified tree.
Hierarchy is defined by indentation of the modules and instances.
It is possible (and looks nice) to draw a tree-like structure, but this structure
is not parsed -- any non-alphabetic characters are just parsed as indentation.

Modules that are not resources will be generated and can only be instantiated once.
The reason is that there is no way to distinguish their sub-instances when creating
signals.
Every instance can have an instance identifier in `<` and `>` delimiters.
Resource instances can have multiple instances specified by separating their
identifiers by commas or alternatively using `..` for a range of numeric identifiers (see example above).

### Module properties
A module can have comma-separated properties set in parentheses at the end of its specification line.
Dot and space characters before the parentheses are ignored and can be used to improve readability.
Properties specify a view, a hardware description language or additional properties.

Views:
* `tb` (testbench)
* `rtl` (rtl description = default)
* `beh` (behavioral description)

Hardware description languages:
* `v` (verilog = default)
* `sv` (systemverilog)
* `vhdl` (vhdl)

Additional properties
* `res` (module is a resource -- resources are assumed to exist,
  will not be generated and are allowed to be instantiated multiple times)
* `ilm` (module is an ILM module -- it will become a place & route macro
  and parameters are not fed through to its instance as this is impossible for macros)
* `inc` (instance of a module specified before, e.g. in an individual hierarchy tree)
* `unit=<unitname>` (to specify an individual unit for a hierarchy tree branch)
* `rf=<rf-name>` (module contains a register file, a name can be specified)
* `rfattr=<attr>=<value>` (additional attribute set for the regfile in a module;
  regfile will have an attribute `<attr>` set to value `<value>`)

### Alternative module/instance specification
Alternatively it is possible to specify individual modules in the form:
```
M [-tb|-rtl|-beh] [-v|-sv|-vhdl] [-ilm] [-res] [-u <unit>] <module-name> [-i <instance-list>]
```

In this case instantiated modules  must already be defined.
Instance identifiers are similar to those in the hierarchy tree.
The flags are similar to the module properties in the hierarchy tree.
