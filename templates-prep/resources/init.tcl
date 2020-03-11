# template init script

# print template help, return nothing
proc template_args {} {
    #   <option>     <description>     <default value>  <callback for checking>
    return {}
}

proc template_data {userdata tdir} {
    add "scr-res" copy "${tdir}/resources.tcl" "resources/resources"
    add "cfg-def" copy "${tdir}/default.cfg"   "resources/.resources.default.cfg"
    add "cfg-loc" copy "${tdir}/local.cfg"     "resources/.resources.local.cfg"
    add "git-ign" copy "${tdir}/gitignore"     "resources/.gitignore"
}

