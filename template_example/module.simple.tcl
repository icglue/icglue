#!/usr/bin/tclsh

package require ICGlue 0.0.1

#ig::logger -level D -linenumber

ig::templates::add_template_dir "../../templates"
ig::templates::load_template "default"

if {$::argc != 1} {
    ig::log -error "Expected one input file"
    exit 1
}
set gen_source [lindex $::argv 0]

if {[string match "*.sng" $gen_source] || [string match "*.icsng" $gen_source]} {
    ig::sng::parse_file $gen_source
} elseif {[string match "*.tcl" $gen_source]} {
    source $gen_source
} else {
    ig::log -error "Unknown input file suffix for $gen_source"
    exit 1
}

# generate modules
foreach i_module [ig::db::get_modules -all] {
    if {![ig::db::get_attribute -object $i_module -attribute "resource"]} {
        ig::log -info "generating module $i_module"
        ig::templates::write_module $i_module
    }
}
