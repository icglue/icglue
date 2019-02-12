# template init script
# predefined variable in this script: template (template name)

# generate object output filename: arguments: {object} (object-identifier)
init::output_types $template {
    set objtype [ig::db::get_attribute -object $object -attribute "type"]
    if {$objtype eq "module"} {
        set lang [ig::db::get_attribute -object $object -attribute "language"]
        if {$lang eq "systemc"} {
            return {sc-h sc-cpp sc-v}
        }
        return $lang
    } elseif {$objtype eq "regfile"} {
        return {csv txt tex html h c hpp cpp soc.h}
    } else {
        ig::log -warning "No templates available for objects of type ${objtype}"
        return {}
    }
}

# return {<path to template file> <template type>}: arguments: {object type template_dir} (object-identifier, outputtype, path to this template's directory)
init::template_file $template {
    set objtype [ig::db::get_attribute -object $object -attribute "type"]
    if {$objtype eq "module"} {
        switch -regexp -matchvar m_matches -- $type {
            {^verilog$}         {return [list "${template_dir}/module.template.v"  "icgt"]}
            {^systemverilog$}   {return [list "${template_dir}/module.template.sv" "icgt"]}
            {^sc-(.*)$}         {return [list "${template_dir}/systemc/module.wtf.[lindex ${m_matches} 1]" "wtf"]}
            default {
                ig::log -error -abort "No template available for objecttype/outputtype ${objtype}/${type}"
            }
        }
    } elseif {$objtype eq "regfile"} {
        if {[file exist "${template_dir}/regfile.template.${type}"]} {
            return [list "${template_dir}/regfile.template.${type}" "icgt"]
        } elseif {[file exist "${template_dir}/regfile.wtf.${type}"]} {
            return [list "${template_dir}/regfile.wtf.${type}" "wtf"]
        } else {
            ig::log -error -abort "No template available for objecttype/outputtype ${objtype}/${type}"
        }
    } else {
        ig::log -error -abort "No template available for objects of type ${objtype}"
    }
}

# generate object output filename: arguments: {object type} (object-identifier, outputtype)
init::output_file $template {
    set output_dir_root "."
    if {[info exists ::env(ICPRO_DIR)]} {
        set output_dir_root "$::env(ICPRO_DIR)"
    }
    #TODO: rework type vs objtype
    set objtype     [ig::db::get_attribute -object $object -attribute "type"]
    set object_name [ig::db::get_attribute -object $object -attribute "name"]
    if {$objtype eq "module"} {
        set parent_unit [ig::db::get_attribute -object $object -attribute "parentunit" -default $object_name]
        if {[string match "tb_*" $object_name]} {
            set mode [ig::db::get_attribute -object $object -attribute "mode" -default "tb"]
        } else {
            set mode [ig::db::get_attribute -object $object -attribute "mode" -default "rtl"]
        }
        set lang [ig::db::get_attribute -object $object -attribute "language" -default "verilog"]
        set type_map {
            "verilog"       {verilog       v}
            "systemverilog" {systemverilog sv}
            "vhdl"          {vhdl          vhdl}
            "sc-h"          {systemc       h}
            "sc-cpp"        {systemc       cpp}
            "sc-v"          {verilog       v}
        }
        lassign [dict get $type_map $type] dir fileext

        return "${output_dir_root}/units/${parent_unit}/source/${mode}/${dir}/${object_name}.$fileext"
    } elseif {$objtype eq "regfile"} {
        if {$type in {h c hpp cpp}} {
            return "${output_dir_root}/units/regfile_access/source/behavioral/lib/rf_${object_name}.${type}"
        } else {
            set object_name     [ig::db::get_attribute -object $object -attribute "name"]
            set parent_mod      [ig::db::get_attribute -object $object -attribute "parent"]
            set parent_mod_name [ig::db::get_attribute -object $parent_mod -attribute "name"]
            set module_unit     [ig::db::get_attribute -object $parent_mod -attribute "parentunit" -default $parent_mod_name]
            return "${output_dir_root}/units/${module_unit}/doc/regfile/${object_name}.${type}"
        }
    } else {
        ig::log -warning "No output file pattern specified for objects of type ${objtype}"
        return "/dev/null"
    }
}

