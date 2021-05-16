# template init script

#  return template arguments
proc template_args {} {
    #   <option>     <description>     <default value>  <check expression>
    return {
        "--unit"     "<unit-name>"     {}               {$value ne {}}
    }
}

proc template_data {userdata tdir} {
    set unit [dict get $userdata "--unit"]

    add "mk-prj"      copy "${tdir}/Makefile.project.symbiyosys"       "env/symbiyosys/Makefile.project.symbiyosys"

    add "mk-sby"      wtf  "${tdir}/Makefile.wtf"                      "units/${unit}/formalverification/symbiyosys/Makefile"
    add "cfg-sby"     icgt "${tdir}/verify.sby.template"               "units/${unit}/formalverification/symbiyosys/verify.sby"

    add "src-res"     copy "${tdir}/res.vlog.sources.cmdf"             "units/${unit}/source/list/res.vlog.sources"
    add "src-rtl"     wtf  "${tdir}/rtl.vlog.wtf.sources.cmdf"         "units/${unit}/source/list/rtl.vlog.sources" .cmdf
    add "src-fv"      wtf  "${tdir}/fv.vlog.wtf.sources.cmdf"          "units/${unit}/source/list/fv.vlog.sources"  .cmdf

    add "src-fv-res"  link "../../../source/list/res.vlog.sources"  "units/${unit}/formalverification/symbiyosys/sources/res.vlog.sources"
    add "src-fv-rtl"  link "../../../source/list/rtl.vlog.sources"  "units/${unit}/formalverification/symbiyosys/sources/rtl.vlog.sources"
    add "src-fv-tb"   link "../../../source/list/fv.vlog.sources"   "units/${unit}/formalverification/symbiyosys/sources/fv.vlog.sources"
}

