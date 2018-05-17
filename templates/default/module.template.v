<%
    # tcl header
    array set mod_data [ig::templates::preprocess::module_to_arraylist $obj_id]

    set port_data_maxlen_dir   [ig::aux::max_array_entry_len $mod_data(ports) vlog.direction]
    set port_data_maxlen_range [ig::aux::max_array_entry_len $mod_data(ports) vlog.bitrange]

    set decl_data_maxlen_type  [ig::aux::max_array_entry_len $mod_data(declarations) vlog.type]
    set decl_data_maxlen_range [ig::aux::max_array_entry_len $mod_data(declarations) vlog.bitrange]

    set param_data_maxlen_type [ig::aux::max_array_entry_len $mod_data(parameters) vlog.type]
    set param_data_maxlen_name [ig::aux::max_array_entry_len $mod_data(parameters) name]
-%>

<%= [ig::templates::get_pragma_content $pragma_data "keep" "head"] -%>


module <%= $mod_data(name) -%> (
<%
    # module port list
    foreach i_port $mod_data(ports) {
        array set port $i_port
-%>
    <%= $port(name) -%>
<%      if {![ig::aux::is_last $mod_data(ports) $i_port]} { -%>,<%
        } -%>

<%  } -%>
);

<%
    # module parameters
    foreach i_param $mod_data(parameters) {
        array set param $i_param
-%>
<%=     [format "    %-${param_data_maxlen_type}s " $param(vlog.type)] -%>
<%=     [format "%-${param_data_maxlen_name}s" $param(name)] -%>
 = <%=  $param(value) -%>
;
<%  } -%>
<%= [ig::templates::get_pragma_content $pragma_data "keep" "parameters"] -%>


<%
    # module port details
    foreach i_port $mod_data(ports) {
        array set port $i_port
-%>
<%=     [format "    %-${port_data_maxlen_dir}s " $port(vlog.direction)] -%>
<%=     [format "%${port_data_maxlen_range}s " $port(vlog.bitrange)] -%>
<%=     $port(name) -%>
;
<%  } -%>


<%
    # module declarations
    foreach i_decl $mod_data(declarations) {
        array set decl $i_decl
-%>
<%=     [format "    %-${decl_data_maxlen_type}s " $decl(vlog.type)] -%>
<%=     [format "%${decl_data_maxlen_range}s " $decl(vlog.bitrange)] -%>
<%=     $decl(name) -%>
;
<%  } -%>
<%= [ig::templates::get_pragma_content $pragma_data "keep" "declarations"] -%>


<%
    # submodule instanciations
    foreach i_inst $mod_data(instances) {
        array set inst $i_inst
        set i_params_maxlen_name [ig::aux::max_array_entry_len $inst(parameters) name]
        set i_pins_maxlen_name   [ig::aux::max_array_entry_len $inst(pins) name]
-%>

    <%= $inst(module.name) -%>
<%      if {$inst(hasparams)} {
-%>
 #(<%
            foreach i_param $inst(parameters) {
                array set param $i_param
-%>

        .<%= [format "%-${i_params_maxlen_name}s" $param(name)] -%> (<%= $param(value) %>)<%
                if {![ig::aux::is_last $inst(parameters) $i_param]} {
-%>
,
<%-
                }
            }
-%>

    )<%
        } -%> <%= $inst(name) %> (
<%
        foreach i_pin $inst(pins) {
            array set pin $i_pin
-%>
        .<%= [format "%-${i_pins_maxlen_name}s" $pin(name)] -%> (<%= $pin(connection) %>)<%
            if {![ig::aux::is_last $inst(pins) $i_pin]} {
-%>
,
<%
            }
        }
-%>

    );
<%  } -%>

<%= [ig::templates::get_pragma_content $pragma_data "keep" "instances"] -%>

<%
    # code sections
    foreach i_cs $mod_data(code) {
        array set cs $i_cs
-%>

<%=     $cs(code) -%>

<%  } -%>

<%= [ig::templates::get_pragma_content $pragma_data "keep" "code"] -%>


endmodule

<% # vim: set filetype=verilog_template: -%>
