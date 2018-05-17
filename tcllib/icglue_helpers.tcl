
#
#   ICGlue is a Tcl-Library for scripted HDL generation
#   Copyright (C) 2017-2018  Andreas Dixius, Felix Neumärker
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

package provide ICGlue 1.0a1

## @brief Helper functions mainly in template/output context.
namespace eval ig::aux {

    ## @brief Option parser helper
    #
    # @param opt_regex  Regex of the optspec list
    #
    # @return stripping version of the regex
    proc opt_regex_to_helpname {opt_regex} {
        # remove ^$?
        set name [string trim $opt_regex [list "^$?"]]
        return $name
    }
    ## @brief Option parser helper
    #
    # @param cmdname        Commandname to be printed for the help message
    # @param optspec        Option specification
    # @param helpcontext    Helpcontext to be printed [arguments]
    # @param arguments      Arguments to be parsed
    #
    # optspec is a list of list containing the following elements
    #     1. regex - matching the optionname
    #     2. type - can be [const=value|TCL-TYPE] (1st form does not accept arguments, 2nd take a argument of type or throws error)
    #     3. varName - variable to be set if specified in $arguments
    #     4. description - help text for the descrition
    #
    # Example:
    # @code
    # set all 0
    # set color "no"
    # set args [ig::aux::parse_opts "ls" [list \
        {{^-a(ll)?$}   {const=1} {all}   "do not ignore entries starting with ."} \
        {{^-c(olor)?$} {string}  {color} "colorize the output"} \
        ] \
        "Files" \
        $::argv \
        ]
    #
    # puts "Flags: $color, $all - Args $args"
    #
    # @endcode
    #
    # @return Argument without a match
    proc parse_opts {cmdname optspec helpcontext arguments} {
        set retval {}
        array set opt {}

        while {[llength $arguments] > 0} {
            set arg [lindex $arguments 0]
            set arguments [lrange $arguments 1 end]
            set found 0
            foreach o $optspec {

                # option listing goes here (<regex> <type>[const=value|TCL-TYPE] <up-varname> <description>:
                set opt_regex [lindex $o 0]
                set opt_type  [lindex $o 1]
                set opt_var   [lindex $o 2]
                set opt_descr [lindex $o 3]

                if {[regexp $opt_regex $arg]} {
                    set found 1
                    set typelist [split $opt_type =]
                    set type [lindex $typelist 0]
                    if {$type eq "const"} {
                        set opt([lindex $o 2]) [lindex $typelist 1]
                    } else {
                        #TODO: check type
                        set arg [lindex $arguments 0]
                        set arguments [lrange $arguments 1 end]
                        if {($type ne "string") && (![string is $type $arg])} {
                            error "Option [opt_regex_to_helpname $opt_regex] expects value of type $type but got: $arg"
                        }
                        set opt($opt_var) $arg
                    }
                    break;
                }
                # check for default help
                if {[regexp ^-h(elp)?$ $arg]} {
                    set helpmsg {}
                    lappend helpmsg "Usage: $cmdname \[OPTION\] $helpcontext"
                    set optlist {}
                    set opthelpname_maxlen 0
                    foreach o $optspec {
                        set opt_regex [lindex $o 0]
                        set opt_descr [lindex $o 3]
                        set opthelpname [opt_regex_to_helpname $opt_regex]
                        set opthelpname_len [string length $opthelpname]
                        if {$opthelpname_maxlen < $opthelpname_len} {
                            set opthelpname_maxlen $opthelpname_len
                        }
                        lappend optlist $opthelpname
                        lappend optlist $opt_descr
                    }

                    foreach {opt_name opt_descr} $optlist {
                        lappend helpmsg [format "  %-${opthelpname_maxlen}s %s" $opt_name $opt_descr]
                    }
                    set helpmsg [join $helpmsg "\n"]
                    error $helpmsg
                    break;
                }
            }

            if {$found == 0} {
                lappend retval $arg
            }
        }

        foreach {upvarname upvarvalue} [array get opt] {
            uplevel set $upvarname $upvarvalue
        }

        return $retval
    }

    ## @brief Iterate over a list of arrays.
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param body Code to run in each iteration.
    proc foreach_array {iter array_list body} {
        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            uplevel 1 $body
        }
    }

    ## @brief Iterate over a list of arrays meeting a condition.
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param condition Condition an array must meet (otherwise the loop will continue with the next array).
    # @param body Code to run in each iteration.
    proc foreach_array_with {iter array_list condition body} {
        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            uplevel 1 if [list $condition] [list $body]
        }
    }

    ## @brief Get maximum string length out of a list of data.
    #
    # @param data_list List of data to process.
    # @param transform_proc Proc to call on each list entry to obtain string to check.
    #
    # @return Length of maximum string obtained when iterating over data_list and calling transform_proc on each element.
    proc max_entry_len {data_list transform_proc} {
        set len 0
        foreach i_entry $data_list {
            set i_len [string length [$transform_proc $i_entry]]
            set len [expr {max ($len, $i_len)}]
        }
        return $len
    }

    ## @brief Get maximum string length of a certain entry out of a list of arrays.
    #
    # @param array_list List of arrays to process (in list form as from [array get ...]).
    # @param array_entry Entry of each array to check.
    #
    # @return Length of maximum string obtained when iterating over array_list and checking for array_entry.
    proc max_array_entry_len {array_list array_entry} {
        set len 0
        foreach i_entry $array_list {
            array set i_a $i_entry
            set i_len [string length $i_a($array_entry)]
            set len [expr {max ($len, $i_len)}]
        }
        return $len
    }

    ## @brief Check whether ar list entry is last of the list.
    #
    # @param lst List to check.
    # @param entry Entry to check.
    #
    # @return true if entry is the last entry of lst, falso otherwise.
    proc is_last {lst entry} {
        if {[lindex $lst end] eq $entry} {
            return "true"
        } else {
            return "false"
        }
    }

    ## @brief Get object name from database object-ID
    #
    # @param obj ID of Object.
    #
    # @return Name of the given Object.
    proc object_name {obj} {
        return [ig::db::get_attribute -object $obj -attribute "name"]
    }

    ## @brief Adapt signalnames in a codesection object if adapt-attribute is set.
    #
    # @param codesection Codesection Object-ID.
    #
    # @return Modified codesection based on "adapt" property.
    proc adapt_codesection {codesection} {
        set do_adapt [ig::db::get_attribute -object $codesection -attribute "adapt" -default "false"]
        set code [ig::db::get_attribute -object $codesection -attribute "code"]
        if {!$do_adapt} {
            return $code
        }

        set parent_mod [ig::db::get_attribute -object $codesection -attribute "parent"]
        set signal_replace [list]
        foreach i_port [ig::db::get_ports -of $parent_mod -all] {
            set i_rep [list \
                [ig::db::get_attribute -object $i_port -attribute "signal"] \
                [ig::db::get_attribute -object $i_port -attribute "name"] \
            ]
            lappend signal_replace $i_rep
        }
        foreach i_decl [ig::db::get_declarations -of $parent_mod -all] {
            set i_rep [list \
                [ig::db::get_attribute -object $i_decl -attribute "signal"] \
                [ig::db::get_attribute -object $i_decl -attribute "name"] \
            ]
            lappend signal_replace $i_rep
        }

        foreach i_rep $signal_replace {
            set i_orig  "\\m[lindex $i_rep 0]\\M"
            set i_subst [lindex $i_rep 1]

            regsub -all $i_orig $code $i_subst code
        }

        return $code
    }

    ## @brief Adapt a signalname in given module to the local signal name.
    #
    # @param signalname Name of the signal to check.
    # @param mod_id Object-ID of the module to adapt for.
    #
    # @return Adapted signal name if found in specified module.
    proc adapt_signalname {signalname mod_id} {
        foreach i_port [ig::db::get_ports -of $mod_id -all] {
            if {[ig::db::get_attribute -object $i_port -attribute "signal"] eq $signalname} {
                return [ig::db::get_attribute -object $i_port -attribute "name"]
            }
        }
        foreach i_decl [ig::db::get_declarations -of $mod_id -all] {
            if {[ig::db::get_attribute -object $i_decl -attribute "signal"] eq $signalname} {
                return [ig::db::get_attribute -object $i_decl -attribute "name"]
            }
        }
        ig::log -warning "Signal $signalname not defined in module [ig::db::get_attribute -object $mod_id -attribute "name"]"
        return $signalname
    }

    namespace export *
}

# vim: filetype=icgluetcl
