# template init script

# print template help, return nothing
proc template_args {} {
    #   <option>     <description>     <default value>  <check expression>
    return {
        "--path"     "<project-path>"  "./"             {}
    }
}

# return list with {<path to template file> <template type> <output file>}
proc template_data {userdata tdir} {
    set proj_root [file normalize [dict get $userdata "--path"]]

    return [subst {
        copy "${tdir}/env.sh"               "${proj_root}/env.sh"
        copy "${tdir}/vlog/tb_selfcheck.vh" "${proj_root}/global_src/verilog/tb_selfcheck.vh"
        copy "${tdir}/stimc/tb_selfcheck.h" "${proj_root}/global_src/stimc/tb_selfcheck.h"
        copy "${tdir}/stimc/tb_selfcheck.c" "${proj_root}/global_src/stimc/tb_selfcheck.c"
    }]
}
