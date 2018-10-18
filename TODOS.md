# Todo-List

## general
- add check (nagelfar shell script)
- README update:
  - acknolwledgement?
  - add description

## lib
- regfile support
  - add get\_regfile -name (without -of option) possibility
- add net/signal data type to retrieve signals?
- library cleanup
  - merge similar data-structs
  - only one regfile per module
- localparams?
- allow partial connections of bus signals (low-prio - would require larger reworks)

## tcllib
- add instance-only command or check in M if already exists: sane values, instances only?
- regfile:
  - specify data width / address alignment?
  - specify regfile portnames (clk, ...)
- codesections: make adapt-selectively the default?
- verilog-helpers: add parser for simple verilog values - use it in checkers

## templates
- support module attributes (fpga)
- testbench -> regs
- testbench to outside dummy module (see nowriteout function ?)

## bin
- allow multiple construction scripts?
- add "nowriteout" function or similar? -> allows for construction with intermediate clean

## documentation
- regfile / handshake direct connect
- some markdown pages with explanations?
  - how to write a construct script
  - how to write a template/template set
  - how the software is organized (for developers)
  - ...?
  - minimal example that shows off most features (similar to initial SNG file)
