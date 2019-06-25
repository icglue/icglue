
#
#   ICGlue is a Tcl-Library for scripted HDL generation
#   Copyright (C) 2017-2019  Andreas Dixius, Felix Neumärker
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

package provide ICGlue 3.2

## @brief Template related functionality
namespace eval ig::templates {
    ## @brief Collect template data
    namespace eval collection {
        variable template_dir       {}
        variable output_types_gen   {}
        variable template_path_gen  {}
        variable output_path_gen    {}
    }

    ## @brief Callback procs of currently loaded template.
    namespace eval current {
        variable template_dir ""

        ## @brief Actual callback to get the template file.
        # @param object The Object-ID of the Object to generate output for.
        # @param type One of the types returned by @ref get_output_types for the given object.
        # @param template_dir Path to this template.
        # @return Filename of the template file or optionally a 2-element list
        #         with filename and template language (currently icgt (default) or wtf).
        #
        # See also @ref ig::templates::add_template_dir
        # Should be called by @ref get_template_file.
        proc get_template_file_raw {object type template_dir} {
            ig::log -error -abort "No template loaded"
        }

        ## @brief Callback to get supported output types for given object.
        # @param object Object-ID of the Object to generate output for.
        # @return A list of supported output types needed by
        # @ref get_template_file, @ref get_template_file_raw,
        # @ref get_output_file.
        #
        # See also @ref ig::templates::add_template_dir
        proc get_output_types {object} {
            ig::log -error -abort "No template loaded"
        }

        ## @brief Callback wrapper to get the template file.
        # @param object The Object-ID of the Object to generate output for.
        # @param type One of the types returned by @ref get_output_types for the given object.
        # @return Filename of the template file.
        #
        # Calls @ref get_template_file_raw with the path to the current template.
        proc get_template_file {object type} {
            variable template_dir
            return [get_template_file_raw $object $type $template_dir]
        }

        ## @brief Callback to get path to output file.
        # @param object Object-ID of the Object to generate output for.
        # @param type One of the types returned by @ref get_output_types for the given object.
        # @return Path to the output file to generate.
        #
        # See also @ref ig::templates::add_template_dir
        proc get_output_file {object type} {
            ig::log -error -abort "No template loaded"
        }
    }

