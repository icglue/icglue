# template init script

# print template help, return nothing
proc template_args {} {
    #   <option>     <description>     <default value>  <callback for checking>
    return {}
}

proc template_data {userdata tdir} {
    add "mk-prj" copy "${tdir}/Makefile.regression" "env/regression/Makefile.regression"
    add "mk-reg" icgt "${tdir}/Makefile.template"   "regression/Makefile"
}

