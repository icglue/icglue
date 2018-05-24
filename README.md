# ICGlue is a Tcl-Library for scripted HDL generation

Currently in alpha test phase.
Planned features: see [todo-list](TODOS.md).

## Dependencies
### Main
- glib2
- tcl8.6

### Optional
- nagelfar (for Tcl syntax checks)
- doxygen (for Documentation)

### Build
- gcc
- make
- pkg-config (with configs for glib2 and tcl - otherwise you need to patch `lib/Makefile`)

### Build dependencies

## Build
Run
```shell
make
```
to build core library and tcl package.
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
see [developers](AUTHORS.md).

## Licensing
GNU GPLv3 (see [license](LICENSE.md)).
