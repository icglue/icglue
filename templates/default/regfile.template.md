<%
    #----------------------------------------#
    #  ^..^                                  #
    # ( oo )  )~                             #
    #   ,,  ,,                               #
    #----------------------------------------#
    # register file markup language template #
    #----------------------------------------#
%><%
    set register_list [regfile_to_arraylist $obj_id]
    foreach i_register $register_list {
        array set register $i_register
        foreach i_sreg $register(regs) {
            array set sreg $i_sreg
        }
    }

    # define header text
    set header { "Register Name" "Address" "Name" "Port" "Width" "Access" "Align" "Reset" "Description" }
    set collumn_width { 0 0 0 0 0 0 0 0 0 }

    set len_max_data(0)   [max_array_entry_len $register_list name      ]
    set len_max_data(1)   10
    set len_max_data(2)   [max_array_entry_len $register(regs) name      ]
    set len_max_data(3)   [max_array_entry_len $register(regs) signal    ]
    set len_max_data(4)   [max_array_entry_len $register(regs) width     ]
    set len_max_data(5)   [max_array_entry_len $register(regs) type      ]
    set len_max_data(6)   [max_array_entry_len $register(regs) entrybits ]
    set len_max_data(7)   [max_array_entry_len $register(regs) reset     ]
    set len_max_data(8)   [max_array_entry_len $register(regs) comment   ]
    set len_max_data(9) 0

    proc get_padding_size { width string } {
        set string_length [string length $string]
        set padding       [expr {$width - $string_length} ]

        return $padding
    }
%><%
    set num_collumn { 0 1 2 3 4 5 6 7 8 }
    foreach i_collumn $num_collumn {
        set tmp_string [lindex $header $i_collumn]
        set len_header [string length $tmp_string]

        if {$len_header >  $len_max_data($i_collumn)} {
            lset collumn_width $i_collumn $len_header
        } else {
            lset collumn_width $i_collumn $len_max_data($i_collumn)
        }
        set debug [lindex $collumn_width $i_collumn]
    }
%><%
    # generate header
    foreach i_collumn $num_collumn {
        set tmp_string [lindex $header $i_collumn]
        set len_header [string length $tmp_string]
        set padding [expr {[lindex $collumn_width $i_collumn] - $len_header} ]

        %><[format "| %s%${padding}s " $tmp_string "" ]><%
         if {$i_collumn == 8} {
             %>|<%
         }
    }
%>
<%
    %>| <%
    # generate header separator
    foreach i_collumn $num_collumn {
        set width [expr { [lindex $collumn_width $i_collumn]} ]

        for { set i 0} {$i < $width} {incr i} {
            %>-<%
        }
        %> | <%
    }
%>
<%
# generate register list
    foreach i_reg $register_list {
        array set reg $i_reg

        set sreg_idx 0
        foreach i_sreg $reg(regs) {
            array set sreg $i_sreg

            #start of line
            %>| <%
            foreach i_collumn $num_collumn {

               if {$i_collumn == 0} {
                   set width   [lindex $collumn_width $i_collumn]
                   set padding [get_padding_size $width $reg(name)]
                   if {$sreg_idx == 0 } {
                     %><[format "%s%${padding}s | " $reg(name) "" ]><%
                   } else {
                       %><[format "%${width}s | " ""]><%
                  }
               }
               if {$i_collumn == 1} {
                   set width   [lindex $collumn_width $i_collumn]
                   set padding [get_padding_size $width $reg(address)]
                   if {$sreg_idx == 0 } {
                      %><[format "0x%08x | " $reg(address)  ]><%
                   } else {
                       %><[format "%${width}s | " ""]><%
                  }
               }
               if {$i_collumn == 2} {
                   set width   [lindex $collumn_width $i_collumn]
                   set padding [get_padding_size $width $sreg(name)]
                   %><[format "%s%${padding}s | " $sreg(name) "" ]><%
               }

               if {$i_collumn == 3} {
                   set width   [lindex $collumn_width $i_collumn]
                   set padding [get_padding_size $width $sreg(signal)]
                   %><[format "%s%${padding}s | " $sreg(signal) "" ]><%
               }
               if {$i_collumn == 4} {
                   set width   [lindex $collumn_width $i_collumn]
                   set padding [get_padding_size $width $sreg(width)]
                  %><[format "%s%${padding}s | "  $sreg(width) "" ]><%
               }
               if {$i_collumn == 5} {
                   set width   [lindex $collumn_width $i_collumn]
                   set padding [get_padding_size $width $sreg(type)]
                  %><[format "%s%${padding}s | "  $sreg(type) ""]><%
               }
               if {$i_collumn == 6} {
                   set width   [lindex $collumn_width $i_collumn]
                   set padding [get_padding_size $width $sreg(entrybits)]
                  %><[format "%s%${padding}s | "  $sreg(entrybits) ""]><%
               }
               if {$i_collumn == 7} {
                   set width   [lindex $collumn_width $i_collumn]
                   set padding [get_padding_size $width $sreg(reset)]
                  %><[format "%s%${padding}s | "  $sreg(reset) ""]><%
               }
               if {$i_collumn == 8} {
                   set width   [lindex $collumn_width $i_collumn]
                   set padding [get_padding_size $width $sreg(comment)]
                  %><[format "%s%${padding}s | "  $sreg(comment)  "" ]><%
               }
        }
        %><%="\n"%><%
        incr sreg_idx
    }
    # generate register separator line
    %>| <%
    foreach i_collumn $num_collumn {
        set width [expr { [lindex $collumn_width $i_collumn]} ]

        for { set i 0} {$i < $width} {incr i} {
            %>-<%
        }
        %> | <%
    }
    %><%="\n"%><%
%><%
%><%    }
%>






