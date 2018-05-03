# template init script
# predefined variable: template (template name)

# return path to template file: arguments: {module template_dir} (module identifier, path to this template's directory)
init::template_file $template {
    return "${template_dir}/module.template.v"
}

# generate module output filename: arguments: {module} (module identifier)
init::module_file $template {
    set module_name [ig::db::get_attribute -object $module -attribute "name"]
    set parent_unit [ig::db::get_attribute -object $module -attribute "parentunit" -default $module_name]
    if {[string match "tb_*" $module_name]} {
        set mode [ig::db::get_attribute -object $module -attribute "mode" -default "tb"]
    } else {
        set mode [ig::db::get_attribute -object $module -attribute "mode" -default "rtl"]
    }
    set lang [ig::db::get_attribute -object $module -attribute "language" -default "verilog"]
    return "./units/${parent_unit}/source/${mode}/${lang}/${module_name}.v"
}

# generate module default header: arguments: {module} (module identifier)
init::default_header $template {
    set result "
/*
 * Module: [ig::db::get_attribute -object $module -attribute "name"]
 * Author: 
 * E-Mail: 
 */
"

    return $result
}

