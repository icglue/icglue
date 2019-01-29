# ICGlue is a Tcl-Library for scripted HDL generation

ICGlue is a C/Tcl based library and tool for scripted generation of hardware description.
The focus here is on simplifying to create module hierarchy, connectivity and configuration via register-files.
Created output contains modules in a hardware description language (currently only systemverilog/verilog) and register-file documentation.

## Features
Current features are:
- Read in a user-defined Tcl construction script to describe hierarchy, connectivity and config registers.
- Run some sanity checks.
- Write out code/documentation defined by customizable Tcl-based templates.

Planned features: see [todo-list](TODOS.md).

## Documentation
For an overview see [icglue](doxy/icglue.md).
For library documentation build the doxygen documentation by running
```shell
make docs
```
and browse it in firefox by running
```shell
make showdocs
```

## Dependencies
### Main
- glib2
- tcl8.6

### Optional
- nagelfar (for Tcl syntax checks)
- doxygen (for source code documentation)

### Build
- gcc
- make
- pkg-config (with configs for glib2 and Tcl - otherwise you need to patch `lib/Makefile`)

## Build
Run
```shell
make
```
to build core library and Tcl package.
Run
```shell
make everything
```
to build doxygen-Documentation (needs doxygen) and nagelfar syntaxfiles as well (needs nagelfar installed).

## Install
Run e.g.
```shell
DESTDIR=/opt/icglue make install
```
to install to /opt/icglue.

## Developers
See [developers](AUTHORS.md).

## Licensing
GNU GPLv3 (see [license](LICENSE.md)).

## Acknowledgement
After the initial phase, most of the work for ICGlue was done at the Chair of Highly-Parallel VLSI Systems and Neuro-Microelectronics (HPSN) at TU Dresden
(see [HPSN](https://tu-dresden.de/ing/elektrotechnik/iee/hpsn "Chair of Highly-Parallel VLSI Systems and Neuro-Microelectronics")).
It is inspired by its predecessor icsng developed by Jens-Uwe Schlüssler.
