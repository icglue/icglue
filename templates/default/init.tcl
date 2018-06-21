# template init script
# predefined variable in this script: template (template name)

# generate object output filename: arguments: {object} (object-identifier)
init::output_types $template {
    set objtype [ig::db::get_attribute -object $object -attribute "type"]
    if {$objtype eq "module"} {
        return {verilog}
    } elseif {$objtype eq "regfile"} {
        return {csv html}
    } else {
        ig::log -warning "no templates available for objects of type ${objtype}"
        return {}
    }
}

# return path to template file: arguments: {object type template_dir} (object-identifier, outputtype, path to this template's directory)
init::template_file $template {
    set objtype [ig::db::get_attribute -object $object -attribute "type"]
    if {$objtype eq "module"} {
        if {$type eq "verilog"} {
            return "${template_dir}/module.template.v"
        } else {
            ig::log -error -abort "no template available for objecttype/outputtype ${objtype}/${type}"
        }
    } elseif {$objtype eq "regfile"} {
        if {$type eq "csv"} {
            return "${template_dir}/regfile.template.csv"
        } elseif {$type eq "html"} {
            return "${template_dir}/regfile.template.html"
        } else {
            ig::log -error -abort "no template available for objecttype/outputtype ${objtype}/${type}"
        }
    } else {
        ig::log -error -abort "no template available for objects of type ${objtype}"
    }
}

# generate object output filename: arguments: {object type} (object-identifier, outputtype)
init::output_file $template {
    #TODO: rework type vs objtype
    set objtype [ig::db::get_attribute -object $object -attribute "type"]
    if {$objtype eq "module"} {
        set object_name [ig::db::get_attribute -object $object -attribute "name"]
        set parent_unit [ig::db::get_attribute -object $object -attribute "parentunit" -default $object_name]
        if {[string match "tb_*" $object_name]} {
            set mode [ig::db::get_attribute -object $object -attribute "mode" -default "tb"]
        } else {
            set mode [ig::db::get_attribute -object $object -attribute "mode" -default "rtl"]
        }
        set lang [ig::db::get_attribute -object $object -attribute "language" -default "verilog"]
        return "./units/${parent_unit}/source/${mode}/${lang}/${object_name}.v"
    } elseif {$objtype eq "regfile"} {
        set object_name     [ig::db::get_attribute -object $object -attribute "name"]
        set parent_mod      [ig::db::get_attribute -object $object -attribute "parent"]
        set parent_mod_name [ig::db::get_attribute -object $parent_mod -attribute "name"]
        set module_unit     [ig::db::get_attribute -object $parent_mod -attribute "parentunit" -default $parent_mod_name]
        return "./units/${module_unit}/doc/regfile/${object_name}.${type}"
    } else {
        ig::log -warning "no output file pattern specified for objects of type ${objtype}"
        return "/dev/null"
    }
}

# generate object default header: arguments: {object type} (object-identifier, outputtype)
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

