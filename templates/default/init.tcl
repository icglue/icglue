# template init script

proc template_attributes {userdata} {
    set object [dict get $userdata "object"]
    set attrs  [dict get $userdata "attributes"]

    set type [get_attribute -object $object -attribute "type"]

    set known_attrs {}

    if {$type eq "regfile"} {
        set known_attrs {
            accesscargs
            interface
            pad_to
            ports
            port_prefix
            regtypes
        }

        set rf_interfaces {"apb" "rf"}
        set rf_interface "apb"
        set rf_port_prefix {
            apb "apb"
            rf  "rf"
        }
        set rf_ports {
            apb {
                clk         {"%s_clk_i"     1}
                reset       {"%s_resetn_i"  1}
                addr        {"%s_addr_i"    $addrwidth}
                sel         {"%s_sel_i"     1}
                enable      {"%s_enable_i"  1}
                write       {"%s_write_i"   1}
                wdata       {"%s_wdata_i"   $datawidth}
                bytesel     {"%s_strb_i"    {($datawidth+7)/8}}
                prot        {"%s_prot_i"    3}
                prot_enable {"%s_prot_en_i" 1}
                rdata       {"%s_rdata_o"   $datawidth}
                ready       {"%s_ready_o"   1}
                error       {"%s_slverr_o"  1}
            }
            rf {
                clk         {"clk_%s_i"     1}
                reset       {"reset_%s_n_i" 1}
                addr        {"%s_addr_i"    $addrwidth}
                enable      {"%s_enable_i"  1}
                write       {"%s_write_i"   1}
                wdata       {"%s_wdata_i"   $datawidth}
                bytesel     {"%s_strb_i"    {($datawidth+7)/8}}
                prot        {"%s_prot_i"    3}
                prot_enable {"%s_prot_en_i" 1}
                rdata       {"%s_rdata_o"   $datawidth}
                ready       {"%s_ready_o"   1}
                error       {"%s_error_o"   1}
            }
        }
        set rf_regtypes {
            R   RS   RW   RWT
            CR  CRS  CRW  CRWT
            FCR FCRS FCRW FCRWT
        }

        # default attributes
        foreach {dattr dvalue} [subst {
            interface   $rf_interface
            pad_to      0
            accesscargs {}
            regtypes    [list $rf_regtypes]
        }] {
            if {![dict exists $attrs $dattr]} {
                dict set attrs $dattr $dvalue
            }
        }
        set interface [dict get $attrs "interface"]

        # check
        if {$interface ni $rf_interfaces} {
            ig::log -error "invalid regfile interface \"$interface\" for current template"
        }

        # depending attributes
        if {![dict exists $attrs "port_prefix"]} {
            dict set attrs "port_prefix" [dict get $rf_port_prefix $interface]
        }
        if {![dict exists $attrs "ports"]} {
            set ports_pre [dict get $rf_ports $interface]
            set prefix    [dict get $attrs "port_prefix"]

            set ports {}
            set addrwidth [get_attribute -object $object -attribute "addrwidth"]
            set datawidth [get_attribute -object $object -attribute "datawidth"]

            foreach k [dict keys $ports_pre] {
                lassign [dict get $ports_pre $k] f s

                set n [format $f $prefix]
                set s [expr $s]

                dict set ports $k [list $n $s]
            }

            dict set attrs "ports" $ports
        }
    } elseif {$type eq "module"} {
        set known_attrs {
            keepblocks
        }

        # default attributes
        foreach {dattr dvalue} [subst {
            keepblocks  false
        }] {
            if {![dict exists $attrs $dattr]} {
                dict set attrs $dattr $dvalue
            }
        }
    }

    foreach k [dict keys $attrs] {
        if {$k ni $known_attrs} {
            ig::log -id TIni -warn "unknown $type attribute $k"
        }
    }

    if {[llength $attrs] > 0} {
        set_attribute -object $object -attributes $attrs
    }
}

proc template_data {userdata tdir} {
    set object [dict get $userdata "object"]

    set type [get_attribute -object $object -attribute "type"]
    set name [get_attribute -object $object -attribute "name"]

    if {$type eq "module"} {
        set parent [get_attribute -object $object -attribute "parentunit" -default $name]
        set mode   [get_attribute -object $object -attribute "mode"       -default "rtl"]
        set lang   [get_attribute -object $object -attribute "language"]

        set gen_dummy_liberty [get_attribute -object $object -attribute "gen_dummy_liberty" -default false]

        foreach {ilang         itag  itype idir          text iext lexcom} {
                 verilog       vlog  wtf   verilog       v    v    {"/* " " */"}
                 systemverilog vlog  wtf   systemverilog v    sv   {"/* " " */"}
                 systemc       sc    wtf   systemc       h    h    {"/* " " */"}
                 systemc       sc    wtf   systemc       cpp  cpp  {"/* " " */"}
                 systemc       shell wtf   verilog       v    v    {"/* " " */"}
        } {
            if {$lang eq $ilang} {
                add "${itag}-${iext}" $itype "${tdir}/${itag}/template.${itype}.${text}" "units/${parent}/source/${mode}/${idir}/${name}.${iext}" $lexcom
            }
        }

        if {$gen_dummy_liberty} {
            # opcondition is mandatory, no default
            set opcondition [get_attribute -object $object -attribute "opcondition"]
            add "dummy-liberty" wtf "${tdir}/dummy-liberty/template.wtf.lib" "units/${parent}/source/dummy-liberty/${name}_${opcondition}.lib" {"/* " " */"}
        }
    } elseif {$type eq "regfile"} {
        foreach {itpfx itag itype lexcom} {
                 +     txt  wtf   {}
                 -     csv  wtf   {}
                 -     html icgt  {"<!-- " " -->"}
                 -     tex  icgt  {"%"     "\n"}
                 +     rst  wtf   {}
        } {
            add "${itpfx}rf-${itag}" $itype "${tdir}/rf/template.${itype}.${itag}" "doc/${itag}/${name}.${itag}" $lexcom
        }

        add "rf-c.txt" wtf "${tdir}/rf/template.wtf.c.txt" "software/doc/regfile_access/${name}.txt" {}

        foreach {itpfx itag   itype iinf iext lexcom} {
                 +     soc    wtf   {}   h    {"/* " " */"}
                 +     host   icgt  {}   h    {"/* " " */"}
                 +     host   icgt  {}   cpp  {"/* " " */"}
                 -     tcl    wtf   .tcl h    {"/* " " */"}
                 -     tcl    wtf   .tcl cpp  {"/* " " */"}
                 -     python wtf   {}   py   {"#"    "\n"}
                 -     py     wtf   {}   py   {"#"    "\n"}
        } {
            add "${itpfx}rf-${itag}.${iext}" $itype "${tdir}/rf/template.${itype}.${itag}.${iext}" "software/${itag}/regfile_access/rf_${name}${iinf}.${iext}" $lexcom
        }
    }
}
