# template init script
# predefined variable in this script: template (template name)

# print template help, return nothing, arguments: {}
init::help $template {
    puts [join {
        "--unit     <unit-name>"
        "--testcase <testcase-name>"
    } "\n"]
}

# check userdata, return true/false: arguments: {userdata}
init::check_userdata $template {
    set result true
    foreach key {unit testcase} {
        if {![dict exists $userdata $key]} {
            ig::log -error "expected --${key}"
            set result false
        }
    }
    return $result
}

# return {<path to template file> <template type> <output file>}: arguments: {userdata template_dir}
init::template_data $template {
    set tf_map {
        "Makefile.project.iverilog.template" "icgt" "env/iverilog/Makefile.project.iverilog"
        "Makefile.rtl.sources.template"      "icgt" "units/%s/simulation/iverilog/common/Makefile.rtl.sources"
        "Makefile.iverilog.template"         "icgt" "units/%s/simulation/iverilog/common/Makefile.iverilog"
        "../common/Makefile.rtl.sources"     "link" "units/%s/simulation/iverilog/%s/Makefile.rtl.sources"
        "../common/Makefile.iverilog"        "link" "units/%s/simulation/iverilog/%s/Makefile"
    }

    set output_dir_root "."
    if {[info exists ::env(ICPRO_DIR)]} {
        set output_dir_root "$::env(ICPRO_DIR)"
    }

    set unit [dict get $userdata unit]
    set tc   [dict get $userdata testcase]

    set result [list]
    foreach {i_tfile i_format i_ofile} $tf_map {
        if {$i_format ne "link"} {
            set i_tfile "${template_dir}/${i_tfile}"
        }

        set i_ofile "${output_dir_root}/[format $i_ofile $unit $tc]"

        lappend result [list $i_tfile $i_format $i_ofile]
    }

    return $result
}

