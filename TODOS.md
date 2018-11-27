# Todo-List

## general
- add check (nagelfar shell script)

## lib
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

## templates
- support module attributes (fpga)
- testbench -> regs
- testbench to outside dummy module (see nowriteout function ?)
- add warning to header (something with "generated file, only edit between keep-blocks").

## bin
- allow multiple construction scripts?
- add "nowriteout" function or similar? -> allows for construction with intermediate clean

