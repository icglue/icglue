%(
set entry_list [regfile_to_arraylist $obj_id]
set rf_name [object_name $obj_id]

set idxnames [lindex [ig::db::get_attribute -object $obj_id -attribute "indices" -default {}] 0]
set idxnum   [llength $idxnames]

set header_name "rf_${rf_name}_tcl"

set rf_c_type        "rf_${rf_name}_t [string repeat "*" [expr {$idxnum > 0 ? $idxnum : 1}]]"
set rf_c_type_access [expr {$idxnum > 0 ? "." : "->"}]

set lbrc "{"
set rbrc "}"

%)

#include "rf_${rf_name}.tcl.h"
#include <string.h>

static int rf_${rf_name} (ClientData client_data, Tcl_Interp *interp, int tcl_argc, Tcl_Obj * const *tcl_argv);
static inline void ckfree_if_needed (int *count, Tcl_Obj ***objs);

void rftcl_${rf_name}_register_commands (Tcl_Interp *interp, ${rf_c_type}rf)
{
    Tcl_CreateObjCommand (interp, "rf_${rf_name}", rf_${rf_name}, (void *) rf, NULL);
}

static inline void ckfree_if_needed (int *count, Tcl_Obj ***objs)
{
    if (*count != 0) {
        ckfree (*objs);

        *objs  = NULL;
        *count = 0;
    }
}

static int rf_${rf_name} (ClientData client_data, Tcl_Interp *interp, int tcl_argc, Tcl_Obj * const *tcl_argv)
{
    ${rf_c_type}rf = (${rf_c_type}) client_data;

    const int mode_wordread  = 0;
    const int mode_wordwrite = 1;
    const int mode_regread   = 2;
    const int mode_regwrite  = 3;
    const int mode_regmodify = 4;

    char *entry = NULL;
    int  mode   = -1;

% set rfidx {}
% foreach idx $idxnames {
%   append rfidx "\[idx_${idx}\]"
    int idx_${idx} = 0;
% }
% set rfacc "rf${rfidx}${rf_c_type_access}"

    const Tcl_ArgvInfo arg_table\[\] = {
% foreach idx $idxnames {
        {TCL_ARGV_INT,      "-${idx}",         NULL,                                  (void *)&idx_${idx}, "${idx} index",             NULL},
% }
        {TCL_ARGV_STRING,   "-entry",          NULL,                                  (void *)&entry, "the name of the regfile entry", NULL},

        {TCL_ARGV_CONSTANT, "-mode-wordread",  (void *) (uintptr_t) (mode_wordread),  (void *)&mode,  "read whole entry as word",                                      NULL},
        {TCL_ARGV_CONSTANT, "-mode-wordwrite", (void *) (uintptr_t) (mode_wordwrite), (void *)&mode,  "write whole entry as word",                                     NULL},
        {TCL_ARGV_CONSTANT, "-mode-regread",   (void *) (uintptr_t) (mode_regread),   (void *)&mode,  "read individual register(s)",                                   NULL},
        {TCL_ARGV_CONSTANT, "-mode-regwrite",  (void *) (uintptr_t) (mode_regwrite),  (void *)&mode,  "write individual register(s) - unused = default value",         NULL},
        {TCL_ARGV_CONSTANT, "-mode-regmodify", (void *) (uintptr_t) (mode_regmodify), (void *)&mode,  "write individual register(s) - unused = write read back value", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    Tcl_Obj **tcl_argv_rem = NULL;
    int result = Tcl_ParseArgsObjv (interp, arg_table, &tcl_argc, tcl_argv, &tcl_argv_rem);
    if (result != TCL_OK) {
        ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
        return result;
    }

    if (mode < 0) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("rf_${rf_name}: no mode specified (one of -mode-(wordread|wordwrite|regread|regwrite|regmodify)).", -1));
        ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
        return TCL_ERROR;
    }

    if (entry == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("rf_${rf_name}: no regfile entry specified.", -1));
        ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
        return TCL_ERROR;
    }