    ## @brief Preprocess helpers for template files
    namespace eval preprocess {
        ## @brief Preprocess regfile-object into array-list.
        # @param regfile_id Object-ID of regfile-object.
        # @return List of arrays (as list like obtained via array get) of regfile-entry data.
        #
        # Structure of returned array-list:
        # Main List contains arrays with entries
        # @li name = Name of regfile entry.
        # @li object = Object-ID of regfile entry.
        # @li address = Address of regfile entry.
        # @li regs = Array-list for registers in this entry.
        #
        # The regs-entry of the regfile-entry is a list of arrays with entries
        # @li name = Name of the register.
        # @li object = Object-ID of register.
        # @li bit_high = MSBit occupied inside regfile-entry.
        # @li bit_low = LSBit occupied inside regfile-entry.
        # @li width = Size of register in bits.
        # @li entrybits = Verilog-range of bits occupied inside regfile-entry.
        # @li type = Type of register, e.g. R, RW.
        # @li reset = Reset value of register.
        # @li signal = Signal this register connects to.
        # @li signalbits = Verilog-range of bits of signal to connect to.
        proc regfile_to_arraylist {regfile_id} {
            # collect all regfile entries, sort by address
            set entries [ig::db::get_regfile_entries -all -of $regfile_id]
            set entry_list {}
            set wordsize [ig::db::get_attribute -object $regfile_id -attribute "datawidth"]

            foreach i_entry $entries {
                set reg_list {}
                set regs [ig::db::get_regfile_regs -all -of $i_entry]
                set next_bit 0

                try {
                    #entry_default_map {name width entrybits type reset signal signalbits}
                    foreach i_reg $regs {
                        set name       [ig::db::get_attribute -object $i_reg -attribute "name"]
                        set width      [ig::db::get_attribute -object $i_reg -attribute "rf_width"      -default -1]
                        set entrybits  [ig::db::get_attribute -object $i_reg -attribute "rf_entrybits"  -default ""]
                        set type       [ig::db::get_attribute -object $i_reg -attribute "rf_type"       -default "RW"]
                        set reset      [ig::db::get_attribute -object $i_reg -attribute "rf_reset"      -default "-"]
                        set signal     [ig::db::get_attribute -object $i_reg -attribute "rf_signal"     -default "-"]
                        set signalbits [ig::db::get_attribute -object $i_reg -attribute "rf_signalbits" -default "-"]
                        set comment    [ig::db::get_attribute -object $i_reg -attribute "rf_comment"    -default ""]

                        if {$width < 0} {
                            if {$entrybits eq ""} {
                                set width $wordsize
                                set entrybits "[expr {$wordsize - 1}]:0"
                            } else {
                                set blist [split $entrybits ":"]
                                if {[llength $blist] == 1} {
                                    set width 1
                                } else {
                                    set width [expr {[lindex $blist 0] - [lindex $blist 1] + 1}]
                                }
                            }
                        } elseif {$entrybits eq ""} {
                            if {$width == 1} {
                                set entrybits "$next_bit"
                            } else {
                                set entrybits "[expr {$width + $next_bit - 1}]:$next_bit"
                            }
                        }

                        set blist [split $entrybits ":"]
                        set bit_high [lindex $blist 0]
                        set next_bit [expr {$bit_high+1}]
                        if {[llength $blist] == 2} {
                            set bit_low  [lindex $blist 1]
                        } else {
                            set bit_low  $bit_high
                        }

                        lappend reg_list [list \
                            $name $bit_high $bit_low $width $entrybits $type $reset $signal $signalbits $comment $i_reg \
                            ]
                    }
                    set reg_list_raw [lsort -integer -index 2 $reg_list]
                    set reg_list {}
                    set idx_start -1

                    foreach i_reg $reg_list_raw {
                        set i_bit_low [lindex $i_reg 2]
                        set i_bit_high [lindex $i_reg 1]
                        if {$i_bit_low - $idx_start > 1} {
                            set tmp_high [expr {$i_bit_low - 1}]
                            set tmp_low  [expr {$idx_start + 1}]
                            if {$tmp_high == $tmp_low} {
                                set entrybits $tmp_high
                            } else {
                                set entrybits "${tmp_high}:${tmp_low}"
                            }

                            lappend reg_list [list \
                                "name"       "-" \
                                "bit_high"   $tmp_high \
                                "bit_low"    $tmp_low \
                                "width"      [expr {$tmp_high - $tmp_low + 1}] \
                                "entrybits"  $entrybits \
                                "type"       "-" \
                                "reset"      "-" \
                                "signal"     "-" \
                                "signalbits" "-" \
                                "comment"    "" \
                                "object"     "" \
                                ]
                        }
                        lappend reg_list [list \
                            "name"       [lindex $i_reg 0] \
                            "bit_high"   [lindex $i_reg 1] \
                            "bit_low"    [lindex $i_reg 2] \
                            "width"      [lindex $i_reg 3] \
                            "entrybits"  [lindex $i_reg 4] \
                            "type"       [lindex $i_reg 5] \
                            "reset"      [lindex $i_reg 6] \
                            "signal"     [lindex $i_reg 7] \
                            "signalbits" [lindex $i_reg 8] \
                            "comment"    [lindex $i_reg 9] \
                            "object"     [lindex $i_reg 10] \
                            ]

                        set idx_start $i_bit_high
                    }
                    if {$idx_start < $wordsize - 1} {
                        set tmp_high [expr {$wordsize - 1}]
                        set tmp_low  [expr {$idx_start + 1}]
                        if {$tmp_high == $tmp_low} {
                            set entrybits $tmp_high
                        } else {
                            set entrybits "${tmp_high}:${tmp_low}"
                        }

                        lappend reg_list [list \
                            "name"       "-" \
                            "bit_high"   $tmp_high \
                            "bit_low"    $tmp_low \
                            "width"      [expr {$tmp_high - $tmp_low + 1}] \
                            "entrybits"  $entrybits \
                            "type"       "-" \
                            "reset"      "-" \
                            "signal"     "-" \
                            "signalbits" "-" \
                            "comment"    "" \
                            "object"     "" \
                            ]
                    }

                    set entry_attributes [ig::db::get_attribute -object $i_entry]
                    lappend entry_list [list                                                    \
                        "address" [ig::db::get_attribute -object $i_entry -attribute "address"] \
                        {*}[dict remove $entry_attributes "address"]                            \
                        "regs"    $reg_list                                                     \
                        "object"  $i_entry                                                      \
                        ]
                } on error {emsg eopt} {
                    ig::log -error -id RF [format "Error while processing register \"%s/%s\" in regfile \"%s\" \n -- (%s) --\n%s" \
                        [ig::db::get_attribute -object ${i_entry} -attribute "name"] ${name} \
                        [ig::db::get_attribute -object ${regfile_id} -attribute "name"] \
                        ${i_entry} \
                        [dict get $eopt {-errorinfo}]
                    ]
                }
            }
            set entry_list [lsort -integer -index 1 $entry_list]

            return $entry_list
        }

        ## @brief Preprocess instance-object into array-list.
        # @param instance_id Object-ID of instance-object.
        # @return Array as list (like obtained via array get) with instance data.
        #
        # Elements of returned array:
        # @li name = Name of instance.
        # @li object = Object-ID of instance.
        # @li module = Object-ID of module instanciated.
        # @li module.name = Name of module instanciated.
        # @li ilm = ilm property of instance.
        # @li pins = Array-List of pins of instance.
        # @li parameters = Array-List of parameters of instance.
        # @li hasparams = Boolean indicating whether instance has parameters.
        #
        # The pins entry is an array-list of arrays with entries
        # @li name = Name of pin.
        # @li object = Object-ID of pin.
        # @li connection = Connected signal/value to this pin.
        # @li invert = Pin should be inverted.
        #
        # The parameters entry is an array-list of arrays with entries
        # @li name = Name of parameter.
        # @li object = Object-ID of parameter.
        # @li value = Value assigned to parameter.
        proc instance_to_arraylist {instance_id} {
            set result {}

            set mod [ig::db::get_modules -of $instance_id]
            set ilm [ig::db::get_attribute -object $mod -attribute "ilm" -default "false"]

            lappend result "name"        [ig::db::get_attribute -object $instance_id -attribute "name"]
            lappend result "object"      $instance_id
            lappend result "module"      $mod
            lappend result "ilm"         $ilm
            lappend result "module.name" [ig::db::get_attribute -object $mod -attribute "name"]

            # pins
            set pin_data {}
            foreach i_pin [ig::db::get_pins -of $instance_id] {
                lappend pin_data [list \
                    "name"           [ig::db::get_attribute -object $i_pin -attribute "name"] \
                    "object"         $i_pin \
                    "connection"     [ig::aux::adapt_pin_connection $i_pin] \
                    "connection_raw" [ig::db::get_attribute -object $i_pin -attribute "connection"] \
                    "invert"         [ig::db::get_attribute -object $i_pin -attribute "invert" -default "false"] \
                ]
            }
            lappend result "pins" $pin_data

            # parameters
            set param_data {}
            foreach i_param [ig::db::get_adjustments -of $instance_id] {
                lappend param_data [list \
                    "name"           [ig::db::get_attribute -object $i_param -attribute "name"] \
                    "object"         $i_param \
                    "value"          [ig::db::get_attribute -object $i_param -attribute "value"] \
                ]
            }
            lappend result "parameters" $param_data

            lappend result "hasparams" [expr {(!$ilm) && ([llength $param_data] > 0)}]

            return $result
        }

