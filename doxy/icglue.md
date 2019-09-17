# ICGlue overview

ICGlue consists of:
- icglue script for invocation by users.
- icsng2icglue script for backwards compatibility to icsng (HPSN internal tool which inspired ICGlue).
- icglue library encapsulating the core functionality.
- A template-set for HDL and documentation output.
- icprep binary for template based tool setups.

## icglue Binary
The main tool for the user.
It reads in a custom user-defined construction Tcl-script (see [construct](construct.md))
and writes out the generated files in multiple files as defined by the templates.

For help on tool invocation run
```shell
icglue --help
```
or
```shell
man icglue
```
in case you have the ICGlue manpage in your man path.

## icsng2icglue Conversion
Backwards compatibility tool.
It reads in an icsng-file and writes out a compatible ICGlue script and converts the icsng-generated verilog-files for ICGlue.
Not all features if icsng are supported.

For help on tool invocation run
```shell
icsng2icglue --help
```
or
```shell
man icsng2icglue
```

## icglue Library
The core library consists of:
- The backend database library, the only part written in c, under *lib*. It stores all generated data as objects and is responsible for connecting hierarchical signals and parametrization.
- The construction frontend. It is used to read in the user-script and execute the database commands to create modules, registers and so on.
- The sng frontend. It is used to be able to also read in an icsng-file and execute the appropriate database commands.
- A set of sanity-checkers. They are invoked after the user-script is read in and can warn about inconsistencies (e.g. different pin-names on different instances of the same resource module).
- The template output-stage. It preprocesses the database content, parses the templates and invokes them to output everything in the specified files.
- Some additional helpers functions.

For more details have a look into the source code or the generated doxygen documentation.

## Templates
Templates are a combination of an init Tcl-script for template setup and a set of template-files within one template directory.
For details have a look at [templates](templates.md).

## icprep Binary
An additional binary using the ICGlue template engines for providing tool setups.
It is also used for simulation setup in icglue tests.
For a short introduction see [ICPrep](icprep.md).
