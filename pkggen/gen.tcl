#!/usr/bin/tclsh

if {$::argc != 1} {
    puts "ERROR: Expected a package directory"
    exit 1
}

pkg_mkIndex [lindex $::argv 0] *.tcl *.so

