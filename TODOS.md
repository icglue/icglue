# Todo-List

## general
- documentation
  - some markdown pages with explanations?
    - how to write a template/template set
    - how to write a construct script
    - ...?
- add check (nagelfar shell script)

## lib
- regfile support
  - add get\_regfile -name (without -of option) possibility
- add net/signal data type to retrieve signals?
- library cleanup
  - merge similar data-structs
  - only one regfile per module

## tcllib
- add instance-only command or check in M if already exists: sane values, instances only?
- squash regfile

## templates
- regfiles: support
  - trigger reg (different types: 1-0 trigger, toggle trigger, ...?)
  - sanity checker
- **testbench -> regs**
- **testbench to outside dummy module (see nowriteout function ?)**

## bin
- allow multiple construction scripts?
- add "nowriteout" function or similar? -> allows for construction with intermediate clean

## docu
- regfile / handshake direct connect

## vim
- add alignment vim-script for signals usw. <(-)- -(-)>