        ## @brief Preprocess module-object into arra-list.
        # @param module_id Object-ID of module-object.
        # @return Array as list (like obtained via array get) with module data.
        #
        # Elements of returned array:
        # @li name = Name of module.
        # @li object = Object-ID of module.
        # @li ports = Array-List of ports of module.
        # @li parameters = Array-List of parameters of module.
        # @li declarations = Array-List of declarations of module.
        # @li code = Array-List of codesections of module.
        # @li instances = Array-List of instances of module.
        # @li regfiles = Array-List of regfiles of module.
        #
        # The ports entry is an array-list of arrays with entries
        # @li name = Name of port.
        # @li object = Object-ID of port.
        # @li size = Bitsize of port.
        # @li %vlog.bitrange = Verilog-Bitrange of port.
        # @li direction = Direction of port.
        # @li vlog.direction = Verilog port-direction.
        #
        # The parameters entry is an array-list of arrays with entries
        # @li name = Name of parameter.
        # @li object = Object-ID of parameter.
        # @li local = Boolean indicating whether this is a local parameter.
        # @li vlog.type = Verilog-Type of parameter.
        # @li value = Default value of parameter.
        #
        # The declarations entry is an array-list of arrays with entries
        # @li name = Name of declaration.
        # @li object = Object-ID of declaration.
        # @li size = Bitsize of declaration.
        # @li %vlog.bitrange = Verilog-Bitrange of declaration.
        # @li defaulttype = Boolean indicating whether declaration is of default type for declarations.
        # @li vlog.type = Verilog-Type of declarations.
        #
        # The code entry is an array-list of arrays with entries
        # @li name = Name of codesection.
        # @li object = Object-ID of codesection.
        # @li code_raw = Verbatim code of codesection.
        # @li code = Code adapted according to adapt property by @ref ig::aux::adapt_codesection.
        #
        # The instances entry is an array-list of arrays with entries as returned by
        # @ref instance_to_arraylist
        #
        # The regfiles entry is an array-list of arrays with entries
        # @li name = Name of regfile.
        # @li object = Object-ID of regfile.
        # @li addrwidth = Address input size.
        # @li addralign = Address alignment.
        # @li datawidth = Data size.
        # @li entries = Entries of regfile as array-list as returned by @ref regfile_to_arraylist.
        proc module_to_arraylist {module_id} {
            set result {}

            lappend result "name"   [ig::db::get_attribute -object $module_id -attribute "name"]
            lappend result "object" $module_id

            # ports
            set port_data {}
            foreach i_port [ig::db::get_ports -of $module_id] {
                set dimension_bitrange {}
                foreach dimension [ig::db::get_attribute -object $i_port -attribute "dimension" -default {}] {
                    append dimension_bitrange [ig::vlog::bitrange $dimension]
                }
                lappend port_data [list \
                    "name"           [ig::db::get_attribute -object $i_port -attribute "name"] \
                    "object"         $i_port \
                    "size"           [ig::db::get_attribute -object $i_port -attribute "size"] \
                    "vlog.bitrange"  [ig::vlog::obj_bitrange $i_port] \
                    "direction"      [ig::db::get_attribute -object $i_port -attribute "direction"] \
                    "vlog.direction" [ig::vlog::port_dir $i_port] \
                    "dimension"      $dimension_bitrange \
                ]
            }
            lappend result "ports" $port_data

            # parameters
            set param_data {}
            foreach i_param [ig::db::get_parameters -of $module_id] {
                lappend param_data [list \
                    "name"           [ig::db::get_attribute -object $i_param -attribute "name"] \
                    "object"         $i_param \
                    "local"          [ig::db::get_attribute -object $i_param -attribute "local"] \
                    "vlog.type"      [ig::vlog::param_type $i_param] \
                    "value"          [ig::db::get_attribute -object $i_param -attribute "value"] \
                ]
            }
            lappend result "parameters" $param_data

            # delarations
            set decl_data {}
            foreach i_decl [ig::db::get_declarations -of $module_id] {
                set dimension_bitrange {}
                foreach dimension [ig::db::get_attribute -object $i_decl -attribute "dimension" -default {}] {
                    append dimension_bitrange [ig::vlog::bitrange $dimension]
                }
                lappend decl_data [list \
                    "name"           [ig::db::get_attribute -object $i_decl -attribute "name"] \
                    "object"         $i_decl \
                    "size"           [ig::db::get_attribute -object $i_decl -attribute "size"] \
                    "vlog.bitrange"  [ig::vlog::obj_bitrange $i_decl] \
                    "defaulttype"    [ig::db::get_attribute -object $i_decl -attribute "default_type"] \
                    "vlog.type"      [ig::vlog::declaration_type $i_decl] \
                    "dimension"      $dimension_bitrange \
                ]
            }
            lappend result "declarations" $decl_data

            # codesections
            set code_data {}
            foreach i_code [ig::db::get_codesections -of $module_id] {
                lappend code_data [list \
                    "name"           [ig::db::get_attribute -object $i_code -attribute "name"] \
                    "object"         $i_code \
                    "code_raw"       [ig::db::get_attribute -object $i_code -attribute "code"] \
                    "code"           [ig::aux::adapt_codesection $i_code] \
                ]
            }
            set code_data [ig::aux::align_codesections $code_data]
            lappend result "code" $code_data

            # instances
            set inst_data {}
            foreach i_inst [ig::db::get_instances -of $module_id] {
                lappend inst_data [instance_to_arraylist $i_inst]
            }
            lappend result "instances" $inst_data

            # regfiles
            set regfile_data {}
            foreach i_regfile [ig::db::get_regfiles -of $module_id] {
                lappend regfile_data [list \
                    "name"      [ig::db::get_attribute -object $i_regfile -attribute "name"] \
                    "addrwidth" [ig::db::get_attribute -object $i_regfile -attribute "addrwidth"] \
                    "addralign" [ig::db::get_attribute -object $i_regfile -attribute "addralign"] \
                    "datawidth" [ig::db::get_attribute -object $i_regfile -attribute "datawidth"] \
                    "name"      [ig::db::get_attribute -object $i_regfile -attribute "name"] \
                    "object"    $i_regfile \
                    "entries"   [regfile_to_arraylist $i_regfile] \
                ]
            }
            lappend result "regfiles" $regfile_data

            return $result
        }

