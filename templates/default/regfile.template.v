<%+
    ##  icglue - template regfile

    array set mod_data [ig::templates::preprocess::module_to_arraylist $obj_id]
    set entry_list     [ig::templates::preprocess::regfile_to_arraylist [lindex [ig::db::get_regfiles -of $obj_id] 0]]

    set port_data_maxlen_dir   [ig::aux::max_array_entry_len $mod_data(ports) vlog.direction]
    set port_data_maxlen_range [ig::aux::max_array_entry_len $mod_data(ports) vlog.bitrange]

    set decl_data_maxlen_type  [ig::aux::max_array_entry_len $mod_data(declarations) vlog.type]
    set decl_data_maxlen_range [ig::aux::max_array_entry_len $mod_data(declarations) vlog.bitrange]

    set param_data_maxlen_type [ig::aux::max_array_entry_len $mod_data(parameters) vlog.type]
    set param_data_maxlen_name [ig::aux::max_array_entry_len $mod_data(parameters) name]

    set maxlen_name            [ig::aux::max_array_entry_len $entry_list name]
    set maxlen_regname         0

    proc reset     {} { return "reset_n_ref_i" }
    proc clk       {} { return "clk_ref_i"     }
    proc rf_addr   {} { return "rf_addr_i";    }
    proc rf_w_data {} { return "rf_w_data_i"   }
    proc rf_r_data {} { return "rf_r_data_i"   }
    proc rf_w_en   {} { return "rf_en_i"       }
    proc r_data    {} { return "rf_r_data"     }

    proc param {} {
        return [uplevel 1 {format "RA_%-${maxlen_name}s" [string toupper $entry(name)]}]
    }
    proc addr_vlog {} {
        return [uplevel 1 {format "32'h%08X" $entry(address)}]
    }

    proc reg_comment {} {
        return [uplevel 1 {format "// %s @ %s" $entry(name)  $entry(address)}]
    }
    proc reg_name {} {
        return [uplevel 1 {format "reg_%-${maxlen_regname}s" $reg(name)}]
    }
    proc reg_range {} {
        return [uplevel 1 {format "%2d:%2d" [expr {$reg(width)-1}] 0 }]
    }
    proc reg_val {} {
        return [uplevel 1 {format "val_%s" $entry(name)}]
    }
    proc reg_entrybits {} {
        return [uplevel 1 {format "%2d:%2d" {*}[split $reg(entrybits) ":"]}]
    }

    proc signal_name {} {
        return [uplevel 1 {
                ig::aux::adapt_signalname $reg(signal) $obj_id
        }]
    }
    proc signal_entrybits {} {
        return [uplevel 1 {format "%2d:%2d" {*}[split $reg(signalbits) ":"]}]
    }

-%>

<%-= [ig::templates::get_pragma_content $pragma_data "keep" "head"] -%>

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
<%
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


<%+
    ###########################################
    ## <localparams>
-%>
    // Regfile ADDRESS definition:
<%+
    ig::aux::foreach_array entry $entry_list {
-%>
    localparam <%=[param]%> = <%=[addr_vlog]%>;
<%+
    }
    ## </localparams> ##
    ###########################################
-%>

<%+
    ###########################################
    ## <registers>
-%>
<%+
    ###########################################
    ## <definition>
-%>

    reg  [31: 0] <%=[r_data]%>;
<%-ig::aux::foreach_array entry $entry_list {-%>
    wire [31: 0] <%=[reg_val]%>;
<%+ ig::aux::foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} {-%>
    reg  [<%=[reg_range]-%>] <%=[reg_name]%>;
<%+ }+%>
<%+}-%>

<%+
    ## </definition> ##
    ###########################################
-%>

<%+ig::aux::foreach_array entry $entry_list {
    set maxlen_regname [ig::aux::max_array_entry_len $entry(regs) name]
-%>
    //////////////////////////////////////////////////////////////////////////////
    <%=[reg_comment]%>
    always @(posedge <%=[clk]%> or negedge <%=[reset]%>) begin
        if (<%=[reset]%> == 1'b0) begin
<%+ ig::aux::foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} {
-%>
            <%=[reg_name]%> <= <%=$reg(reset)%>;
<%+ }-%>
        end else begin
            if (<%=[rf_w_en]%> == 1'b1) begin
                <%=[reg_comment]%>
                if (<%=[rf_addr]%> == <%=[string trim [param]]%>) begin
<%+ ig::aux::foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} {-%>
                    <%=[reg_name]%> <= <%=[rf_w_data]%>[<%=[reg_entrybits]%>];
<%+ }-%>
                end
            end
        end
    end
<%+ ig::aux::foreach_array reg $entry(regs) { -%>
<%+   if {$reg(type) eq "RW"} { -%>
    assign <%=[signal_name]%>[<%=[signal_entrybits]%>] = <%=[string trim [reg_name]]%>;
<%+   } -%>
<%- } -%>

<%+ ig::aux::foreach_array reg $entry(regs) { -%>
<%+   if {$reg(type) eq "RW"} { -%>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=[string trim [reg_name]]%>;
<%+   } elseif {$reg(type) eq "R"} { -%>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=[string trim [signal_name]]%>[<%=[signal_entrybits]%>];
<%+   } elseif {$reg(type) eq "-"} { -%>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=$reg(width)%>'h0;
<%+   } -%>
<%- } -%>

<%+}-%>
<%+
    ## </registers> ##
    ###########################################
-%>

<%+
    ###########################################
    ## <output mux>
-%>
    always @(*) begin
        case (<%=[rf_addr]%>)
<%+
    ig::aux::foreach_array entry $entry_list {
-%>
            <%=[param]%>: <%=[r_data]%> = <%=[reg_val]%>;
<%+}-%>
            <%=[format "%-${maxlen_name}s   " {default}]%>: <%=[r_data]%> = 32'h0000_0000;
        endcase
    end
    assign <%=[rf_r_data]%> = <%=[r_data]%>;
<%+
    ## </output mux> ##
    ###########################################
-%>
endmodule

<%+ # vim: set filetype=verilog_template: -%>