% set efirst true
% foreach_array entry $entry_list {
%   if {$efirst} {
%     set efirst false
%     set ifexpr "if"
%   } else {
%     set ifexpr "${rbrc} else if"
%   }
    ${ifexpr} (strcmp (entry, "${entry(name)}") == 0) {
        if (mode == mode_wordread) {
            if (tcl_argc > 1) {
                Tcl_SetObjResult (interp, Tcl_NewStringObj ("rf_${rf_name}: too many arguments for word-read.", -1));
                ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
                return TCL_ERROR;
            }
            rf_data_t res = ${rfacc}_${entry(name)}_word;
            Tcl_SetObjResult (interp, Tcl_NewLongObj (res));
        } else if (mode == mode_wordwrite) {
            if (tcl_argc != 2) {
                Tcl_SetObjResult (interp, Tcl_NewStringObj ("rf_${rf_name}: wrong number of arguments for word-write.", -1));
                ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
                return TCL_ERROR;
            }
            long val;
            if (Tcl_GetLongFromObj (interp, tcl_argv_rem\[1\], &val) != TCL_OK) {
                ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
                return TCL_ERROR;
            }
            rf_data_t wval = val;
            ${rfacc}_${entry(name)}_word = wval;
        } else if (mode == mode_regread) {
            ${rf_name}_${entry(name)}_t rval = ${rfacc}${entry(name)};
            Tcl_Obj *reslist = Tcl_NewListObj (0, NULL);

            for (int i = 1; i < tcl_argc; i++) {
                const char *ireg = Tcl_GetString (tcl_argv_rem\[i\]);
%   set rfirst true
%   foreach_array reg $entry(regs) {
%     if {$reg(name) in {- {}}} {continue}
%     if {$rfirst} {
%       set rfirst false
%       set ifexpr "if"
%     } else {
%       set ifexpr "${rbrc} else if"
%     }
                ${ifexpr} (strcmp (ireg, "${reg(name)}") == 0) {
                    if (Tcl_ListObjAppendElement (interp, reslist, Tcl_NewLongObj (rval.${reg(name)})) != TCL_OK) {
                        Tcl_DecrRefCount (reslist);
                        ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
                        return TCL_ERROR;
                    }
%   }
%   if {! $rfirst} {
                } else {
%   }
                    Tcl_Obj *res = Tcl_NewStringObj ("rf_${rf_name}: invalid register ", -1);
                    Tcl_AppendStringsToObj (res, ireg, " for entry ", entry, ".", NULL);
                    Tcl_SetObjResult (interp, res);
                    Tcl_DecrRefCount (reslist);
                    ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
                    return TCL_ERROR;
%   if {! $rfirst} {
                }
%   }
            }
            Tcl_SetObjResult (interp, reslist);
        } else {
            if ((tcl_argc % 2) != 1) {
                Tcl_SetObjResult (interp, Tcl_NewStringObj ("rf_${rf_name}: expecdet even number of arguments for reg-write/modify.", -1));
                ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
                return TCL_ERROR;
            }

            ${rf_name}_${entry(name)}_t wval;

            if (mode == mode_regwrite) {
%   foreach_array reg $entry(regs) {
%     if {$reg(reset) in {- {}}} {continue}
%     set prstval [ig::vlog::parse_value $reg(reset)]
%     if {! [lindex $prstval 0]} {
%       ig::log -warn "tcl regfile access: register ${entry(name)}.${reg(name)}: could not parse reset value \"${reg(reset)}\" - code might behave unexpectedly for regwrite mode."
%       continue
%     }
                wval.${reg(name)} = [lindex $prstval 1];
%   }
            } else {
                wval = ${rfacc}${entry(name)};
            }

            for (int i = 1; i < tcl_argc; i++) {
                const char *ireg = Tcl_GetString (tcl_argv_rem\[i++\]);
                long ival;
                if (Tcl_GetLongFromObj (interp, tcl_argv_rem\[i\], &ival) != TCL_OK) {
                    ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
                    return TCL_ERROR;
                }
%   set rfirst true
%   foreach_array reg $entry(regs) {
%     if {$reg(name) in {- {}}} {continue}
%     if {$rfirst} {
%       set rfirst false
%       set ifexpr "if"
%     } else {
%       set ifexpr "${rbrc} else if"
%     }
                ${ifexpr} (strcmp (ireg, "${reg(name)}") == 0) {
                    wval.${reg(name)} = ival;
%   }
%   if {! $rfirst} {
                } else {
                    Tcl_Obj *res = Tcl_NewStringObj ("rf_${rf_name}: invalid register ", -1);
                    Tcl_AppendStringsToObj (res, ireg, " for entry ", entry, ".", NULL);
                    Tcl_SetObjResult (interp, res);
                    ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
                    return TCL_ERROR;
%   }
%   if {! $rfirst} {
                }
%   }
            }

            ${rfacc}${entry(name)} = wval;
        }
% }
% if {! $efirst} {
    } else {
% }
        Tcl_Obj *res = Tcl_NewStringObj ("rf_${rf_name}: invalid regfile entry: ", -1);
        Tcl_AppendStringsToObj (res, entry, ".", NULL);
        Tcl_SetObjResult (interp, res);
        ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
        return TCL_ERROR;
% if {! $efirst} {
    }
% }

    ckfree_if_needed (&tcl_argc, &tcl_argv_rem);
    return TCL_OK;
}


%# vim: filetype=c_wooftemplate
