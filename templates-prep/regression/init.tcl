# template init script

# print template help, return nothing
proc help {} {
    puts [join {
    } "\n"]
}

# check userdata, return true/false
proc check_userdata {userdata} {
    return true
}

# return list with {<path to template file> <template type> <output file>}
proc template_data {userdata template_dir} {
    set tf_map {
        "Makefile.regression.template" "icgt" "env/regression/Makefile.regression"
        "Makefile.template"            "icgt" "regression/Makefile"
    }

    set output_dir_root "."
    if {[info exists ::env(ICPRO_DIR)]} {
        set output_dir_root "$::env(ICPRO_DIR)"
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

