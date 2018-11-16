# ICGlue construction scripts

## File
An ICGlue construction script is a Tcl script run in an encapsulating namespace by ICGlue.
Besides all Tcl commands, ICGlue commands for hierarchy, codesection and regfile generation are provided.

## Module hierarchy
For creating the module hierarchy the command `M` is provided.
It creates a unit/module hierarchy.

### Example
```tcl
M -unit "abc" -tree {
    tb_abc .................. (tb)
    |
    +-- abc ................. (rtl,ilm)
    |   |
    |   +-- res1<inst1..4> .. (res)
    |   +-- res2<a,b> ....... (res)
    |
    +-- verifip<tb> ......... (res)
}
```

The example will create a unit `abc` with a testbench (`tb`) `tb_abc`,
an RTL module `abc` and an instance of a non-generated resource (`res`)
`verifip` with instance identifier `tb`.
The Module `abc` will contain multiple instances of two other non-generated
resources `res1` (instance identifiers `inst1`, ..., `inst4`) and `res2`
(instance identifiers `a` and `b`).

### Design unit
The design unit for the generated hierarchy can be specified via the `-unit` switch.
Alternatively sub hierarchies can be part of a different unit by specifying `unit=<unitname>`
in the modules properties in parentheses at the end of the module's specification line.

### Hierarchy tree
The hierarchy is specified as a tree block after the `-tree` argument.
Variables and Tcl commands in brackets will be evaluated inside the specified tree.
Hierarchy is defined by indentation of the modules and instances.
It is possible (and looks nice) to draw a tree-like structure, but this structure
is not parsed -- any non-alphabetic characters are just parsed as indentation.

Modules that are not resources will be generated and can only be instantiated once.
The reason is that there is no way to distinguish their sub-instances when creating
signals.
Every instance can have an instance identifier in `<` and `>` delimiters.
Resource instances can have multiple instances specified by separating their
identifiers by commas or alternatively using `..` for a range of numeric identifiers (see example above).

### Module properties
A module can have comma-separated properties set in parentheses at the end of its specification line.
Dot and space characters before the parentheses are ignored and can be used to improve readability.
Properties specify a view, a hardware description language or additional properties.

Views:
* `tb` (testbench)
* `rtl` (RTL description = default)
* `beh` (behavioral description)

Hardware description languages:
* `v` (verilog = default)
* `sv` (systemverilog)
* `vhdl` (vhdl)

Additional properties
* `res` (module is a resource -- resources are assumed to exist,
  will not be generated and are allowed to be instantiated multiple times)
* `ilm` (module is an ILM module -- it will become a place & route macro
  and parameters are not fed through to its instance as this is impossible for macros)
* `inc` (instance of a module specified before, e.g. in an individual hierarchy tree)
* `unit=<unitname>` (to specify an individual unit for a hierarchy tree branch)
* `rf=<rf-name>` (module contains a register file, a name can be specified)
* `rfattr=<attr>=<value>` (additional attribute set for the regfile in a module;
  regfile will have an attribute `<attr>` set to value `<value>`)

### Alternative module/instance specification
Alternatively it is possible to specify individual modules in the form:
```
M [-tb|-rtl|-beh] [-v|-sv|-vhdl] [-ilm] [-res] [-u <unit>] <module-name> [-i <instance-list>]
```

In this case instantiated modules  must already be defined.
Instance identifiers are similar to those in the hierarchy tree.
The flags are similar to the module properties in the hierarchy tree.

## Signals and Parameters
For specifying hierarchical signals and module parameters the commands
`S` (signals) and `P` (parameters) are provided.

Signals and parameters have a unique identifier.
So within a given construction step every signal name and every parameter name
can be specified only once even for different sub hierarchies.

For every signal or parameter explicit endpoints (= instances) within the
hierarchy can be specified where the signal is connected to or the parameter is provided.
The remaining hierarchy will be adapted accordingly if it is between two explicit endpoints
on a hierarchy branch or a common root between two explicit endpoints.

Explicit endpoints are instances with their instance identifiers.
Additionally they can be provided with an explicit instance-specific
port or parameter name after a colon (`:`).
In case of a signal an explicit port name will be used verbatim unless
followed by an exclamation mark (`!`, in which case the port will get a generated suffix
indicating its direction).
Additionally in case of a signal a signal can be connected inverted by prefixing the
explicit endpoint with a tilde (`~`).

Parameters have to be provided a default value, signals can be provided with a value
which will be assigned to them at the signal source point.
Additionally signals can be specified with a bus width.

