# template init script

# print template help, return nothing
proc template_args {} {
    #   <option>     <description>     <default value>  <callback for checking>
    return {}
}

# return list with {<path to template file> <template type> <output file>}
proc template_data {userdata tdir} {
    return [subst {
        copy "${tdir}/Makefile.regression" "env/regression/Makefile.regression"
        icgt "${tdir}/Makefile.template"   "regression/Makefile"
    }]
}

