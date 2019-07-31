# template init script

#  return template arguments
proc template_args {} {
    #   <option>     <description>       <default value>  <callback for checking>
    return {
        "--unit"     "<unit-name>"       {}               {$value ne {}}
        "--suffix"   "<optional suffix>" {}               {}
    }
}


# return list with {<tag> <template type> <path to template file> <template type> <output file>}
proc template_data {userdata tdir} {
    set unit   [dict get $userdata "--unit"]
    set suffix [dict get $userdata "--suffix"]
    if {$suffix ne {}} {set suffix "-${suffix}"}

    add "mk-prj"       copy "${tdir}/Makefile.project.lint.verilator" "env/verilator/Makefile.project.lint.verilator"

    add "mk-src"       icgt "${tdir}/Makefile.rtl.sources.template"   "units/${unit}/lint/verilator${suffix}/Makefile.rtl.sources"
    add "mk-vltr"      icgt "${tdir}/Makefile.verilator.template"     "units/${unit}/lint/verilator${suffix}/Makefile"

    add "src-res"      copy "${tdir}/res.vlog.sources.cmdf"           "units/${unit}/source/list/res.vlog.sources"
    add "src-rtl"      wtf  "${tdir}/rtl.vlog.wtf.sources.cmdf"       "units/${unit}/source/list/rtl.vlog.sources"

    add "src-lint-res" link "../../../source/list/res.vlog.sources"   "units/${unit}/lint/common/sources${suffix}/res.vlog.sources"
    add "src-lint-rtl" link "../../../source/list/rtl.vlog.sources"   "units/${unit}/lint/common/sources${suffix}/rtl.vlog.sources"

    add "src-run"      link "../common/sources${suffix}"              "units/${unit}/lint/verilator${suffix}/sources"
}