### Signals
General command structure:
```
S <signal-identifier> [-w <bus-width>] [(-v|=) <assigned-value>] <endpoint-list> ... (<--|<->|-->) <endpoint-list> ...
```

The arrow between the endpoint lists specifies the signal direction.
For a directed signal (`<--` or `-->`) only one source endpoint is allowed.

### Parameters
General command structure:
```
P <parameter-identifier> [-v <default-value>] <endpoint-list> ...
```

### Examples
```tcl
# 32 bit regfile config signal
S config1 -w 32 regfile --> core:config_i

# 1 bit tied config signal
S config2 -v {1'b0} mgmt --> core<1..4>:mode! ~accelerator:mode_n!

# parameter
P GPIO_W -v 8 testbench pads

# bidirectional
S gpio -w {GPIO_W} pads <-> testbench
```

## Codesections
In order to add code-snippets or larger parts of code within the constructions script
the `C` command is provided to add a code-snippet `<code>` into a module specified by `<module-name>`:
```
C [-a[dapt]|-noa[dapt]|-a[dapt-]s[electively]] [-s[ubst]|-nos[ubst]|-e[valuate]] [-v[erbatim]] [-align <align-string>] [-noi[ndentfix]] <module-name> <code>
```

The code can be adapted to replace signal-names used in the construction script by the actual wire/port names within the module:
* `-adapt` (default): Whenever a substring in the code-snippet matches a signal-name in the construction script, it is replaced.
* `-noadapt`: Nothing is replaced.
* `-adapt-selectively`: Only substrings followed by an exclamation mark (`!`) are replaced. If they do not match a signal-name, a warning is issued.

Tcl variables and sub-commands can be substituted within the code-snippet:
* `-subst` (default): Tcl-Variables are substituted.
* `-evaluate`: Tcl-Variables and sub-commands are substituted by their (return) value.
* `-nosubst`: Nothing is substituted.

In order to prevent adaption of signal-names and Tcl substitution, both can be disabled by `-verbatim`.

Code-snippet indentation will be adapted by default so that it can be fitted to the construction script and also later in the
template output. This can be disabled by `-noindentfix`.

It is possible to align lines inside multiple consecutive codesections at e.g. a ` = ` string by specifying `-align " = "`.
This happens independent of the semantics. So it is better to specify ` = ` instead of `=` because the latter will also align at `==`.

Example:
```tcl
# make use of substitution, selective adaption and alignment
set n 10
for {set i 0} {$i < $n} {incr i} {
    S signal${i} -w 4 top <-- core
    C -adapt-selectively -align " = " core {
        assign signal${i}! = 4'd${i};
    }
}
```

## Regfiles

### Regfile Entries
Entries of a regfile (specified as module option in the `M` command) can be created using the `R` command.
The definition is done one entry at a time with all of its containing registers.
An entry has an address, which can be assigned explicitly or automatically with auto-incrementing of the last assigned address value.

The registers within an entry are specified with
* a name,
* a size specified by width in bits or explicitly specifying sub-bits in the entry,
* a type and optionally
* a reset value,
* a signal connected to the register,
* a bit-range for the signal in case the signal is only partially connected and
* a comment for documentation.

The general `R` command is invoked in the form to add an entry `<entry-name>` to a register-file `<regfile-name>`:
```
R -regfile <regfile-name> [(@|-addr) <address>] [-prot[ected]] [-handshake <handshake-specification>] [-subst|-nosubst|-evaluate] <entry-name> <register-table>
```

An explicit address can be specified using the `-addr` or `@` option followed by the address.
If no address is specified, the last address used of the specified register file is incremented and used instead.

To set the protected property of the regfile entry you can specify the `-protected` option.

In case a signal of another module is read via handshake-synchronization, this can be specified by the `-handshake` option.
It expects a list of the form `{<trigger-out> <acknowledge-in> type}`, where `<trigger-out>` and `<acknowledge-in>` are
the Signals to use for the handshake and `<type>` can be `"S"` for synchronization (so the acknowledgement will by synchronized
into the regfile clock domain) or empty.

Substitution in the register-table can be controlled by:
* `-subst` (default): Tcl-Variables are substituted.
* `-evaluate`: Tcl-Variables and sub-commands are substituted by their (return) value.
* `-nosubst`: Nothing is substituted.

The register-table is specified as
```
{
    "name"  | "width" or "entrybits"  | "type"  | "reset"  | "signal"  | ["signalbits" ] | "comment"
    ------  | ----------------------  | ------  | -------  | --------  | [------------ ] | ---------
    <name1> | <width1 or <entrybits1> | <type1> | <reset1> | <signal1> | [<signalbits1>] | <comment1>
    <name2> | <width2 or <entrybits2> | <type2> | <reset2> | <signal2> | [<signalbits2>] | <comment2>

    ...
}

```

