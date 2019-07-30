# template init script

# return list with {<tag> <template type> <path to template file> <template type> <output file>}
proc template_data {userdata tdir} {
    set object [dict get $userdata "object"]

    set type [ig::db::get_attribute -object $object -attribute "type"]
    set name [ig::db::get_attribute -object $object -attribute "name"]

    set result [list]

    if {$type eq "module"} {
        set parent [ig::db::get_attribute -object $object -attribute "parentunit" -default $name]
        set mode   [ig::db::get_attribute -object $object -attribute "mode"       -default "rtl"]
        set lang   [ig::db::get_attribute -object $object -attribute "language"]

        foreach {ilang itag itype idir iext} {
                verilog       vlog  icgt verilog       v
                systemverilog svlog icgt systemverilog sv
                systemc       sc    wtf  systemc       h
                systemc       sc    wtf  systemc       cpp
                systemc       shell wtf  verilog       v
        } {
            if {$lang eq $ilang} {
                lappend result "${itag}-${iext}" $itype "${tdir}/${itag}/template.${itype}.${iext}" "units/${parent}/source/${mode}/${idir}/${name}.${iext}"
            }
        }
    } elseif {$type eq "regfile"} {
        foreach {itag itype} {
            txt  wtf
            csv  wtf
            html icgt
            tex  icgt
        } {
            lappend result "rf-${itag}" $itype "${tdir}/rf/template.${itype}.${itag}" "doc/${itag}/${name}.${itag}"
        }

        lappend result "rf-c.txt"    wtf  "${tdir}/rf/template.wtf.c.txt"     "software/doc/regfile_access/${name}.txt"

        foreach {itag itype iinf iext} {
            soc  icgt {}   h
            host icgt {}   h
            host icgt {}   cpp
            tcl  wtf  .tcl h
            tcl  wtf  .tcl cpp
        } {
            lappend result "rf-${itag}.${iext}" $itype "${tdir}/rf/template.${itype}.${itag}.${iext}" "software/${itag}/regfile_access/rf_${name}${iinf}.${iext}"
        }
    }

    return $result
}
