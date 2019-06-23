
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

package provide ICGlue 4.0a1

## @brief Helper functions mainly in template/output context.
namespace eval ig::aux {

    ## @brief Option parser helper
    #
    # @param opt_regex  Regex of the optspec list
    #
    # @return stripping version of the regex
    proc opt_regex_to_helpname {opt_regex} {
        # remove ^$
        set name [string trim $opt_regex [list "^$"]]
        set name [string map {"?" {}} $name]
        return $name
    }

    ## @brief Option parser helper
    #
    # @param cmdname        Commandname to be printed for the help message
    # @param helpcontext    Helpcontext to be printed [arguments]
    # @param optspec        Option specification
    # @param arguments      Arguments to be parsed
    # @param level          Uplevel for varName (default 1)
    #
    # optspec is a list of list containing the following elements
    #     1. regex - matching the optionname
    #     2. type - can be [const=value|TCL-TYPE] (1st form does not accept arguments, 2nd take a argument of type or throws error)
    #     3. varName - variable to be set if specified in $arguments
    #     4. description - help text for the descrition
    #
    #
    # @return Argument without a match
    proc _parse_opts {cmdname helpcontext optspec arguments {level 1}} {
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
                set index [regexp $opt_regex $arg match]
                if {$index > 0} {
                    set found 1
                    set typelist [split $opt_type =]
                    set type [lindex $typelist 0]
                    if {$type eq "const"} {
                        set opt([lindex $o 2]) [lindex $typelist 1]
                    } else {
                        set len_match [string length $match]
                        set len_arg   [string length $arg]
                        if {$len_match == $len_arg} {
                            if {[llength $arguments] == 0} {
                                error "Option [opt_regex_to_helpname $opt_regex] expects an argument"
                            }
                            set arg [lindex $arguments 0]
                            set arguments [lrange $arguments 1 end]
                        } else {
                            set arg [string range $arg $len_match end]
                        }
                        if {($type ne "string") && ($type ne "list") && (![string is $type $arg])} {
                            error "Option [opt_regex_to_helpname $opt_regex] expects value of type $type but got: $arg"
                        }
                        if {$type eq "list"} {
                            lappend opt($opt_var) $arg
                        } else {
                            set opt($opt_var) $arg
                        }
                    }
                    break;
                }
            }

            if {$found == 1} {
                continue;
            }

            # check for default help
            if {[regexp ^-h(elp)?$ $arg]} {
                set helpmsg {}
                lappend helpmsg "Usage: $cmdname \[OPTION\]... $helpcontext"
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
            } elseif {$arg eq "-helpdoxy"} {
                set helpmsg {}
                lappend helpmsg "    # @param args <b> \[OPTION\]... $helpcontext</b><br>"
                lappend helpmsg "    #    <table style=\"border:0px; border-spacing:40px 0px;\">"
                lappend helpmsg "    #      <tr><td><b> __TODO__ HELPCONTEXT </b></td><td> __TODO__ ARGUMENT DESCRIPTION <br></td></tr>"
                lappend helpmsg "    #      <tr><td><b> OPTION </b></td><td><br></td></tr>"
                set optlist {}
                set opthelpname_maxlen 0
                set optdescr_maxlen 0
                foreach o $optspec {
                    set opt_regex [lindex $o 0]
                    set opt_descr [lindex $o 3]
                    set opthelpname [opt_regex_to_helpname $opt_regex]
                    set opthelpname_len [string length $opthelpname]
                    if {$opthelpname_maxlen < $opthelpname_len} {
                        set opthelpname_maxlen $opthelpname_len
                    }
                    set optdescr_len [string length $opt_descr]
                    if {$optdescr_maxlen < $optdescr_len} {
                        set optdescr_maxlen $optdescr_len
                    }
                    lappend optlist $opthelpname
                    lappend optlist $opt_descr
                }

                foreach {opt_name opt_descr} $optlist {
                    lappend helpmsg [format "    #      <tr><td><i> &ensp; &ensp; %-${opthelpname_maxlen}s  </i></td><td>  %-${optdescr_maxlen}s <br></td></tr>" $opt_name $opt_descr]
                }
                lappend helpmsg "    #    </table>"
                set helpmsg [join $helpmsg "\n"]
                error $helpmsg
                break;
            }

