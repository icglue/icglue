# ICGlue templates

## Overview
ICGlue can accept multiple templates.
A template is a directory containing template-files for generated output and an init-script defining types of outputs
for a given object and target-filenames and template-files to use for each type of output.

Directories containing template directories can be specified in the `ICGLUE_TEMPLATE_PATH` environment variable.
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
The init script of a template defines 3 Tcl proc bodies that return
* the types of outputs to be generated for an ICGlue object (currently modules and regfiles),
* the template-file to use for a given object and output type,
* the output filename for a given object and output type.


### Output Types
The output types proc defines what is generated for a given object.
This is a list of custom template-specific identifiers used in the remaining procs to decide the output filename and the template-file to use
in case more than one output file is to be generated or different template-files are to be used.

### Template-File
The template-file proc decides which template-file is to be parsed for the given object and output type.
It gets the directory of the template as additional argument to be able to specify the full path to the template-file.

### Output File
The output file proc decides where to write the generated output of the template-file for the given object and output-type.

### Actual Script
Before the script is executed the variable `template` is set to contain the name of the template.

The init script only defines the proc bodies.
If The actual procs were defined like this:
```tcl
# actual procs using the bodies of the init script:

proc output_types {object} {
    # proc body defining a list of types based on the given object
    set type_list [list]
    # ... code filling the list
    return $type_list
}

proc template_file {object type template_dir} {
    # proc body defining an absolute path to the template-file to be used
    # for the given object and output type
    # template_dir is the path to the template directory with the init script
    if {type eq "verilog"} {
        set filename "${template_dir}/template.v"
    } else {
        #...
    }
    return $filename
}

proc output_file {object type} {
    # proc body defining a path to the file to be written
    # for the given object and output type
    set object_name [ig::db::get_attribute -object $object -attribute "name"]
    if {type eq "verilog"} {
        set filename "${object_name}.v"
    } else {
        #...
    }
    return $filename
}
```

Then the init script would look like this:
```tcl
# actual content of init.tcl script

# generate object output filename: arguments: {object} (object-identifier)
init::output_types $template {
    # proc body defining a list of types based on the given object
    set type_list [list]
    # ... code filling the list
    return $type_list
}

# return path to template file: arguments: {object type template_dir} (object-identifier, outputtype, path to this template's directory)
init::template_file $template {
    # proc body defining an absolute path to the template-file to be used
    # for the given object and output type
    # template_dir is the path to the template directory with the init script
    if {type eq "verilog"} {
        set filename "${template_dir}/template.v"
    } else {
        #...
    }
    return $filename
}

# generate object output filename: arguments: {object type} (object-identifier, outputtype)
init::output_file $template {
    # proc body defining a path to the file to be written
    # for the given object and output type
    set object_name [ig::db::get_attribute -object $object -attribute "name"]
    if {type eq "verilog"} {
        set filename "${object_name}.v"
    } else {
        #...
    }
    return $filename
}
```

This way the proc bodies are registered for the given template name and can be used if the template is selected.


## Template-Files
The template files are written in a Tcl template language inspired by a code snipped in a comment on the Tcl wiki ([TemplaTcl](https://wiki.tcl-lang.org/page/TemplaTcl%3A+a+Tcl+template+engine "TemplaTcl: a Tcl template engine")).
When the template code is invoked, the Tcl variable `obj_id` is set to the object for which output will be generated.

### Block delimiters
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

It is possible to remove line breaks at beginning/end of lines by adding a `-` to the delimiters or explicitly add a `+` to indicate the line break is kept.
This leads to the shown variants.

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
