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

proc template_data {userdata tdir} {
    set unit   [dict get $userdata "--unit"]
    set tc     [dict get $userdata "--testcase"]
    set srcext [dict get $userdata "--srcext"]
    set srce   {}
    if {$srcext ne {}} {set srce "-${srcext}"}

    add "mk-prj"      copy "${tdir}/Makefile.project.iverilog"              "env/iverilog/Makefile.project.iverilog"

    add "mk-src"      icgt "${tdir}/Makefile.rtl.sources.template"          "units/${unit}/simulation/iverilog/common/Makefile.rtl${srce}.sources"
    add "mk-iv"       copy "${tdir}/Makefile.iverilog"                      "units/${unit}/simulation/iverilog/common/Makefile.iverilog"

    add "mk-tc-src"   link "../common/Makefile.rtl${srce}.sources"          "units/${unit}/simulation/iverilog/${tc}/Makefile.rtl.sources"
    add "mk-tc-iv"    link "../common/Makefile.iverilog"                    "units/${unit}/simulation/iverilog/${tc}/Makefile"

    add "src-res"     copy "${tdir}/res.vlog.sources.cmdf"                  "units/${unit}/source/list/res.vlog.sources"
    add "src-rtl"     wtf  "${tdir}/rtl.vlog.wtf.sources.cmdf"              "units/${unit}/source/list/rtl.vlog.sources"
    add "src-tb"      wtf  "${tdir}/tb.vlog.wtf.sources.cmdf"               "units/${unit}/source/list/tb${srce}.vlog.sources"

    add "src-sim-res" link "../../../../source/list/res.vlog.sources"       "units/${unit}/simulation/iverilog/common/sources${srce}/res.vlog.sources"
    add "src-sim-rtl" link "../../../../source/list/rtl.vlog.sources"       "units/${unit}/simulation/iverilog/common/sources${srce}/rtl.vlog.sources"
    add "src-sim-tb"  link "../../../../source/list/tb${srce}.vlog.sources" "units/${unit}/simulation/iverilog/common/sources${srce}/tb${srce}.vlog.sources"

    add "src-tc"      link "../common/sources${srce}"                       "units/${unit}/simulation/iverilog/${tc}/sources"
}