            lappend retval $arg
        }

        foreach {upvarname upvarvalue} [array get opt] {
            uplevel $level set $upvarname [list $upvarvalue]
        }

        return $retval
    }

    ## @brief Option parser helper wrapper
    #
    # @param args <b>[OPTION]... OPTSPEC ARGUMENTS</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b>  OPTSPEC  </b></td><td>  Option specification is a list of list containing the following elements  <br></td></tr>
    #      <tr><td></td><td>
    #         <table style="border:0px">
    #           <tr><td><i> &ensp; &ensp; 1. regexp       </i></td><td>  matching the optionname                                                                                          <br></td></tr>
    #           <tr><td><i> &ensp; &ensp; 2. type         </i></td><td>  can be [const=value|TCL-TYPE] (1st form does not accept arguments, 2nd take a argument of type or throws error)  <br></td></tr>
    #           <tr><td><i> &ensp; &ensp; 3. varName      </i></td><td>  variable to be set if option exist in ARGUMENTS                                                                  <br></td></tr>
    #           <tr><td><i> &ensp; &ensp; 4. description  </i></td><td>  help text for the descrition                                                                                     <br></td></tr>
    #         </table>
    #       </td></tr>
    #     <tr><td><b>  ARGUMENTS  </b></td><td>  Arguments that should be parsed into specified variables  <br></td></tr>
    #     <tr><td><b>  OPTION     </b></td><td>                                                            <br></td></tr>
    #         <tr><td>&ensp; &ensp; &ensp; -name(=)COMMANDNAME    </td><td>  set commandname for help message default is proc-name of caller / filename  <br></td></tr>
    #         <tr><td>&ensp; &ensp; &ensp; -context(=)HELPCONTEXT </td><td>  set helpcontext for specifing the position dependendent arguments           <br></td></tr>
    #         <tr><td>&ensp; &ensp; &ensp; -helpdoxy            </td><td>  generate templalte for doxygen help for the caller                          <br></td></tr>
    #    </table>
    #
    # Example:
    # @code
    # set all 0
    # set color "no"
    #
    # set args [ig::aux::_parse_opts -name "ls" {
    #     {{^-a(ll)?}   "const=1" all   "do not ignore entries starting with ."}
    #     {{^-c(olor)?} "string"  color "colorize the output"}
    #   } -context "FILES..." $::argv ]
    #
    # puts "Flags: $color, $all - Args $args"
    # @endcode
    #
    # @return Arguments without a match
    proc parse_opts args {
        set procname [lindex [info level 0] 0]
        set help 0
        set helpdoxy 0
        # default command name is proc caller
        if {[info level] == 1} {
            set cmdname $::argv0
        } else {
            set cmdname [lindex [info level -1] 0]
        }

        set optspec [list                                                                                       \
                    { {^-name(=)?}      "string"  cmdname     "specfiy a command name for the helpmsg"}         \
                    { {^-context(=)?}   "string"  helpcontext "specfiy a helpcontext for the helpmsg"}          \
                ]                                                                                               \

        if {[llength $args] != 1} {
            lappend optspec \
                { {^-h(elp)?$}   "const=1" help        "generate help message for the caller"}              \
                { {^-helpdoxy$}  "const=1" helpdoxy    "generate template for doxygen help for the caller"} \
        }

        set helpcontext {}
        set arguments [             \
            _parse_opts             \
                $procname           \
                "OPTSPEC ARGUMENTS" \
                $optspec            \
                $args               \
                1                   \
            ]

        if {$help == 1} {
            return [_parse_opts $cmdname $helpcontext [lindex $arguments 0] -help]
        }
        if {$helpdoxy == 1} {
            return [_parse_opts $cmdname $helpcontext [lindex $arguments 0] -helpdoxy]
        }

        if {[llength $arguments] == 2} {
            return [_parse_opts $cmdname $helpcontext {*}$arguments 2]
        } elseif {[llength $arguments] < 2} {
            error "$procname: not enough arguments\nUSAGE: $procname \[-name CMDNAME\] \[-context HELPCONTEXT\] OPTSPEC ARGUMENT"
        } elseif {[llength $arguments] > 2} {
            error "$procname: too many arguments: $arguments"
        }
    }

    ## @brief Iterate over a list of arrays.
    #
    # @param iter     Iterator variable.
    # @param lst      Elements for the interation
    # @param preamble Preamble body to be executed if list is not empty
    # @param body     Code to run in each iteration.
    proc foreach_preamble {iter lst preamble body} {
        if {[llength $lst]} {
            uplevel 1 $preamble
            uplevel 1 foreach [list $iter] [list $lst] [list $body]
        }
    }

    ## @brief Iterate over a list of arrays.
    #
    # @param iter     Iterator variable.
    # @param lst      Elements for the interation
    # @param preamble Preamble body to be executed if list is not empty
    # @param epilog   Epilog body to be executed after last iteration if list is not empty
    # @param body     Code to run in each iteration.
    proc foreach_preamble_epilog {iter lst preamble body epilog} {
        if {[llength $lst]} {
            uplevel 1 $preamble
            uplevel 1 foreach [list $iter] [list $lst] [list $body]
            uplevel 1 $epilog
        }
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
            uplevel 1 array unset $iter
        }
    }

    ## @brief Iterate over a list of arrays.
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param preamble Code that is execute if array is not empty
    # @param body Code to run in each iteration.
    proc foreach_array_preamble {iter array_list preamble body} {
        if {[llength $array_list]} {
            uplevel 1 $preamble
            uplevel 1 foreach_array [list $iter] [list $array_list] [list $body]
        }
    }

    ## @brief Iterate over a list of arrays and execute inbetween the joinbody.
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param body Code to run in each iteration.
    # @param joinbody Code to run inbetween each iteration
    proc foreach_array_join {iter array_list body joinbody} {
        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            uplevel 1 $body
            if {![is_last $array_list ${__iter}]} { uplevel 1 $joinbody }
            uplevel 1 array unset $iter
        }
    }

    ## @brief Iterate over a list of arrays and execute inbetween the joinbody.
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param body Code to run in each iteration.
    # @param preamble Code that is execute if array is not empty
    # @param joinbody Code to run inbetween each iteration
    proc foreach_array_preamble_join {iter array_list preamble body joinbody} {
        if {[llength $array_list]} {
            uplevel 1 $preamble
            uplevel 1 foreach_array_join [list $iter] [list $array_list] [list $body] [list $joinbody]
        }
    }

    ## @brief Iterate over a list of arrays and execute inbetween the joinbody.
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param body Code to run in each iteration.
    # @param preamble Code that is execute once before the iteration if the array is not empty
    # @param joinbody Code to run inbetween each iteration
    # @param epilog   Code that is execute  once after the iteration if the array is not empty
    proc foreach_array_preamble_epilog_join {iter array_list preamble body joinbody epilog} {
        if {[llength $array_list]} {
            uplevel 1 $preamble
            uplevel 1 foreach_array_join [list $iter] [list $array_list] [list $body] [list $joinbody]
            uplevel 1 $epilog
        }
    }

    ## @brief Iterate over a list of arrays meeting a condition.
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param condition Condition which must be met to execute body
    # @param body Code to run in each iteration.
    proc foreach_array_with {iter array_list condition body} {
        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            uplevel 1 if [list $condition] [list $body]
            uplevel 1 array unset $iter
        }
    }

    ## @brief Iterate over a list of arrays meeting a condition.
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param preamble Code that is execute if array is not empty
    # @param condition Condition which must be met to execute body
    # @param body Code to run in each iteration.
    proc foreach_array_preamble_with {iter array_list condition preamble body} {
        set do_iter "false"

        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            if {[uplevel 1 [list $condition]]} {
                set do_iter "true"
                break
            }
        }
        if {$do_iter} {
            uplevel 1 $preamble
            uplevel 1 foreach_array_with [list $iter] [list $array_list] [list $condition] [list $body]
        }
    }

    ## @brief Iterate over a list of arrays and execute inbetween the joinbody meeting a condition
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param condition Condition which must be met to execute body
    # @param body Code to run in each iteration.
    # @param joinbody Code to run inbetween each iteration
    proc foreach_array_join_with {iter array_list condition body joinbody} {
        set first_ele 1
        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            set cond [uplevel 1 expr [list $condition]]
            if {$cond} {
                if {$first_ele} {
                    uplevel 1 $joinbody
                } else {
                    set first_ele 1
                }
                uplevel 1 $body
            }
            uplevel 1 array unset $iter
        }
    }


    ## @brief Iterate over a list of arrays meeting a condition.
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param preamble Code that is execute if array is not empty
    # @param condition Condition which must be met to execute body
    # @param body Code to run in each iteration.
    # @param epilog Epilog body to be executed after last iteration if list is not empty
    proc foreach_array_preamble_epilog_with {iter array_list condition preamble body epilog} {
        set do_iter "false"

        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            if {[uplevel 1 expr [list $condition]]} {
                set do_iter "true"
                break
            }
        }
        if {$do_iter} {
            uplevel 1 $preamble
            uplevel 1 foreach_array_with [list $iter] [list $array_list] [list $condition] [list $body]
            uplevel 1 $epilog
        }
    }

    ## @brief Iterate over a list return true as soon as condition matches
    #
    # @param iter Iterator variable.
    # @param array_list List of arrays as list as obtained by [array get ...].
    # @param condition Condition which must be met
    proc foreach_array_contains {iter array_list condition} {
        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            set cond [uplevel 1 expr [list $condition]]
            if {$cond} {
                uplevel 1 array unset $iter
                return true;
            }
            uplevel 1 array unset $iter
        }
        return false;
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

    ## @brief Replacement list for adaption of signal names.
    #
    # @param module Module Object-ID for obtaining replacement list.
    #
    # @return Replacement list.
    proc adapt_replacement_list {module} {
        set signal_replace [list]

        foreach i_port [ig::db::get_ports -of $module -all] {
            set i_rep [list \
                [ig::db::get_attribute -object $i_port -attribute "signal"] \
                [ig::db::get_attribute -object $i_port -attribute "name"] \
            ]
            lappend signal_replace $i_rep
        }
        foreach i_decl [ig::db::get_declarations -of $module -all] {
            set i_rep [list \
                [ig::db::get_attribute -object $i_decl -attribute "signal"] \
                [ig::db::get_attribute -object $i_decl -attribute "name"] \
            ]
            lappend signal_replace $i_rep
        }

        return $signal_replace
    }

    ## @brief Adapt signalnames in a codesection object if adapt-attribute is set.
    #
    # @param codesection Codesection Object-ID.
    #
    # @return Modified codesection based on "adapt" property.
    proc adapt_codesection {codesection} {
        set do_adapt [ig::db::get_attribute -object $codesection -attribute "adapt" -default "none"]
        set code [ig::db::get_attribute -object $codesection -attribute "code"]
        if {$do_adapt eq "none"} {
            return $code
        }

        set origin [ig::db::get_attribute -object $codesection -attribute "origin" -default {}]

        # collect signals of module and replacement-name
        set parent_mod [ig::db::get_attribute -object $codesection -attribute "parent"]
        set signal_replace [adapt_replacement_list $parent_mod]

        # adapt signal-names
        if {$do_adapt eq "selective"} {
            set code_out [adapt_codesection_replace $code $signal_replace true $origin]
        } elseif {$do_adapt eq "all"} {
            set code_out [adapt_codesection_replace $code $signal_replace false $origin]
        } elseif {$do_adapt eq "signalcheck"} {
            # TODO: remove signalcheck part when no longer necessary
            set code_out1 [adapt_codesection_replace $code $signal_replace true]
            set code_out2 [adapt_codesection_replace [ig::db::get_attribute -object $codesection -attribute "checkcode"] $signal_replace false]

            if {$code_out1 eq $code_out2} {
                set code_out $code_out1
            } else {
                ig::log -warn -id "SCADp" "Signal [ig::db::get_attribute -object $codesection -attribute "signalname"] Deprecated to assign to adaptable signalname without using \"adapt-selective\" style with \"!\" after name ($origin)"
                set code_out $code_out2
            }
        } else {
            error "invalid adapt option: ${do_adapt}"
        }

        #set t_collect [clock microseconds]

        #set t_replaced [clock microseconds]
        #puts "t_collect: [expr {$t_collect - $t_start}]us, t_replace: [expr {$t_replaced - $t_collect}]us"

        return $code_out
    }

    ## @brief Adapt signalnames in a pin connection if adapt-attribute is set.
    #
    # @param pin Pin Object-ID.
    #
    # @return Modified connection value based on "adapt" property.
    proc adapt_pin_connection {pin} {
        set connection [ig::db::get_attribute -object $pin -attribute "connection"]
        set do_adapt [ig::db::get_attribute -object $pin -attribute "adapt" -default "none"]
        if {$do_adapt eq "none"} {
            return $connection
        }

        set parent_inst [ig::db::get_attribute -object $pin -attribute "parent"]
        set parent_mod  [ig::db::get_attribute -object $parent_inst -attribute "parent"]

        set signal_replace [adapt_replacement_list $parent_mod]

        if {$do_adapt eq "selective"} {
            set conn_out [adapt_codesection_replace $connection $signal_replace true]
        } elseif {$do_adapt eq "all"} {
            set conn_out [adapt_codesection_replace $connection $signal_replace false]
        }

        return $conn_out
    }

    ## @brief Helper for code adaption of @ref adapt_codesection.
    #
    # @param code Raw code input.
    # @param replace_list List of 2-element litsts with signal-names and replacements.
    # @param selective If true use selective syntax with "!" after signal names.
    # @param origin Origin of code for log message.
    #
    # @return adapted code.
    proc adapt_codesection_replace {code replace_list {selective true} {origin {}}} {
        # adapt signal-names
        if {$selective} {
            set re {^(.*?)(\m[[:alnum:]_]+\M)\!(.*)$}
        } else {
            set re {^(.*?)(\m[[:alnum:]_]+\M)(.*)$}
        }

        set code_out {}
        while {[string length $code] > 0} {
            if {[regexp $re $code m_whole m_pre m_var m_post]} {
                append code_out $m_pre
                set    code     $m_post
                set    idx      [lsearch -exact -index 0 $replace_list $m_var]
                if {$idx < 0} {
                    append code_out $m_var
                    if {$selective} {
                        ig::log -warn -id "TACAd" "selective adaption in codesection failed: signal \"$m_var\" not found ($origin)"
                    }
                } else {
                    append code_out [lindex $replace_list $idx 1]
                }
            } else {
                append code_out $code
                set code {}
            }
        }

        return $code_out
    }

    ## @brief Align dict of preprocessed codesection-data.
    #
    # @param cslist List of codesection dicts of form {name \<name\> object \<obj-id\> code_raw \<code\> code \<adapted code\>}
    #
    # @return modified cslist
    proc align_codesections {cslist} {
        set istart 0
        set csllen [llength $cslist]

        while {$istart < $csllen} {
            set align [ig::db::get_attribute -object [dict get [lindex $cslist $istart] object] -attribute "align" -default {}]
            if {$align eq {}} {
                incr istart
                continue
            }
            for {set istop [expr {$istart + 1}]} {$istop < $csllen} {incr istop} {
                set align_s [ig::db::get_attribute -object [dict get [lindex $cslist $istop] object] -attribute "align" -default {}]
                if {$align ne $align_s} {
                    break
                }
            }

            set midx 0
            for {set i $istart} {$i < $istop} {incr i} {
                set code [dict get [lindex $cslist $i] "code"]
                foreach l [split $code "\n"] {
                    set midx [expr {max ($midx, [string first $align $l])}]
                }
            }

            for {set i $istart} {$i < $istop} {incr i} {
                set code [dict get [lindex $cslist $i] "code"]
                set ll {}
                foreach l [split $code "\n"] {
                    set sidx [string first $align $l]
                    if {$sidx < 0} {
                        lappend ll $l
                    } else {
                        lappend ll [format "%-*s%s" $midx [string range $l 0 [expr {$sidx - 1}]] [string range $l $sidx end]]
                    }
                }
                lset cslist $i [dict replace [lindex $cslist $i] "code" [join $ll "\n"]]
            }

            set istart $istop
        }

        return $cslist
    }

    ## @brief Adapt code block indentation based on it's first line to a default indentation.
    #
    # @param code The code of the block.
    # @param default_indent The indentation the first code line should have.
    #
    # @return Reindented code.
    proc code_indent_fix {code {default_indent "    "}} {
        set code_lines [split $code "\n"]
        set file_indent 0
        set lead_subst {}
        set start_idx 0
        foreach line $code_lines {
            if {$line ne ""} {
                regexp {^\s+} $line lead_subst
                break
            }
            incr start_idx
        }
        set code_lines [lrange $code_lines $start_idx end]

        set new_code {}
        foreach line $code_lines {
            if {$lead_subst ne ""} {
                set line [regsub ^$lead_subst $line $default_indent]
            } else {
                set line "${default_indent}${line}"
            }
            set line [string trimright $line]
            lappend new_code "$line\n"
        }
        set code [join $new_code {}]

        return $code
    }

    ## @brief Get the signalid relate to the signalname with one module (mod_id)
    #
    # @param signalname Name of the signal to check.
    # @param mod_id Object-ID of the module to adapt for.
    #
    # @return Adapted signal name if found in specified module.
    proc get_signal_id_by_name {signalname mod_id} {
        foreach id [concat \
            [ig::db::get_ports -of $mod_id -all] \
            [ig::db::get_declarations -of $mod_id -all] \
        ] {
            if {[ig::db::get_attribute -object $id -attribute "signal"] eq $signalname} {
                return "$id"
            }
        }

        ig::log -warning "Signal $signalname not defined in module [ig::db::get_attribute -object $mod_id -attribute "name"]"
        return {}
    }

    ## @brief Adapt a signalname in given module to the local signal name.
    #
    # @param signalname Name of the signal to check.
    # @param mod_id Object-ID of the module to adapt for.
    #
    # @return Adapted signal name if found in specified module.
    proc adapt_signalname {signalname mod_id} {
        set sigid [get_signal_id_by_name ${signalname} ${mod_id}]

        if {$sigid ne ""} {
            return [ig::db::get_attribute -object $sigid -attribute "name"]
        } else {
            return $signalname
        }
    }

    ## @brief Count amount of newlines in a string.
    #
    # @param str the string.
    # @return number of newline characters in str.
    #
    # copied from: http://wiki.tcl.tk/4478
    proc string_count_nl str {
        return [expr {[string length $str]-[string length [string map {\n {}} $str]]}]
    }

    ## @brief Set varName to maximum of ($varName, $value)
    #
    # @param varName variable name to set
    # @param value value to compare against and set if larger than current value
    proc max_set {varName value} {
        upvar $varName var
        if {[uplevel info exists $varName]} {
            set var [expr {max ($var, $value)}]
        } else {
            set var $value
        }
    }

    ## @brief Get/Set implicit regfile address
    #
    # @param rfid regfile id
    # @param args optional value of address to be set
    # @return address
    proc regfile_next_addr {rfid args} {
        if {[llength $args] > 1} {
            log -error -abort "regfile_next_addr takes maximal two arguments."
        }

        if {[llength $args] == 1} {
            ig::db::set_attribute -obj $rfid -attribute "_save_reg_addr" -value [lindex $args 0]
        }

        return [ig::db::get_attribute -obj $rfid -attribute "_save_reg_addr" -default "0x0000"]
    }

    ## @brief Align regfile address
    #
    # @param base_addr base address to align
    # @param addr_align base address alignment
    # @param reg_align  align address to given number of registers
    # @return realigned address
    proc regfile_aligned_addr {base_addr addr_align reg_align} {
        set align [expr {$addr_align * $reg_align}]
        set rem   [expr {$base_addr % $align}]
        if {$rem == 0} {
            return $base_addr
        }
        set addr [expr {$base_addr + $align - $rem}]
        return $addr
    }

    ## @brief Get origin of where a command was invoked
    #
    # @param fstart relative frame to start looking for source file
    # @return the origin in form "file-basename:line"
    proc get_origin_here {{fstart -1}} {
        set origin {}

        set imin [expr {-[info frame]}]
        for {set i [expr {$fstart - 1}]} {$i > $imin} {incr i -1} {
            set fdict [info frame $i]
            if {[dict get $fdict type] eq "source"} {
                set filename [file tail [dict get $fdict file]]
                set line     [dict get $fdict line]
                set cmd      [split [dict get $fdict cmd] "\n"]
                if {[llength $cmd] > 1} {
                    set cmd "[lindex $cmd 0] (...)"
                } else {
                    set cmd [lindex $cmd 0]
                }
                set origin   "${filename}:${line} {${cmd}}"
                break
            }
        }

        return $origin
    }

    ## @brief Remove whitespace after comma
    #
    # @param s string to be modified
    # @return the value of the modified string
    proc remove_comma_ws {s} {
        set s [regsub -all {(\S),\s+} $s {\1,}]
        return $s
    }

    ## @brief Remove brackets { }
    #
    # @param arg variable name to be modified
    # @return the value of the modified variable
    proc remove_brackets {arg} {
        set retval [string trim $arg]
        if {([string index $retval 0] == "{") && ([string index $retval end] == "}")} {
            set retval [string range $retval 1 end-1]
        }
        return $retval
    }

    namespace export *
}

## @brief Return integer value of ceil(log2(x))
#
# @param x should be an integer > 0.
# @return int(ceil(log2(x)))
proc ::tcl::mathfunc::clog2 {x} {
    # simple version does not work due to floating point precision:
    #return [expr {int(ceil(log($x)/log(2)))}]

    if {$x <= 0} {error "cannot compute logarithm of $x"}
    if {![string is entier $x]} {
        set x [expr {entier(ceil($x)) - 1}]
    } else {
        incr x -1
    }

    set y 0

    while {$x > 0} {
        incr y
        set x [expr {$x >> 1}]
    }

    return $y
}

