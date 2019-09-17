# ICGlue templates

## Overview
ICGlue can accept multiple templates.
A template is a directory containing template-files for generated output and an init-script defining types of outputs
for a given object and target-filenames and template-files to use for each type of output.

Directories containing template directories can be specified in the `ICGLUE_TEMPLATE_PATH` (ICGlue, `ICPREP_TEMPLATE_PATH` for ICPrep) environment variable.
If a template is specified, all directories in the template path will be searched for a directory with the specified name.
If nothing is specified, the `default` template is used.

Example directory structure of a directory in the template path:
```
+-- templates
    +-- template1
    |   +-- init.tcl
    |   +-- verilog.template.v
    |   +-- regfiledoc.template.txt
    +-- template2
        +-- init.tcl
        +-- vhdl.template.vhd
```

## Init script
The init script of a template defines a Tcl proc `template_data` that defines
* the types of outputs to be generated for an ICGlue object (currently modules and regfiles),
* the template-file to use for a given object and each output type,
* the output filename for a given object and each output type.

It gets 2 arguments:
* `userdata` (mainly used in [ICPrep](icprep.md) for user provided arguments).
* `tdir` (the path to the template's directory).

To specify a set of data for output generation the `add` proc is provided taking 4 arguments:
* A tag,
* the template type,
* the template-file and
* the output file.

### Tag
The output tag is a custom identifier for what is generated for a given object.
It is useful in case more than one output file is to be generated for explicit output selection.

### Template Type and File
The template type specifies how the template is processed.
Currently there are 2 parsers available: `icgt` for ICGlue template format and `wtf` for Woof! template format.
The template-file decides which template-file is to be parsed and which parser is to be used for the given object and output type.
Additionaly there are the special types `copy` and `link` that copy the specified file or create a symlink with the specified target.
Copy and link by default do not overwrite an exisiting target file unless followed by "!".

### Output File
The output file proc decides where to write the generated output of the template-file for the given object and output-type.

### Optional Arguments
For `icprep` templates taking user provided arguments the additional proc `template_args` should be provided.
It defines what command line arguments are to be parsed in a stride list with elements
* argument (command line argument),
* description (variable description),
* default (default assignment if not specified or empty) and
* check expression (Tcl expression returning true on success checking the given argument value as `$value`).

### Actual Script
The init script only defines the 2 procs.
```tcl
# optional userdata specification
proc template_args {} {
    #   <option>      <description>    <default value>  <check expression>
    return {
        "--argument1" "<description1>" {}               {$value ne {}}
    }
}

# mandatory template data
proc template_data {userdata tdir} {
    # ... optional userdata checks

    add "tag1" icgt "${tdir}/template1.template" "target/path/1"
    add "tag2" wtf  "${tdir}/template2.wtf"      "target/path/2"
}

```

This way the procs are registered for the given template name and can be used if the template is selected.


## Template-Files
Template files are written in one of two Tcl template languages.
ICGT (ICGlue template) is inspired by a code snipped in a comment on the Tcl wiki ([TemplaTcl](https://wiki.tcl-lang.org/page/TemplaTcl%3A+a+Tcl+template+engine "TemplaTcl: a Tcl template engine")).
WTF (Woof! template format) is mainly taken from woof ([Woof! Template Format](http://woof.sourceforge.net/woof-ug/_woof/docs/ug/wtf "Woof! Template Format")).
When the template code is invoked, the Tcl variable `obj_id` is set to the object for which output will be generated.

### ICGlue Template Block delimiters
By default content in the template-file is written to the output file verbatim.
Content between special delimiters is interpreted as Tcl code.
Those blocks are:
* `<% # tcl code %>`: Contains Tcl commands to be executed.
  * `<%- # tcl code -%>`: Variant to remove line break on both sides.
  * `<%+ # tcl code +%>`: Variant to explicitly keep line break on both sides (also default).
* `<%= $tclvar %>`: Tcl value between delimiters (typically a variable or a Tcl string) is written to the output file.
  * `<%-= $tclvar -%>`: Variant to remove line break on both sides.
  * `<%+= $tclvar +%>`: Variant to explicitly keep line break on both sides (also default).
* `<[tclcommand]>`: Return value of command is written to the output file.
  * `<[-tclcommand-]>`: Variant to remove line break on both sides.
  * `<[+tclcommand+]>`: Variant to explicitly keep line break on both sides (also default).
* `<%I filename %>`: Content of file "filename" is included as template. Paths are relative to the template directory.
  * `<%-I filename -%>`: Variant to remove line break on both sides.
  * `<%+I filename +%>`: Variant to explicitly keep line break on both sides (also default).

It is possible to remove line breaks at beginning/end of lines by adding a `-` to the delimiters or explicitly add a `+` to indicate the line break is kept.
This leads to the shown variants.

### Woof! Template Block delimiters
By default content in the template-file is written to the output file with Tcl substitutions
(e.g. `$var` is replaced by the value of `var`, `[command]` is replaced by the return value of `command`, `\` need to be escaped).
Lines starting with special delimiters are interpreted as Tcl code / include statement:
* `%`: Contains a single line of Tcl code.
* `%(` to `%)`: Block of Tcl code. `%(` and `%)` must be placed at beginning of line.
* `%I(filename)`: Content of file "filename" is included as template. Paths are relative to the template directory.

### Commands
There is a set of commands to simplify some template tasks.

#### Data Preprocessing
For preprocessing of object data to Tcl lists of arrays the commands to be used are:
* `regfile_to_arraylist {object_id}`: Preprocess data of regfile object.
* `module_to_arraylist {object_id}`: Preprocess data of module object.
* `instance_to_arraylist {object_id}`: Preprocess data of instance object.

#### Keep Block Management
In order to manage content of ICGlue keep blocks a set of commands is provided.
If the generated output file already exists, the keep blocks are parsed from the file into the `keep_block_data` variable.
* `get_keep_block_content {block_data block_entry block_subentry {filesuffix ".v"} {default_content {}}}`:
  Return the content of given keep block entry. Optionally a default content can be provided if nothing has been parsed.
* `pop_keep_block_content {block_data_var block_entry block_subentry {filesuffix ".v"} {default_content {}}}`
  Return and remove the content of given keep block entry. Optionally a default content can be provided if nothing has been parsed.
* `remaining_keep_block_contents {block_data {filesuffix ".v"} {nonempty "true"}}`
  Return content of all keep blocks remaining in the keep block data set.
  This is useful to prevent loss of keep blocks that are parsed in but not written out due to a name change.

All those commands have an argument `filesuffix` which specifies the comment format.

#### Direct Output
For writing to the output file from a Tcl code segment, the command `echo` is provided.
