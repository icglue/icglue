# general
- add documentation
  - doxygen for lib?
  - man-pages for tcl-commands?

# lib
- regfile support
  - add get\_regfile -name (without -of option) possibility
- add cleanup function to reset library (with proper freeing of db...)
- add net/signal data type to retrieve signals?

# tcllib
- "-help"-switches for main commands
- templates:
  - possibility to write out more than one file per object (e.g. csv + systemc for regfile)
  - preprocessing for module data

# bin
- improve binary
  - command line arguments (e.g. icglue -t \<template\> (-f \<construct.tcl\>|-sng \<file.icsng\>))
  - environment variables for template path

# templates
- integrate regfile into default template
