# template init script

# print template help, return nothing
proc template_args {} {
    #   <option>     <description>     <default value>  <callback for checking>
    return {}
}

# return list with {<tag> <template type> <path to template file> <template type> <output file>}
proc template_data {userdata tdir} {
    return [subst {
        "mk-prj" copy "${tdir}/Makefile.regression" "env/regression/Makefile.regression"
        "mk-reg" icgt "${tdir}/Makefile.template"   "regression/Makefile"
    }]
}