        namespace export *
    }

    ## @brief Load directory with templates.
    # @param dir Path to directory with templates.
    #
    # dir should contain one subdirectory for each template.
    # Each subdirectory should contain an "init.tcl" script inserting the template's
    # procs
    proc add_template_dir {dir} {
        set tmpl_dirs [glob -directory $dir *]
        foreach i_dir $tmpl_dirs {
            set initf_name "${i_dir}/init.tcl"
            if {![file exists ${initf_name}]} {
                continue
            }

            if {[catch {
                set init_scr [open $initf_name "r"]
                set init [read $init_scr]
                close $init_scr
            }]} {
                continue
            }

            set template     [file tail [file normalize [file dirname $initf_name]]]
            set template_dir [file normalize "${dir}/${template}"]

            lappend ig::templates::collection::template_dir [list \
                $template $template_dir \
            ]

            set preface {
                proc proc {name arglist body} {
                    variable template
                    switch -- $name {
                        output_types {
                            if {$arglist ne {object}} {
                                ig::log -error "template ${template}: invalid output_types definition (arguments must be {object})"
                            } else {
                                lappend ig::templates::collection::output_types_gen [list \
                                    $template $body \
                                ]
                            }
                        }
                        template_file {
                            if {$arglist ne {object type template_dir}} {
                                ig::log -error "template ${template}: invalid template_file definition (arguments must be {object type template_dir})"
                            } else {
                                lappend ig::templates::collection::template_path_gen [list \
                                    $template $body \
                                ]
                            }
                        }
                        output_file {
                            if {$arglist ne {object type}} {
                                ig::log -error "template ${template}: invalid output_file definition (arguments must be {object type})"
                            } else {
                                lappend ig::templates::collection::output_path_gen [list \
                                    $template $body \
                                ]
                            }
                        }
                        default {
                            ::proc $name $arglist $body
                        }
                    }
                }
                # icglue 2 init compatibility:
                namespace eval init {
                    proc output_types {template body} {
                        lappend ig::templates::collection::output_types_gen [list \
                            $template $body \
                        ]
                    }
                    proc template_file {template body} {
                        lappend ig::templates::collection::template_path_gen [list \
                            $template $body \
                        ]
                    }
                    proc output_file {template body} {
                        lappend ig::templates::collection::output_path_gen [list \
                            $template $body \
                        ]
                    }
                }
            }

            if {[catch {
                namespace eval _template_init [join [list \
                    "variable template [list $template]" \
                    $preface \
                    $init \
                    ] "\n"]
                } ex]} {

                ig::log -error "error initializing template ${template} (${template_dir}): ${ex}"
            }

            if {[namespace exists _template_init]} {namespace delete _template_init}
        }
    }

