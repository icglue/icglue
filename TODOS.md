# Todo-List

## general
- documentation
  - some markdown pages with explanations?
    - how to write a template/template set
    - how to write a construct script
    - ...?
    - minimal example that shows off most features (similar to initial SNG file)
- add check (nagelfar shell script)

## lib
- no adapt while signal creation on ports
- regfile support
  - add get\_regfile -name (without -of option) possibility
- add net/signal data type to retrieve signals?
- library cleanup
  - merge similar data-structs
  - only one regfile per module
- localparams?
- allow partial connections of bus signals

## tcllib
- add instance-only command or check in M if already exists: sane values, instances only?
- squash regfile

## templates
- support module attributes (fpga)
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
