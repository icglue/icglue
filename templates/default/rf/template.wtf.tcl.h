%(
set entry_list [regfile_to_arraylist $obj_id]
set rf_name [object_name $obj_id]

set idxnames [lindex [ig::db::get_attribute -object $obj_id -attribute "indices" -default {}] 0]
set idxnum   [llength $idxnames]

set header_name "rf_${rf_name}_tcl"

set rf_c_type        "rf_${rf_name}_t [string repeat "*" [expr {$idxnum > 0 ? $idxnum : 1}]]"
set rf_c_type_access [expr {$idxnum > 0 ? "." : "->"}]

%)
#ifndef __[string toupper "${header_name}"]_H__
#define __[string toupper "${header_name}"]_H__

#include <tcl.h>
#include "rf_${rf_name}.hpp"

#ifdef __cplusplus
extern "C" {
#endif

void rftcl_${rf_name}_register_commands (Tcl_Interp *interp, ${rf_c_type}rf);

#ifdef __cplusplus
}
#endif

#endif
%# vim: filetype=c_wooftemplate
