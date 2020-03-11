#!/usr/bin/env tclsh

#   Copyright (C) 2017-2020  Andreas Dixius, Felix Neumärker
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

namespace eval resources {
    variable data [dict create]
    variable ICPRO_DIR .

    proc parse_config_file {filename} {
        variable data
        variable ICPRO_DIR

        set f [open $filename r]
        set lines [split [read $f] "\n"]
        close $f

        foreach l $lines {
            if {[regexp {^\s*(#.*)?$} $l]} {
                # comment / empty
                continue
            } elseif {[regexp -expanded {
                ^\s*
                (\S+)
                \s*=\s*
                (\w+)
                \s*:\s*
                (\S*)
                \s*
                (\((\S*)\))?
                \s*$
                } $l m_all m_res m_type m_target m_st_unused m_subtarget]} {

                dict set data $m_res [list $m_type [subst -nocommands $m_target] $m_subtarget]
            } else {
                puts "ERROR: could not parse resource config line \"$l\""
            }
        }
    }

    proc parse_config {} {
        variable ICPRO_DIR

        # path
        set cfg_path .
        if {[info exists ::env(ICPRO_DIR)]} {
            set ICPRO_DIR $::env(ICPRO_DIR)
            set cfg_path  [file join $::env(ICPRO_DIR) resources]
        } else {
            set cfg_path  [file dirname [info script]]
            set ICPRO_DIR [file join $cfg_path ..]
        }

        # files
        foreach cfg {.resources.default.cfg .resources.local.cfg} {
            set filename [file join $cfg_path $cfg]

            if {[file exists $filename]} {
                parse_config_file $filename
            }
        }
    }

    proc list_resources {} {
        variable data

        foreach k [dict keys $data] {
            lassign [dict get $data $k] type target subtarget

            if {$subtarget ne {}} {set subtarget "::${subtarget}"}
            puts "$k ($type --> ${target}${subtarget})"
        }
    }

    namespace eval link {
        proc create {res trg subtrg} {
            puts "creating link $res"
            file link -symbolic $res $trg
        }

        proc check {res trg subtrg} {
            if {[catch {file link $res}]} {
                return false
            } else {
                return true
            }
        }

        proc update {res trg subtrg} {
            puts "updating link $res"
            file delete -force -- $res
            file link -symbolic $res $trg
        }
    }

    namespace eval git {
        # helpers
        variable remote_cache {}

        proc get_remote_data {{gitpath .}} {
            variable remote_cache

            if {[dict exists $remote_cache $gitpath]} {
                return [dict get $remote_cache $gitpath]
            }

            set remote_name    {}
            set remote_branch  {}
            set remote_default {}

            catch {
                set branchinfo [exec -ignorestderr -- git -C $gitpath branch -vv]

                foreach l [split $branchinfo "\n"] {
                    if {[regexp {^\*\s+(\S+)\s+(\S+)\s+\[(\S+)\/(\S+)(:.*)?\]\s+.*$} $l m_whole m_branch m_hash m_remote m_rbranch m_rel]} {
                        set remote_name   $m_remote
                        set remote_branch $m_rbranch
                        break
                    }
                }
                if {$remote_name eq {}} {break}

                set remote_url [exec -ignorestderr -- git -C $gitpath remote get-url $remote_name]

                set remote_def_data [exec -ignorestderr -- git -C $gitpath branch -r -l ${remote_name}/HEAD]
                if {[regexp {^\s*(.*)/HEAD\s*->\s*(.*)/(.*)\s*$} m_wholeb m_r1 m_r2 m_branch]} {
                    set remote_default $m_branch
                } else {
                    set remote_default master
                }
            }

            set result [list $remote_url $remote_branch $remote_default]
            dict set remote_cache $gitpath $result

            return $result
        }

        proc get_url {trg} {
            if {[string match "*:*" $trg]} {
                set url $trg
            } elseif {[string index $trg 0] eq "/"} {
                set url $trg
            } else {
                set gitpath [set [namespace parent]::ICPRO_DIR]

                lassign [get_remote_data $gitpath] remote_url

                if {$remote_url eq {}} {return {}}

                set idx_split [string last : $remote_url]
                set remote_host [string range $remote_url 0 $idx_split]
                set remote_path [lrange [split [string range $remote_url [expr {$idx_split + 1}] end] "/"] 0 end-1]
                set trg_path [split $trg "/"]

                foreach t $trg_path {
                    if {$t eq {..}} {
                        set remote_path [lrange $remote_path 0 end-1]
                    } else {
                        lappend remote_path $t
                    }
                }

                set url "${remote_host}[join $remote_path "/"]"
            }

            return $url
        }

        proc create {res trg subtrg} {
            set url [get_url $trg]

            puts "cloning repo $res"
            if {[catch {
                exec -ignorestderr -- git clone $url $res

                if {$subtrg ne {}} {
                    puts "checking out $subtrg in $res"
                    exec -ignorestderr -- git -C $res checkout $subtrg
                }
            }]} {
                puts "error cloning repository $url in $res"
            }
        }

        proc check {res trg subtrg} {
            if {![file isdirectory $res]} {
                return false
            }

            lassign [get_remote_data $res] remote_url remote_branch remote_default

            set trg_url [get_url $trg]

            if {$remote_url ne $trg_url} {
                return false
            }

            return true
        }

        proc update {res trg subtrg} {
            puts "updating repo $res"

            if {[catch {
                exec -ignorestderr -- git -C $res pull

                if {$subtrg ne {}} {
                    exec -ignorestderr -- git -C $res checkout $subtrg
                }
            }]} {
                puts "error updating repository in $res"
            }
        }
    }

    namespace eval svn {
        proc get_remote_data {path} {
            set op [pwd]
            cd $path

            if {[catch {exec -ignorestderr -- svn info --show-item url} url]} {
                set url {}
            }

            cd $op

            return $url
        }

        proc create {res trg subtrg} {
            puts "cloning repo $res"
            if {[catch {

                if {$subtrg ne {}} {
                    exec -ignorestderr -- svn checkout $trg $res -r $subtrg
                } else {
                    exec -ignorestderr -- svn checkout $trg $res
                }
            }]} {
                puts "error cloning repository $trg in $res"
            }
        }

        proc check {res trg subtrg} {
            if {![file isdirectory $res]} {
                return false
            }

            set url [get_remote_data $res]

            if {$url ne $trg} {
                return false
            }

            return true
        }

        proc update {res trg subtrg} {
            puts "updating repo $res"

            set op [pwd]
            cd $res

            if {[catch {
                if {$subtrg ne {}} {
                    exec -ignorestderr -- svn up -r $subtrg
                } else {
                    exec -ignorestderr -- svn up
                }
            }]} {
                puts "error updating repository in $res"
            }

            cd $op
        }
    }

    proc remove_resource {res {cause "of different type"}} {
        puts -nonewline stderr "Resource \"${res}\" ${cause} already exists. Delete existing? (y/N): "
        while {true} {
            set resp [read stdin 1]
            if {[string is boolean $resp]} {
                while {[read stdin 1] ne "\n"} {}
                return $resp
            } elseif {$resp in {{} "\n"}} {
                return false
            }
            puts -nonewline stderr "(y/N): "
        }
    }

    proc update_resource {type res target subtarget} {
        if {![namespace exists $type]} {
            puts "ERROR: resource \"$res\" of unsupported type \"$type\""
            return
        }

        # check + cleanup
        if {[file exists $res]} {
            if {[${type}::check $res $target $subtarget]} {
                ${type}::update $res $target $subtarget
                return
            } else {
                if {![remove_resource $res]} {return}
                file delete -force -- $res
            }
        }

        # if not existing or deleted previous files
        ${type}::create $res $target $subtarget
    }

    proc update_resources {args} {
        variable data

        if {[llength $args] == 0} {
            set args [dict keys $data]
        }

        foreach k $args {
            if {[dict exists $data $k]} {
                lassign [dict get $data $k] type target subtarget

                update_resource $type $k $target $subtarget
            } else {
                puts "ERROR: resource \"$k\" does not exist"
            }
        }
    }
}

proc print_help {} {
    puts "usage: $::argv0 (help | list | update \[RESOURCE ...\])"
}

proc main {} {
    set cmd ""
    if {$::argc == 0} {
        set cmd "list"
    } else {
        set cmd      [lindex $::argv 0]
        set cmd_args [lrange $::argv 1 end]
    }

    if {$cmd eq "help"} {
        print_help
        exit 0
    }

    resources::parse_config

    if {$cmd eq "list"} {
        resources::list_resources
    } elseif {$cmd eq "update"} {
        resources::update_resources {*}$cmd_args
    } else {
        puts "ERROR: unknown subcommand \"${cmd}\""
        print_help
        exit 1
    }
}

main

