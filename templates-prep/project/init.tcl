# template init script

# print template help, return nothing
proc help {} {
    puts [join {
        "--path <project-path>"
    } "\n"]
}

# check userdata, return true/false
proc check_userdata {userdata} {
    return true
}

# return list with {<path to template file> <template type> <output file>}
proc template_data {userdata template_dir} {
    set tf_map {
        "env.template.sh"      "icgt" "env.sh"
        "vlog/tb_selfcheck.vh" "icgt" "global_src/verilog/tb_selfcheck.vh"
        "stimc/tb_selfcheck.h" "icgt" "global_src/stimc/tb_selfcheck.h"
        "stimc/tb_selfcheck.c" "icgt" "global_src/stimc/tb_selfcheck.c"
    }

    set output_dir_root "."

    if {[dict exists $userdata path]} {
        set output_dir_root [dict get $userdata path]
    }

    set result [list]
    foreach {i_tfile i_format i_ofile} $tf_map {
        if {$i_format ne "link"} {
            set i_tfile "${template_dir}/${i_tfile}"
        }

        set i_ofile "${output_dir_root}/${i_ofile}"

        lappend result [list $i_tfile $i_format $i_ofile]
    }

    return $result
}

