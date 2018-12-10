#%Module1.0

#------------------------------------------------------------------------
set tool_name_version [split [module-info name] /]
set tool_name         [lindex $tool_name_version 0]
set tool_version      [lindex $tool_name_version 1]

#------------------------------------------------------------------------
set tool_root  "/opt/${tool_name}/${tool_version}"

#------------------------------------------------------------------------
proc ModulesHelp { } {
    puts stderr "Loads ICGlue Library for scripted HDL generation"
}

#------------------------------------------------------------------------
module-whatis "\tadds ${tool_name} v${tool_version} to the environment"

#------------------------------------------------------------------------
# only one active version at a time:
conflict $tool_name

#------------------------------------------------------------------------
if { ([module-info mode load] || [module-info mode switch2]) } {
    if { ! [ file isdirectory $tool_root ] } {
        puts stderr "\nERROR: package ${tool_name} v${tool_version} is not installed!"
        exit 1
    }
    if {[module-info shell] eq "zsh"} {
        puts "compdef _gnu_generic icglue"
        puts "compdef _gnu_generic icsng2icglue"
    }
}

#------------------------------------------------------------------------
if {(![info exists ::env(MANPATH)]) || ($::env(MANPATH) eq "")} {
    if {![catch {exec manpath} manpath]} {
        prepend-path MANPATH $manpath
    }
}
prepend-path PATH       "${tool_root}/bin"
prepend-path MANPATH    "${tool_root}/share/man"
#prepend-path TCLLIBPATH "${tool_root}/lib/icglue"

#------------------------------------------------------------------------

#vim: syntax=tcl
