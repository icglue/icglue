# Todo-List

## general
- documentation
  - some markdown pages with explanations?
    - how to write a template/template set
    - how to write a construct script
    - ...?
- add check (nagelfar shell script)
- add manpage
- add prepare[template]

## lib
- regfile support
  - add get\_regfile -name (without -of option) possibility
- add net/signal data type to retrieve signals?
- library cleanup
  - move pointer functionality from new/free functions to lib-functions
  - make object struct part of data structs (instead of pointer)
  - proper removal of child-objects from parents
  - merge similar data-structs
  - only one regfile per module

## tcllib
- add instance-only command or check in M if already exists: sane values, instances only?
- squash regfile
- regfile R command with module

## templates
- regfiles: support
  - handshake read
  - trigger reg (different types: 1-0 trigger, toggle trigger, ...?)
  - manual entry ( -> in docu custom always block)
  - sanity checker
- testbench -> regs
- testbench to outside dummy module (see nowriteout function ?)

## bin
- allow multiple construction scripts?
- add "nowriteout" function or similar? -> allows for construction with intermediate clean
- tcl-stack-trace: suppress by default (just show error message) - enable per opt
- add "prepare" (or similar) option to generate template construction-script

## docu
- regfile / handshake direct connect

## vim
- add alignment vim-script for signals usw. <(-)- -(-)>
