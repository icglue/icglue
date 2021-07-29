# Todo-List

## general
- [ ] add check (nagelfar shell script)

## regfiles
- [ ] sync. resets:
  - [ ] regfile-attribute: default sync reset signal, default sync. reset feature (= 1/0, default 0)
  - [ ] entry-attribute (= differing from regfile default): sync reset signal, default sync. reset feature
  - [ ] register-attribute in optional reg-table column: differing sync reset signal,
        sync. reset value ("=reset" -> same as async reset value, - -> no sync. reset, value)
- [ ] apb + simple regfile if
  - regfile-attribute for interface type
    - [x] init.tcl
    - [ ] output-template
  - specify regfile portnames (clk, ...)
    - [x] init.tcl
    - [ ] output-template
  - [x] default property in template for required signals
  - [ ] default property in template signal names of required signals (can be overwritten in icglue script)
  - [ ] add check depending on properties
- [ ] read-signal:
  - per entry?: optional module output signalling register read (-> attribute)
- [ ] support systemverilog structs / reg
- [ ] support systemverilog enums
- [ ] regfile-command: explicit switch for table/tcl-list input data (otherwise: guess + warn),
      maybe add dict input data?

## lib
- [ ] library cleanup
  - [ ] merge similar data-structs
  - [ ] only one regfile per module
- [ ] localparams?
- [ ] allow partial connections of bus signals (low-prio - would require larger reworks)
- [ ] make attribute values tcl objects?

## tcllib
- [ ] signals: add type switch (e.g. struct types)
- [ ] reuse created rtl as ressource (also in testbench)
- [ ] add instance-only command or check in M if already exists: sane values, instances only?
- [ ] codesections: make adapt-selectively the default?
- [ ] checks: use "origin" information of constructed parts for logging of warnings
- [ ] support systemverilog structs

## templates
- [ ] signals: add type (see tcllib)
- [ ] testbench -> regs
- [ ] update systemverilog templates for logic type
- [ ] rewrite regfile template as systemverilog woof with enums for address?
- [ ] default properties set by template:
  - [ ] e.g. verilog/systemverilog (default language)
  - [ ] regfile properties (e.g. apb)
  - [ ] init.tcl: add `template_defaults` or similar for default properties initialization

## bin
- [ ] allow multiple construction scripts?

## test
- [ ] more tests
- [ ] coverage? (via nagelfar)