alternatively a nested list of the form is possible:

```
{
    {name    width    or entrybits    type    [reset   ] signal    [signalbits   ] comment   }
    {<name1> <width1> or <entrybits1> <type1> [<reset1>] <signal1> [<signalbits1>] <comment1>}
    {<name2> <width2> or< entrybits2> <type2> [<reset2>] <signal2> [<signalbits2>] <comment2>}
    ...
}
```

- if `signalbits` is omitted the `signalbits` get their value of the entrybits column
- if `reset` is omitted the value `0` is taken as default

The first list contains the table headers and must contain in a matching order for the whole table:
* `name`: the register name.
* `width` or `entrybits`: the size of the register in bits or the bits the register uses within the entry.
* `type`: the register type.
Optionally (and depending on the register type):
* `reset`: the reset value.
* `signal`: a signal connected to the register.
  It is also possible to directly specify a target module port here in the format accepted by the `S` command.
  In this case the signal is created together with the register.
* `signalbits`: subset of bits of the signal connected to the register; otherwise the whole signal is connected.
* `comment`: a comment for documentation.

Unused optional values (except comment) can be omitted by putting a `-` in the table or omitting the column if none of the registers use it.
Unused columns can be omitted in the table.

Register types are:
* `RW`: a generated register with read/write-access.
* `R`: a read-only register (e.g. input from another module).
* `TRW`: a generated register with read/write-access that toggles back to its reset value directly after its write-cycle (can be used for synchronous trigger signals).
* `CRW`: a custom read/write-register: The hardware-description of the write-access is omitted and a keep-block is inserted for the user.
* `FCRW`: a full-custom read/write-register: All register-specific description is omitted and keep-blocks are inserted for the user.


### Examples


explicit way (component view) - signal connection in done seperately:
```
    S "entry_name0_s_cfg"    -w 5  submod:s_cfg_i     <--  submod_regfile
    S "entry_name0_s_status" -w 16 submod:s_status_o  -->  submod_regfile
    R submod_regfile "entry_name0" -protected {
        "name"   | "entrybits" | "type" | "reset" | "signal"             | "comment"
        -----    | ----------- | -----  | ------- | --------             | ---------
        s_cfg    | 4:0         | RW     | 5'h0    | entry_name0_s_cfg    | "Configure component"
        s_status | 31:16       | R      | 16'h0   | entry_name0_s_status | "Component status"
    }
```

same with inline connection (toplevel integration view):
```
    R submod_regfile "entry_name0" {
        "name"   | "entrybits" | "type" | "reset" | "signal"          | "comment"
        -----    | ----------- | -----  | ------- | --------          | ---------
        s_cfg    | 4:0         | RW     | 5'h0    | submod:s_cfg_i    | "Configure component"
        s_status | 31:16       | R      | 16'h0   | submod:s_status_o | "Component status"
    }
}

- use `logger -level I -id RCon` in order to see the generated signals of the command

```


if the signal-width exceeds the the regfile data width you can split signals with the `signalbits` column
this is also useful for part selection and register subfield creation

```
S "s_cfg_large" -w 40 submod_regfile  -->  submod
R submod_regfile "entry_name1_low" {
    "name" | "entrybits" | "type" | "reset" | "signal"    | "signalbits" | "comment"
    -----  | ----------- | -----  | ------- | --------    | ------------ | ---------
    s_cfg  | 31:0        | RW     | 32'h0   | s_cfg_large | 31:0         | "Configure submod part 0"
}
R submod_regfile "entry_name1_high" {
    "name" | "entrybits" | "type" | "reset" | "signal"    | "signalbits" | "comment"
    -----  | ----------- | -----  | ------- | --------    | ------------ | ---------
    s_cfg  | 7:0         | RW     | 8'h0    | s_cfg_large | 39:32        | "Configure submod part 1"
}
```

