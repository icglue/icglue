# general
- add documentation
  - doxygen for lib?
  - man-pages for tcl-commands?
- makefile
  - add install target?

# lib
- regfile support
  - add get\_regfile -name (without -of option) possibility
- add cleanup function to reset library (with proper freeing of db...)
- add net/signal data type to retrieve signals?

# tcllib
- "-help"-switches for main commands

# bin
- improve binary
  - command line arguments (e.g. icglue -t \<template\> (-f \<construct.tcl\>|-sng \<file.icsng\>))
  - environment variables for template path

# templates
- integrate regfile into default template
