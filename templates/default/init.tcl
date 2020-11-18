# template init script

proc template_data {userdata tdir} {
    set object [dict get $userdata "object"]

    set type [ig::db::get_attribute -object $object -attribute "type"]
    set name [ig::db::get_attribute -object $object -attribute "name"]

    if {$type eq "module"} {
        set parent [ig::db::get_attribute -object $object -attribute "parentunit" -default $name]
        set mode   [ig::db::get_attribute -object $object -attribute "mode"       -default "rtl"]
        set lang   [ig::db::get_attribute -object $object -attribute "language"]

        set gen_dummy_liberty [ig::db::get_attribute -object $object -attribute "gen_dummy_liberty" -default false]

        foreach {ilang itag itype idir iext lexcom} {
                verilog       vlog  wtf  verilog       v   {"/* " " */"}
                systemverilog svlog icgt systemverilog sv  {"/* " " */"}
                systemc       sc    wtf  systemc       h   {"/* " " */"}
                systemc       sc    wtf  systemc       cpp {"/* " " */"}
                systemc       shell wtf  verilog       v   {"/* " " */"}
        } {
            if {$lang eq $ilang} {
                add "${itag}-${iext}" $itype "${tdir}/${itag}/template.${itype}.${iext}" "units/${parent}/source/${mode}/${idir}/${name}.${iext}" $lexcom
            }
        }

        if {$gen_dummy_liberty} {
            # opcondition is mandatory, no default
            set opcondition [ig::db::get_attribute -object $object -attribute "opcondition"]
            add "dummy-liberty" wtf "${tdir}/dummy-liberty/template.wtf.lib" "units/${parent}/source/dummy-liberty/${name}_${opcondition}.lib" {"/* " " */"}
        }
    } elseif {$type eq "regfile"} {
        foreach {itag itype lexcom} {
            txt  wtf  {}
            csv  wtf  {}
            html icgt {"<!-- " " -->"}
            tex  icgt {"%"     "\n"}
            rst  wtf  {}
        } {
            add "rf-${itag}" $itype "${tdir}/rf/template.${itype}.${itag}" "doc/${itag}/${name}.${itag}"
        }

        add "rf-c.txt" wtf "${tdir}/rf/template.wtf.c.txt" "software/doc/regfile_access/${name}.txt" {}

        foreach {itag   itype iinf iext lexcom} {
                 soc    icgt  {}   h   {"/* " " */"}
                 host   icgt  {}   h   {"/* " " */"}
                 host   icgt  {}   cpp {"/* " " */"}
                 tcl    wtf   .tcl h   {"/* " " */"}
                 tcl    wtf   .tcl cpp {"/* " " */"}
                 python wtf   {}   py  {"#"    "\n"}
                 py     wtf   {}   py  {"#"    "\n"}
        } {
            add "rf-${itag}.${iext}" $itype "${tdir}/rf/template.${itype}.${itag}.${iext}" "software/${itag}/regfile_access/rf_${name}${iinf}.${iext}" $lexcom
        }
    }
}