### Registerfile-Table
For simple regfile entries (e.g. no handshake synchronization) it is also possible to specify multiple entries as a table using the `RT` command.
The table will then have additional columns for `entryname`, `address` and `protect`.
For multiple registers of the same entry name, address and protection only need to be specified for the first one.
The table will then look like this:
```
{
    {entryname    address    protect    name      width      entrybits      type      reset      signal      signalbits      comment     }
    {<entryname1> <address1> <protect1> <name1.1> <width1.1> <entrybits1.1> <type1.1> <reset1.1> <signal1.1> <signalbits1.1> <comment1.1>}
    {{}           {}         {}         <name1.2> <width1.2> <entrybits1.2> <type1.2> <reset1.2> <signal1.2> <signalbits1.2> <comment1.2>}
    ...
    {<entryname2> <address2> <protect2> <name2.1> <width2.1> <entrybits2.1> <type2.1> <reset2.1> <signal2.1> <signalbits2.1> <comment2.1>}
    {{}           {}         {}         <name2.2> <width2.2> <entrybits2.2> <type2.2> <reset2.2> <signal2.2> <signalbits2.2> <comment2.2>}
    ...
}
```

The command structure is:
```
RT -regfile <regfile-name> [-nosubst|-evaluate] [-csv] [-csvseparator <separator>] (-csvfile <filename>|<register-table>)
```
The `-nosubst` and `-evaluate` options are the same as for the `R` command.
The table can alternatively be specified in csv-format (`-csv` option) with separator specified by `-csvseparator` option, default is `;`.
In case of csv-format it is also possible to specify a csv-file instead of the table via the `-csvfile` option.

### Combined Signal and Register Definition

The `SR` command is a short cut for signal connection and register creation on a register file.
The register type (RW) is derived from the direction of the connection.

If you want to see the `S` and `R` command issued, you can turn on the log-level by
```
logger -level I -id SRCmd
```

The signalname is prefixed by the regfile-name in order to avoid collisions.

The command usage is as follows
```
SR [OPTION]... SIGNALNAME CONNECTIONPORTS...
  -w(idth)(=)                set signal width
  -(-)\>                     first element is interpreted as input source
  <(-)-                      last element is interpreted as input source
  (@|-addr($|=))             specify the address
  -c(omment)($|=)            specify comment for the register
  -handshake($|=)            specify signals and type for handshake {signal-out signal-in type}
  -prot(ect(ed))             register is protected for privileged-only access
  (=|-v(alue)|-r(eset(val))) specify reset value for the register
```

### Examples

```
I,SRCmd     SR submod_start_seed -w 32 = 32'hCAFEBABE submod_regfile --> submod:start_seed_i -comment {Submodule start seed}
                S "submod_regfile_submod_start_seed" -w 32 submod_regfile --> submod:start_seed_i
                R -rf=submod_regfile "submod_start_seed" -nosubst {
                    "name" | "width" | "type" | "reset"      | "signal"                         | "comment"
                    val    | 32      | RW     | 32'hCAFEBABE | submod_regfile_submod_start_seed | "Submodule start seed"
                }
I,SRCmd     SR submod_state -w 32 submod_regfile <-- submod:state_o -handshake {"state_trigger" "state_trigger_ack" "S"} -protected -comment {Submodule read state}
                S "submod_regfile_submod_state" -w 32 submod_regfile <-- submod:state_o
                R -rf=submod_regfile "submod_state" -nosubst -handshake {"state_trigger" "state_trigger_ack" "S"} -protected {
                    "name" | "width" | "type" | "reset" | "signal"                    | "comment"
                    val    | 32      | R      | -       | submod_regfile_submod_state | "Submodule read state"
                }
I,SRCmd     SR rf_protect -w 1 = 1'b0 submod_regfile:rf_protect_ctl! --> submod_regfile:apb_prot_en! -comment {protection enable}
                S "submod_regfile_rf_protect" -w 1 submod_regfile:rf_protect_ctl! --> submod_regfile:apb_prot_en!
                R -rf=submod_regfile "rf_protect" -nosubst {
                    "name" | "width" | "type" | "reset" | "signal"                  | "comment"
                    val    | 1       | RW     | 1'b0    | submod_regfile_rf_protect | "protection enable"
                }
```


## Keep Blocks
The generated outputs can contain keep-blocks.
When the output is regenerated the part within those blocks is kept as it is.
The sections are meant to be used for custom code or code that can be modified by the user and should not be
modified by a new generate cycle.
The blocks are surrounded by special comments in the form:
```verilog
    /* icglue keep begin <identifier> *//* icglue keep end */
```
For verilog or similar for other output languages.

Code between those keep-comments is read in if a generated output already exists and put
at the same logical position in the generated code again. The logical position is determined
by the identifier of the keep begin comment.

In case a non-empty keep block identifier vanishes (e.g. a custom block within generated register code)
the default template will still output the code at the end of the generated output and a warning is issued.
It can then be moved to a new location or deleted if no longer required.
It is recommended to do this in templates where keep-identifiers are dynamically generated based on
construction-script input.

