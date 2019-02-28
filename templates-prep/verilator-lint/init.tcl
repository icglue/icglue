# template init script

# print template help, return nothing
proc help {} {
    puts [join {
        "--unit   <unit-name>"
        "--suffix <optional suffix>"
    } "\n"]
}

# check userdata, return true/false
proc check_userdata {userdata} {
    set result true
    foreach key {unit} {
        if {![dict exists $userdata $key]} {
            ig::log -error "expected --${key}"
            set result false
        }
    }
    return $result
}

# return list with {<path to template file> <template type> <output file>}
proc template_data {userdata template_dir} {
    set tf_map {
        "Makefile.project.lint.verilator.template" "icgt" "env/verilator/Makefile.project.lint.verilator"
        "Makefile.rtl.sources.template"            "icgt" "units/%s/lint/verilator%s/Makefile.rtl.sources"
        "Makefile.verilator.template"              "icgt" "units/%s/lint/verilator%s/Makefile"
    }

    set output_dir_root "."
    if {[info exists ::env(ICPRO_DIR)]} {
        set output_dir_root "$::env(ICPRO_DIR)"
    }

    set unit [dict get $userdata unit]
    set sfx  ""
    if {[dict exists $userdata suffix]} {
        set sfx [dict get $userdata suffix]
    }

    set result [list]
    foreach {i_tfile i_format i_ofile} $tf_map {
        if {$i_format ne "link"} {
            set i_tfile "${template_dir}/${i_tfile}"
        }

        set i_ofile "${output_dir_root}/[format $i_ofile $unit $sfx]"

        lappend result [list $i_tfile $i_format $i_ofile]
    }

    return $result
}

