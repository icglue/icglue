# template init script
# predefined variable in this script: template (template name)

# generate object output filename: arguments: {object} (object identifier)
init::output_types $template {
    set type [ig::db::get_attribute -object $object -attribute "type"]
    if {$type eq "module"} {
        return {verilog}
    } elseif {$type eq "regfile"} {
        return {csv}
    } else {
        ig::log -warning "no templates available for objects of type ${type}"
        return {}
    }
}

# return path to template file: arguments: {object template_dir} (object identifier, path to this template's directory)
init::template_file $template {
    set type [ig::db::get_attribute -object $object -attribute "type"]
    if {$type eq "module"} {
        if { [llength [ig::db::get_regfiles -of $object]] } {
            return "${template_dir}/regfile.template.v"
        } else {
            return "${template_dir}/module.template.v"
        }
    } elseif {$type eq "regfile"} {
        return "${template_dir}/regfile.template.csv"
    } else {
        ig::log -error -abort "no template available for objects of type ${type}"
    }
}

# generate object output filename: arguments: {object} (object identifier)
init::output_file $template {
    set type [ig::db::get_attribute -object $object -attribute "type"]
    if {$type eq "module"} {
        set object_name [ig::db::get_attribute -object $object -attribute "name"]
        set parent_unit [ig::db::get_attribute -object $object -attribute "parentunit" -default $object_name]
        if {[string match "tb_*" $object_name]} {
            set mode [ig::db::get_attribute -object $object -attribute "mode" -default "tb"]
        } else {
            set mode [ig::db::get_attribute -object $object -attribute "mode" -default "rtl"]
        }
        set lang [ig::db::get_attribute -object $object -attribute "language" -default "verilog"]
        return "./units/${parent_unit}/source/${mode}/${lang}/${object_name}.v"
    } elseif {$type eq "regfile"} {
        set object_name     [ig::db::get_attribute -object $object -attribute "name"]
        set parent_mod      [ig::db::get_attribute -object $object -attribute "parent"]
        set parent_mod_name [ig::db::get_attribute -object $parent_mod -attribute "name"]
        set module_unit     [ig::db::get_attribute -object $parent_mod -attribute "parentunit" -default $parent_mod_name]
        return "./units/${module_unit}/doc/regfile/${object_name}.csv"
    } else {
        ig::log -warning "no output file pattern specified for objects of type ${type}"
        return "/dev/null"
    }
}

# generate object default header: arguments: {object} (object identifier)
init::default_header $template {
    set result "
/*
 * Module: [ig::db::get_attribute -object $object -attribute "name"]
 * Author: 
 * E-Mail: 
 */
"

    return $result
}

