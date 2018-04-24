package provide ICGlue 0.0.1

namespace eval ig::vlog {
    proc bitrange {size} {
        if {[string is integer $size]} {
            if {$size == 1} {
                return ""
            } else {
                return "\[[expr {$size-1}]:0\]"
            }
        } else {
            return "\[$size-1:0\]"
        }
    }

    proc obj_bitrange {obj} {
        set size [ig::db::get_attribute -object $obj -attribute "size"]
        return [bitrange $size]
    }

    proc port_dir {port} {
        set dir [ig::db::get_attribute -object $port -attribute "direction"]
        if {$dir eq "input"} {return "input"}
        if {$dir eq "output"} {return "output"}
        if {$dir eq "bidirectional"} {return "inout"}
        return ""
    }

    proc param_type {param} {
        if {[ig::db::get_attribute -object $param -attribute "local"]} {
            return "localparam"
        } else {
            return "parameter"
        }
    }

    proc declaration_type {decl} {
        if {[ig::db::get_attribute -object $decl -attribute "default_type"]} {
            return "wire"
        } else {
            return "reg"
        }
    }
}
