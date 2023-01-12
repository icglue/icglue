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

    # binary wrappers
    add "bin-cvc"     copy "${tdir}/bin/iccvc"                              "env/bin/iccvc"
    add "bin-iv"      copy "${tdir}/bin/iciverilog"                         "env/bin/iciverilog"
    add "bin-ius"     copy "${tdir}/bin/icius"                              "env/bin/icius"
    add "bin-xcelium" copy "${tdir}/bin/icxcelium"                          "env/bin/icxcelium"

    # project makefiles/helpers
    add "mk-prj-cds"  copy "${tdir}/env/Makefile.project.cdssim"            "env/simulation/Makefile.project.cdssim"
    add "mk-prj-cvc"  copy "${tdir}/env/Makefile.project.cvc"               "env/simulation/Makefile.project.cvc"
    add "mk-prj-iv"   copy "${tdir}/env/Makefile.project.iverilog"          "env/simulation/Makefile.project.iverilog"

    add "mk-prj-stc"  copy "${tdir}/env/Makefile.project.stimc"             "env/simulation/Makefile.project.stimc"
    add "mk-prj-gwv"  copy "${tdir}/env/Makefile.project.gtkwave"           "env/simulation/Makefile.project.gtkwave"

    add "mk-prj-sim"  copy "${tdir}/env/Makefile.project.simulation"        "env/simulation/Makefile.project.simulation"

    add "valg-sup"    copy "${tdir}/env/vvp.valgrind.supp"                  "env/simulation/vvp.valgrind.supp"

    # unit/testcase makefiles
    add "mk-src"      icgt "${tdir}/common/Makefile.rtl.sources.template"   "units/${unit}/simulation/generic/common/Makefile.rtl${srce}.sources"
    add "mk-iv"       copy "${tdir}/common/Makefile.simulation"             "units/${unit}/simulation/generic/common/Makefile.simulation"

    add "mk-tc-src"   link "../common/Makefile.rtl${srce}.sources"          "units/${unit}/simulation/generic/${tc}/Makefile.rtl.sources"
    add "mk-tc-iv"    link "../common/Makefile.simulation"                  "units/${unit}/simulation/generic/${tc}/Makefile"

    # verilog source file lists
    add "src-res"     copy "${tdir}/sources/res.vlog.sources.cmdf"          "units/${unit}/source/list/res.vlog.sources"
    add "src-rtl"     wtf  "${tdir}/sources/rtl.vlog.wtf.sources.cmdf"      "units/${unit}/source/list/rtl.vlog.sources"       .cmdf
    add "src-tb"      wtf  "${tdir}/sources/tb.vlog.wtf.sources.cmdf"       "units/${unit}/source/list/tb${srce}.vlog.sources" .cmdf

    add "src-sim-res" link "../../../../source/list/res.vlog.sources"       "units/${unit}/simulation/generic/common/sources${srce}/res.vlog.sources"
    add "src-sim-rtl" link "../../../../source/list/rtl.vlog.sources"       "units/${unit}/simulation/generic/common/sources${srce}/rtl.vlog.sources"
    add "src-sim-tb"  link "../../../../source/list/tb${srce}.vlog.sources" "units/${unit}/simulation/generic/common/sources${srce}/tb${srce}.vlog.sources"

    add "src-tc"      link "../common/sources${srce}"                       "units/${unit}/simulation/generic/${tc}/sources"
}

