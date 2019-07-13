# template init script

#  return template arguments
proc template_args {} {
    #   <option>     <description>     <default value>  <check expression>
    return {
        "--unit"     "<unit-name>"     {}               {$value ne {}}
        "--testcase" "<testcase-name>" {}               {$value ne {}}
        "--srcset"   "<src-set-name>"  {rtl}            {$value ne {}}
    }
}

# return list with {<path to template file> <template type> <output file>}
proc template_data {userdata tdir} {
    set unit [dict get $userdata "--unit"]
    set tc   [dict get $userdata "--testcase"]
    set src  [dict get $userdata "--srcset"]

    return [subst {
        copy "${tdir}/Makefile.project.iverilog.template" "env/iverilog/Makefile.project.iverilog"
        icgt "${tdir}/Makefile.rtl.sources.template"      "units/${unit}/simulation/iverilog/common/Makefile.${src}.sources"
        copy "${tdir}/Makefile.iverilog.template"         "units/${unit}/simulation/iverilog/common/Makefile.iverilog"
        link "../common/Makefile.${src}.sources"          "units/${unit}/simulation/iverilog/${tc}/Makefile.rtl.sources"
        link "../common/Makefile.iverilog"                "units/${unit}/simulation/iverilog/${tc}/Makefile"
    }]
}

