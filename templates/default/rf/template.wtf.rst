%(
    set register_list [regfile_to_arraylist $obj_id]

    set separator_v      "|"
    set separator_h      "-"
    set separator_h_head "="
    set crossing         "+"

    set rf_name [object_name $obj_id]
    set rf_name_len [string length $rf_name]

    # columns
    set columns [list entryname address name signal width type entrybits reset comment]

    set header(entryname) "Register Name"
    set header(address)   "Address"
    set header(name)      "Name"
    set header(signal)    "Port"
    set header(width)     "Width"
    set header(type)      "Access"
    set header(entrybits) "Align"
    set header(reset)     "Reset"
    set header(comment)   "Description"

    set format(entryname) "%-*s"
    set format(address)   "0x%08x"
    set format(name)      "%-*s"
    set format(signal)    "%-*s"
    set format(width)     "%*d"
    set format(type)      "%-*s"
    set format(entrybits) "%*s"
    set format(reset)     "%*s"
    set format(comment)   "%-*s"

    # column size
    max_set len_max_data(address)   10
    max_set len_max_data(entryname) [max_array_entry_len $register_list name]
    max_set len_max_data(type)      0

    foreach_array entry $register_list {
        foreach c [lrange $columns 2 end] {
            max_set len_max_data($c) [max_array_entry_len $entry(regs) $c]
        }
    }

    max_set len_max_data(type) [expr {$len_max_data(type) + 2}]

    foreach c $columns {
        max_set len_max_data($c) [string length $header($c)]
    }

    # separators
    set sepline $crossing
    set entry_sepline $separator_v
    set sephead $crossing
    foreach c $columns {
        # header separation
        append sephead       "[string repeat $separator_h_head [expr {$len_max_data($c) + 2}]]${crossing}"

        # register word separation
        append sepline       "[string repeat $separator_h      [expr {$len_max_data($c) + 2}]]${crossing}"

        # field separation
        set space [string repeat " " [expr {$len_max_data($c) + 2}]]
        switch $c {
            entryname {
                append entry_sepline "${space}${separator_v}"
            }
            address {
                append entry_sepline "${space}${crossing}"
            }
            default {
                append entry_sepline "[string repeat $separator_h [expr {$len_max_data($c) + 2}]]${crossing}"
            }
        }
    }

    proc reg_type {} {
        upvar entry(protected) protected reg(name) name reg(type) type
        if {$name eq "-"} {
            return "-"
        }
        return [format "%s$type%s" {*}[expr {$protected ? {( )} : {"" ""}}]]
    }

    # header content
    set header_line [list]
    foreach c $columns {
        lappend header_line [format "%-*s" $len_max_data($c) $header($c)]
    }
%)
%# Document header
${rf_name}
[string repeat "=" $rf_name_len]

%# Table header
${sepline}
| [join $header_line " ${separator_v} "] |
${sephead}
%# Table content
%(
    foreach_array entry $register_list {
        set first_entry true
        foreach_array_join reg $entry(regs) {
            set line [list]
            if {$first_entry} {
                # fill name and address columns in the first row
                lappend line [format $format(entryname) $len_max_data(entryname) $entry(name)]
                lappend line [format $format(address)                            $entry(address)]
            } else {
                # fill remaining name and address columns with spaces
                lappend line [format "%*s" $len_max_data(entryname) ""]
                lappend line [format "%*s" $len_max_data(address)   ""]
            }
            foreach c [lrange $columns 2 end] {
                if {$c eq "type"} {
                    lappend line [format $format($c) $len_max_data($c) [reg_type]]
                } else {
                    lappend line [format $format($c) $len_max_data($c) $reg($c)]
                }
            }
            echo "${separator_v} [join $line " ${separator_v} "] ${separator_v}\n"
            set first_entry false
        } {
            echo "${entry_sepline}\n"
        }
        echo "${sepline}\n"
    }
%)
