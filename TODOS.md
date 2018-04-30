# general
- documentation
- license (gpl? lgpl?)

# lib
- add regfile support
  - module can be/contain regfile (with parameters/attributes clock/reset/address/wdata/... signals)
  - signals can be mapped to registers (somehow?)

# tcllib
- add regfile support in signal declaration
- include template-stuff in some wrapper
  - templates (for modules/regfiles/...)
  - write-out-function using templates depending on module properties
  - default-template included
  - what should template contain??? ... perhaps:
    - actual template(s) (module, regfile)
    - functions to generate filenames
    - ...?

# bin
- create/add binary (e.g. icglue -t \<template\> (-f \<construct.tcl\>|-sng \<file.icsng\>))
  - source construction-script
  - write-out using template-set
