# template init script

#  return template arguments
proc template_args {} {
    #   <option>     <description>     <default value>  <check expression>
    return {
        "--unit"     "<unit-name>"     {}               {$value ne {}}
        "--testcase" "<testcase-name>" {}               {$value ne {}}
        "--srcext"   "<src-ext-name>"  {}               {}
    }
}

# return list with {<path to template file> <template type> <output file>}
proc template_data {userdata tdir} {
    set unit   [dict get $userdata "--unit"]
    set tc     [dict get $userdata "--testcase"]
    set srcext [dict get $userdata "--srcext"]
    set srce   {}
    if {$srcext ne {}} {set srce "-${srcext}"}

    return [subst {
        copy "${tdir}/Makefile.project.iverilog"              "env/iverilog/Makefile.project.iverilog"

        icgt "${tdir}/Makefile.rtl.sources.template"          "units/${unit}/simulation/iverilog/common/Makefile.rtl${srce}.sources"
        copy "${tdir}/Makefile.iverilog"                      "units/${unit}/simulation/iverilog/common/Makefile.iverilog"

        link "../common/Makefile.rtl${srce}.sources"          "units/${unit}/simulation/iverilog/${tc}/Makefile.rtl.sources"
        link "../common/Makefile.iverilog"                    "units/${unit}/simulation/iverilog/${tc}/Makefile"

        copy "${tdir}/res.vlog.sources.cmdf"                  "units/${unit}/source/list/res.vlog.sources"
        wtf  "${tdir}/rtl.vlog.wtf.sources.cmdf"              "units/${unit}/source/list/rtl.vlog.sources"
        wtf  "${tdir}/tb.vlog.wtf.sources.cmdf"               "units/${unit}/source/list/tb${srce}.vlog.sources"

        link "../../../../source/list/res.vlog.sources"       "units/${unit}/simulation/iverilog/common/sources${srce}/res.vlog.sources"
        link "../../../../source/list/rtl.vlog.sources"       "units/${unit}/simulation/iverilog/common/sources${srce}/rtl.vlog.sources"
        link "../../../../source/list/tb${srce}.vlog.sources" "units/${unit}/simulation/iverilog/common/sources${srce}/tb${srce}.vlog.sources"

        link "../common/sources${srce}"                       "units/${unit}/simulation/iverilog/${tc}/sources"
    }]
}