    ## @brief Load a template to use.
    # @param template Template to use. The template must have been loaded with a
    # template directory using @ref add_template_dir.
    proc load_template {template} {
        # load vars/procs for current template
        set dir_idx  [lsearch -index 0 $collection::template_dir       $template]
        set type_idx [lsearch -index 0 $collection::output_types_gen   $template]
        set tmpl_idx [lsearch -index 0 $collection::template_path_gen  $template]
        set out_idx  [lsearch -index 0 $collection::output_path_gen    $template]

        if {($dir_idx < 0) || ($type_idx < 0) || ($tmpl_idx < 0) || ($out_idx < 0)} {
            ig::log -error -abort "template $template not (fully) defined"
        }

        set current::template_dir [lindex $collection::template_dir $dir_idx 1]
        # workaround for doxygen: is otherwise irritated by directly visible proc keyword
        set procdef "proc"
        $procdef current::get_output_types      {object}                   [lindex $collection::output_types_gen   $type_idx 1]
        $procdef current::get_template_file_raw {object type template_dir} [lindex $collection::template_path_gen  $tmpl_idx 1]
        $procdef current::get_output_file       {object type}              [lindex $collection::output_path_gen    $out_idx  1]
    }

    ## @brief Parse a template.
    # @param txt Template as a single String.
    # @param filename Name of template file for error logging.
    # @return Tcl-Code generated from template as a single String.
    #
    # The template method is copied/modified to fit here from
    # https://wiki.tcl-lang.org/page/TemplaTcl%3A+a+Tcl+template+engine
    #
    # The resulting Tcl Code will write the generated output
    # using the command @c echo, which needs to be provided,
    # when evaluating.
    proc parse_template {txt {filename {}}} {
        set code  {}
        set stack [list [list $filename 1 $txt]]

        while {[llength $stack] > 0} {
            lassign [lindex $stack end] filename linenr txt
            set stack [lreplace $stack end end]

            append code "_filename [list $filename]\n"
            append code "_linenr $linenr\n"

            set re_delim_open     {<(%|\[)([+-])?}
            set delim_close       "%>"
            set delim_close_brack "\]>"

            # search  delimiter
            while {[regexp -indices $re_delim_open $txt indices m_type m_chomp]} {
                lassign $indices i_delim_start i_delim_end

                # include tag
                set incltag 0

                set opening_char [string index $txt [lindex $m_type 0]]
                if {$opening_char eq "%"} {
                    set closing_delim $delim_close
                } else {
                    set closing_delim $delim_close_brack
                }

                # check for right chomp
                set right_i [expr {$i_delim_start - 1}]


                set i [expr {$i_delim_end + 1}]
                if {([string index $txt [lindex $m_chomp 0]] eq "-") && ([string index $txt $right_i] eq "\n")} {
                    incr right_i -1
                }

                # append verbatim/normal template content (tcl-list)
                incr linenr [ig::aux::string_count_nl [string range $txt 0 [expr {$i-1}]]]
                append code "_linenr $linenr\n"
                append code "echo [list [string range $txt 0 $right_i]]\n"
                set txt [string range $txt $i end]

                if {$closing_delim eq "%>"} {
                    if {[string index $txt 0] eq "="} {
                    # <%= will be be append, but evaluated as tcl-argument
                        append code "echo "
                        set txt [string range $txt 1 end]
                    } elseif {[string index $txt 0] eq "I"} {
                    # <%I will be included here
                        set incltag 1
                        set txt [string range $txt 1 end]
                    } else {
                    # append as tcl code
                    }
                } else {
                    # closing delimiter is closing square bracket
                    append code "echo \[ "
                }

                # search ${closing_delim} delimiter
                if {[set i [string first $closing_delim $txt]] == -1} {
                    error "No matching $closing_delim"
                }
                set left_i [expr {$i + 2}]
                incr i -1
                # check for left chomp
                if {[string match {[-+]} [string index $txt $i]]} {
                    if {([string index $txt $i] eq "-") && ([string index $txt $left_i] eq "\n")} {
                        incr left_i
                    }
                    incr i -1
                }

                # include tag / code
                incr linenr [ig::aux::string_count_nl [string range $txt 0 [expr {$left_i-1}]]]

                if {$incltag} {
                    set incfname [file join ${current::template_dir} [string trim [string range $txt 0 $i]]]
                    ig::log -info -id TPrs "...parsing included template $incfname"
                    set incfile [open $incfname "r"]
                    set inccontent [read $incfile]
                    close $incfile

                    lappend stack [list $filename $linenr [string range $txt $left_i end]]
                    set linenr 1
                    set filename $incfname
                    set txt $inccontent

                    # loop-check
                    if {[lsearch -index 0 $stack $filename] >= 0} {
                        error "template file $filename includes itself"
                    }
                } else {
                    if {$closing_delim eq "%>"} {
                        append code "[string range $txt 0 $i] \n"
                    } else {
                        # closing delimiter is closing square bracket
                        append code "[string range $txt 0 $i] \]\n"
                    }
                    set txt [string range $txt $left_i end]
                }
                append code "_filename [list $filename]\n"
                append code "_linenr $linenr\n"
            }

            # append remainder of verbatim/normal template content
            if {$txt ne ""} {
                append code "echo [list $txt]\n"
            }
        }

        return $code
    }

    ## @brief Parse a Woof!-like template.
    # @param txt Template as a single String.
    # @param filename Name of template file for error logging.
    # @param filestack List of files included to check for recursion loops.
    # @return Tcl-Code generated from template as a single String.
    #
    # The template format is based on the Woof! template format:
    # http://woof.sourceforge.net/woof-ug/_woof/docs/ug/wtf
    # which is based on substify:
    # https://wiki.tcl-lang.org/page/Templates+and+subst
    #
    # The resulting Tcl Code will write the generated output
    # using the command @c echo, which needs to be provided,
    # when evaluating.
    proc parse_wtf {txt {filename {}} {filestack {}}} {
        set code {}

        set pos 0
        set block false
        set linenr 1

        lappend filestack $filename

        append code "_filename [list $filename]\n"
        append code "_linenr $linenr\n"

        # find all lines starting with %
        foreach pair [regexp -line -all -inline -indices -- {^%.*$} $txt] {
            lassign $pair from to

            if {$block} {
                # inside %( ... %)
                if {[string range $txt $from [expr {$from+1}]] eq "%)"} {
                    # block ends
                    if {[string range $txt [expr {$from+2}] $to] ne ""} {
                        ig::log -warn -id "WTFPr" "template $filename contains text after \"%)\""
                    }

                    set c [string range $txt $pos [expr {$from-2}]]
                    append code $c "\n"
                    incr linenr [expr {[ig::aux::string_count_nl $c] + 1}]

                    set block false
                    set pos   [expr {$to + 2}]
                } else {
                    # ignore
                    continue
                }
            } else {
                # single codeline / begin of %( ... %)

                # raw text so far
                set s [string range $txt $pos [expr {$from-2}]]

                if {$s ne {}} {
                    append code "_linenr $linenr\n"
                    append code "echo \"\[" [list subst $s] "\]\\n\"\n"
                    incr linenr [expr {[ig::aux::string_count_nl $s] + 1}]
                    append code "_linenr $linenr\n"
                }

                if {[string range $txt $from [expr {$from+2}]] eq "%I("} {
                    # include file
                    set s [string range $txt $from $to]
                    if {![regexp {^%I\([\s]*(.*[^\s])[\s]*\)[\s]*([^\s].*)?$} $s m_whole m_file m_sfx]} {
                        ig::log -error -abort -id "WTFPr" "template $filename contains invalid include statement"
                    }
                    if {$m_sfx ne ""} {
                        ig::log -warn -id "WTFPr" "template $filename contains text after include statement"
                    }

                    set incfname [file join ${current::template_dir} $m_file]

                    # loop-check
                    if {[lsearch $filestack $incfname] >= 0} {
                        error "template file $filename includes itself"
                    }

                    ig::log -info -id WTFPr "...parsing included template $incfname"
                    set incfile [open $incfname "r"]
                    set inccontent [read $incfile]
                    close $incfile

                    append code [parse_wtf $inccontent $incfname $filestack] "\n"

                    incr linenr

                    append code "_filename [list $filename]\n"
                    append code "_linenr $linenr\n"

                    set pos [expr {$to + 2}]
                } elseif {[string range $txt $from [expr {$from+1}]] eq "%("} {
                    # beginning of block
                    set pos [expr {$from + 2}]
                    set block true
                    incr linenr
                } else {
                    # single line
                    append code [string range $txt [expr {$from+1}] $to] "\n"

                    set pos [expr {$to + 2}]
                    incr linenr
                }
            }
        }

        if {$block} {
            error "No matching %)"
        }

        set s [string range $txt $pos end]
        if {$s ne {}} {
            append code "_linenr $linenr\n"
            append code "echo \"\[" [list subst $s] "\]\\n\"\n"
        }

        return $code
    }

    ## @brief Return comment begin/end for given filetype
    # @param filesuffix Suffix for filetype
    # @return List with two elements: begin of comment and end of comment, e.g. {"/* " " */"}
    proc comment_begin_end {filesuffix} {
        switch -exact -- [string tolower $filesuffix] {
            .h      -
            .hpp    -
            .h++    -
            .c      -
            .cpp    -
            .c++    -
            .sv     -
            .svh    -
            .vh     -
            .v      {return [list "/* "   " */"]}

            .vhd    -
            .vhdl   {return [list "-- "   "\n"]}

            .htm    -
            .html   {return [list "<!-- " " -->"]}

            .tex    {return [list "% "    "\n"]}

            default {return [list "# "    "\n"]}
        }
    }

    ## @brief Parse keep blocks of an existing output (file).
    # @param txt Existing generated output as single String.
    # @param filesuffix Suffix of filetype of file blocks are parsed in
    # @return List of parsed blocks as sublists of form {\<maintype\> \<subtype\> \<content\>}.
    #
    # The blocks parsed are of the form @code{.v}
    # /* icglue <maintype> begin <subtype> */
    # /* icglue <maintype> end */
    # @endcode
    #
    # Currently only @c keep is supported as maintype.
    # Subtypes depend on the template used.
    proc parse_keep_blocks {txt {filesuffix ".v"}} {
        set result [list]
        lassign [comment_begin_end $filesuffix] cbegin cend

        # compatibility: accept comments with "pragma"
        if {[string first "${cbegin}pragma icglue keep begin " $txt] >= 0} {
            set block_start "${cbegin}pragma icglue keep begin "
            set block_end   "${cbegin}pragma icglue keep end${cend}"
        } else {
            set block_start "${cbegin}icglue keep begin "
            set block_end   "${cbegin}icglue keep end${cend}"
        }

        while {[set i [string first $block_start $txt]] >= 0} {
            incr i [string length $block_start]

            if {[set j [string first $cend $txt $i]] < 0} {
                error "No end of icglue keep comment"
            }

            set type [string range $txt $i [expr {$j - 1}]]
            set txt [string range $txt [expr {$j + [string length $cend]}] end]

            if {[set i [string first $block_end $txt]] < 0} {
                error "No end of block after keep block begin - pragma type was ${type}"
            }
            set value [string range $txt 0 [expr {$i-1}]]
            set txt [string range $txt [expr {$i + [string length $block_end]}] end]

            lappend result [list "keep" $type $value]
        }
        return $result
    }

    ## @brief Format given content of keep block for specified filetype.
    # @param block_entry Block main type.
    # @param block_subentry Block sub type.
    # @param content Content to format inside block.
    # @param filesuffix Suffix of filetype for generated block comments.
    # @return Formatted keep block string for given content/filetype.
    proc format_keep_block_content {block_entry block_subentry content filesuffix} {
        set result {}
        lassign [comment_begin_end $filesuffix] cbegin cend

        append result "${cbegin}icglue ${block_entry} begin ${block_subentry}${cend}"
        append result $content
        append result "${cbegin}icglue ${block_entry} end${cend}"

        return $result
    }

    ## @brief Get content of specific keep block.
    # @param block_data Block data as generated by @ref parse_keep_blocks.
    # @param block_entry Block main type to look up.
    # @param block_subentry Block sub type to look up.
    # @param filesuffix Suffix of filetype for generated block comments.
    # @param default_content Default block content if nothing has been parsed
    # @return Content of specified block previously parsed or default_content.
    proc get_keep_block_content {block_data block_entry block_subentry {filesuffix ".v"} {default_content {}}} {
        set idx [lsearch -index 1 [lsearch -inline -all -index 0 $block_data $block_entry] $block_subentry]

        if {$idx >= 0} {
            return [format_keep_block_content $block_entry $block_subentry [lindex $block_data $idx 2] $filesuffix]
        } else {
            return [format_keep_block_content $block_entry $block_subentry $default_content $filesuffix]
        }
    }

    ## @brief Get content of specific keep block and remove it from keep blocks.
    # @param block_data_var Variable name containing block data as generated by @ref parse_keep_blocks.
    # @param block_entry Block main type to look up.
    # @param block_subentry Block sub type to look up.
    # @param filesuffix Suffix of filetype for generated block comments.
    # @param default_content Default block content if nothing has been parsed
    # @return Content of specified block previously parsed or default_content.
    #
    # The returned block will be removed from the list in block_data_var.
    proc pop_keep_block_content {block_data_var block_entry block_subentry {filesuffix ".v"} {default_content {}}} {
        upvar 1 $block_data_var block_data
        set idx [lsearch -index 1 [lsearch -inline -all -index 0 $block_data $block_entry] $block_subentry]

        if {$idx >= 0} {
            set result [format_keep_block_content $block_entry $block_subentry [lindex $block_data $idx 2] $filesuffix]
            set block_data [lreplace $block_data $idx $idx]
            return $result
        } else {
            return [format_keep_block_content $block_entry $block_subentry $default_content $filesuffix]
        }
    }

    ## @brief Get a list of all remaining keep blocks.
    # @param block_data Block data as generated by @ref parse_keep_blocks.
    # @param filesuffix Suffix of filetype for generated block comments.
    # @param nonempty Only return non-empty keep blocks.
    # @return list of all generated keep block comments.
    proc remaining_keep_block_contents {block_data {filesuffix ".v"} {nonempty "true"}} {
        set result [list]

        foreach i_block $block_data {
            lassign $i_block block_entry block_subentry content

            if {$nonempty && ($content eq {})} {continue}

            lappend result [format_keep_block_content $block_entry $block_subentry $content $filesuffix]
        }

        return $result
    }

    # template parse cache
    variable template_script_cache [list]

    ## @brief Lookup template file in cache and returned cached template script or parse @c template_filename.
    # @param template_filename Path to file to lookup.
    # @param template_lang Template Language
    # @return cached or parsed template file script.
    proc get_template_script {template_filename {template_lang "icgt"}} {
        variable template_script_cache

        set fname_full [file normalize $template_filename]

        set idx [lsearch -index 0 $template_script_cache $fname_full]
        if {$idx >= 0} {
            return [lindex $template_script_cache $idx 1]
        }

        set template_file [open ${template_filename} "r"]
        set template_raw [read ${template_file}]
        close ${template_file}

        if {($template_lang eq "icgt") || ($template_lang eq {})} {
            set template_script [parse_template ${template_raw} ${template_filename}]
        } elseif {($template_lang eq "wtf")} {
            set template_script [parse_wtf ${template_raw} ${template_filename}]
        } else {
            ig::log -error -abort "invalid template language ${template_lang}"
        }

        lappend template_script_cache [list $fname_full $template_script]

        return $template_script
    }

    ## @brief Generate output-file based on template and provided data.
    # @param outf_name Output file name to generate / read in for keep-blocks.
    # @param template_name name of template file.
    # @param template_lang template language/type or "link" for symbolic link.
    # @param template_data key/value dict of variable-name and variable value to set before execution of template code.
    # @param lognote note text to print in error log messages for reference.
    # @param dryrun If set to true, no actual files are written.
    #
    # The output is written to the file specified by the template callback @ref ig::templates::current::get_output_file.
    proc generate_template_output {outf_name template_name template_lang template_data lognote dryrun} {
        if {!$dryrun} {
            file mkdir [file dirname $outf_name]
            if {$template_lang eq "link"} {
                if {[file exists $outf_name]} {
                    file delete $outf_name
                }
                file link -symbolic $outf_name $template_name
                return
            }
        }

        set block_data [list]
        if {[file exists $outf_name]} {
            set outf [open $outf_name "r"]
            set oldcontent [read $outf]
            close $outf
            set block_data [parse_keep_blocks $oldcontent [file extension $outf_name]]
        }

        set template_code [get_template_script $template_name $template_lang]

        set template_data_preset "\n"
        foreach {key value} $template_data {
            append template_data_preset "    variable [list $key] [list $value]\n"
        }

        # evaluate result in temporary namespace
        eval [join [list \
            "namespace eval _template_run \{" \
            {    namespace import ::ig::aux::*} \
            {    namespace import ::ig::templates::preprocess::*} \
            {    namespace import ::ig::templates::get_keep_block_content} \
            {    namespace import ::ig::templates::pop_keep_block_content} \
            {    namespace import ::ig::templates::remaining_keep_block_contents} \
            {    namespace import ::ig::log} \
            "    variable keep_block_data [list $block_data]" \
            {    variable _res_var {}} \
            {    variable _linenr_var 0} \
            {    variable _filename_var {}} \
            {    variable _error_var {}} \
            "    proc echo {args} \{" \
            {        variable _res_var} \
            {        append _res_var {*}$args} \
            "    \}" \
            "    proc _filename {f} \{" \
            {        variable _filename_var} \
            {        set _filename_var $f} \
            "    \}" \
            "    proc _linenr {n} \{" \
            {        variable _linenr_var} \
            {        set _linenr_var $n} \
            "    \}" \
            $template_data_preset \
            "    if {\[catch {" \
            "        eval [list $template_code]" \
            "        } _errorres\]} {" \
            {        set _error_var $_errorres} \
            "    }" \
            "\}" \
            ] "\n"]

        set res      ${_template_run::_res_var}
        set error    ${_template_run::_error_var}
        set linenr   ${_template_run::_linenr_var}
        set filename ${_template_run::_filename_var}
        namespace delete _template_run

        if {$error ne ""} {
            ig::log -error "Error while running template ${lognote}\nstacktrace:\n${::errorInfo}"
            ig::log -error "template ${filename} somewhere after line ${linenr}"
            return
        }

        if {!$dryrun} {
            file mkdir [file dirname $outf_name]
            set outf [open $outf_name "w"]
            puts -nonewline $outf $res
            close $outf
        }
    }

    ## @brief Generate output for given object of specified type.
    # @param obj_id Object-ID to write output for.
    # @param type Type of template as delivered by @ref ig::templates::current::get_output_types.
    # @param dryrun If set to true, no actual files are written.
    #
    # The output is written to the file specified by the template callback @ref ig::templates::current::get_output_file.
    proc write_object {obj_id type {dryrun false}} {
        if {[catch {lassign [current::get_template_file $obj_id $type] _tt_name _tt_lang}]} {
            return
        }

        set _outf_name [current::get_output_file $obj_id $type]

        set _outf_name_var ${_outf_name}

        set _outf_name_var_norm [file normalize ${_outf_name_var}]
        set _outf_name_var_new [string map [list [file normalize [pwd]]  {.}] ${_outf_name_var_norm}]
        if {${_outf_name_var_new} ne ${_outf_name_var_norm}} {
            set _outf_name_var ${_outf_name_var_new}
        } else {
            if {[info exists ::env(ICPRO_DIR)]} {
                set _outf_name_var [string map [list $::env(ICPRO_DIR) {$ICPRO_DIR}] ${_outf_name_var}]
            }
        }

        set _logtype $type
        set _logtypelen 13
        if {[string length ${_logtype}] > ${_logtypelen}} {
            set _logtype "[string range ${_logtype} 0 [expr {${_logtypelen} - 4}]]..."
        }
        ig::log -info -id Gen "Generating [format {%-*s} [expr {${_logtypelen}+2}] "\[${_logtype}\]"] ${_outf_name_var}"

        set tt_data [list "obj_id" $obj_id]
        set tt_note "type ${type} / object [ig::db::get_attribute -object ${obj_id} -attribute "name"]"
        generate_template_output ${_outf_name} ${_tt_name} ${_tt_lang} $tt_data $tt_note $dryrun
    }

    ## @brief Generate output for given object for all output types provided by template.
    # @param obj_id Object-ID to write output for.
    # @param typelist List of types to generate, empty list generates everything.
    # @param dryrun If set to true, no actual files are written.
    #
    # Iterates over all output types provided by template callback @ref ig::templates::current::get_output_file
    # and writes output via the template.
    proc write_object_all {obj_id {typelist {}} {dryrun false}} {
        foreach i_type [current::get_output_types $obj_id] {
            if {([llength $typelist] > 0) && ($i_type ni $typelist)} {
                continue
            }
            write_object $obj_id $i_type $dryrun
        }
    }

    namespace export *
}

