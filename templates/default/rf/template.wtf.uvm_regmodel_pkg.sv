/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */
%(
  set entry_list [regfile_to_arraylist $obj_id]
  set rf_dw [ig::db::get_attribute -object $obj_id -attribute datawidth]
  set rf_name [object_name $obj_id]
  set RF_NAME [string toupper $rf_name]

  proc write_mask {} {
    upvar entry(regs) regs
    variable maxlen_reg
    set mask 0
    foreach_array_with reg $regs {$reg(name) ne "-" && [write_reg]} {
      set mask [expr {$mask | (1<<(${reg(bit_high)}+1)) - (1<<(${reg(bit_low)}))}]
    }
    return [format "0x%08X" $mask]
  }
  proc uvm_access_type {} {
    upvar reg(type) type
    if {[regexp -nocase {W} $type]} {
      return "RW"
    } else {
      return "RO"
    }
  }
  proc external_reset_reg {} {
    upvar reg(name) name reg(type) type reg(object) obj
    if {$name ne "-"} {
      set val [ig::db::get_attribute -object $obj -attribute "rf_external_reset" -default "-"]
      if {$val ne "-"} {
        if {$type ne "RW"} {
          upvar entry(name) ename
          uplevel [list warn_rftp "The external_reset feature is only supported for RW registers - $ename:$name has type $type."]
        } else {
          #puts "$name"
          return true
        }
      }
    }
    return false
  }


  proc is_volatile {} {
    upvar reg(type) type
    if {![regexp -nocase {W} $type]} {
      # read-only
      return 0
    } elseif {$type eq "RW"} {
      return [expr {[uplevel external_reset_reg] ? 1 : 0}]
    } else {
      return 1
    }
  }

  proc reg_reset {} {
    upvar reg(reset) reset
    return [expr {$reset ne "-" ? "$reset" : "0"}]
  }
%)

package ${rf_name}_uvm_regmodel_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  /* DEFINE REGISTER CLASSES */
% foreach_array entry $entry_list {
  //--------------------------------------------------------------------
  // ${entry(name)}
  //--------------------------------------------------------------------
  class ${entry(name)}_t extends uvm_reg;
    `uvm_object_utils(${entry(name)}_t)

%   foreach_array_with reg [lreverse $entry(regs)] {$reg(name) ne "-"} {
    rand uvm_reg_field ${reg(name)}_f;

    covergroup ${reg(name)}_cov;
      option.per_instance = 1;
%     for {set pos 0} {$pos < $reg(width)} {incr pos} {
      [string toupper ${reg(name)}]$pos: coverpoint ${reg(name)}_f.value\[$pos\];
%     }
    endgroup: ${reg(name)}_cov

%   }

    function new(string name = "${entry(name)}_t");
      super.new(.name(name), .n_bits($rf_dw), .has_coverage(build_coverage(UVM_CVR_FIELD_VALS)));
      if (has_coverage(UVM_CVR_FIELD_VALS)) begin
%       foreach_array_with reg [lreverse $entry(regs)] {$reg(name) ne "-"} {
        ${reg(name)}_cov = new;
%       }
        void'(set_coverage(UVM_CVR_FIELD_VALS));
      end
    endfunction

    protected function void sample(uvm_reg_data_t data,
                                   uvm_reg_data_t byte_en,
                                   bit is_read,
                                   uvm_reg_map map);
      if (get_coverage(UVM_CVR_FIELD_VALS)) begin
%       foreach_array_with reg [lreverse $entry(regs)] {$reg(name) ne "-"} {
        ${reg(name)}_cov.sample();
%       }
      end
    endfunction: sample

    function void sample_values();
      super.sample_values();
      \$display("In sample_values coverage enable bit %0b", get_coverage(UVM_CVR_FIELD_VALS));
      if (get_coverage(UVM_CVR_FIELD_VALS)) begin
%       foreach_array_with reg [lreverse $entry(regs)] {$reg(name) ne "-"} {
        void'(${reg(name)}_cov.sample());
%       }
      end
    endfunction: sample_values

    virtual function void build();
%     foreach_array_with reg [lreverse $entry(regs)] {$reg(name) ne "-"} {
      ${reg(name)}_f = uvm_reg_field::type_id::create("${entry(name)}_${reg(name)}");
      ${reg(name)}_f.configure(
        .parent                  (this),
        .size                    (${reg(width)}),
        .lsb_pos                 (${reg(bit_low)}),
        .access                  ("[uvm_access_type]"),
        .volatile                ([is_volatile]),
        .reset                   ([reg_reset]),
        .has_reset               (1),
        .is_rand                 (0),
        .individually_accessible (0)
      );
      add_hdl_path_slice(
        .name   ("reg_${entry(name)}.bit_${reg(name)}"),
        .offset (${reg(bit_low)}),
        .size   (${reg(width)}),
        .kind   ("RTL")
      );
%     }
    endfunction: build
  endclass: ${entry(name)}_t

% }

  /* REGISTER ACCESS COVERGROUP */
  class ${RF_NAME}_APB_reg_access_wrapper extends uvm_object;
    `uvm_object_utils(${RF_NAME}_APB_reg_access_wrapper)

    covergroup ra_cov(string name) with function sample(uvm_reg_addr_t addr, bit is_read);
      option.per_instance = 1;
      option.name = name;

      ADDR: coverpoint addr {
%       foreach_array entry $entry_list {
        bins ${entry(name)}_b = {'h[format "%08x" $entry(address)]};
%       }
      }

      RW: coverpoint is_read {
        bins RD = {1};
        bins WR = {0};
      }

      ACCESS: cross ADDR, RW;
    endgroup: ra_cov

    function new(string name = "${RF_NAME}_APB_reg_access_wrapper");
      ra_cov = new(name);
    endfunction

    function void sample(uvm_reg_addr_t offset, bit is_read);
      ra_cov.sample(offset, is_read);
    endfunction: sample
  endclass: ${RF_NAME}_APB_reg_access_wrapper

  /* REGISTER MAP */
  class ${rf_name}_reg_block extends uvm_reg_block;
    `uvm_object_utils(${rf_name}_reg_block)

%   foreach_array entry $entry_list {
    rand ${entry(name)}_t ${entry(name)}_r;
%   }

    uvm_reg_map ${rf_name}_map; // Block map

    // Wrapped APB register access covergroup
    ${RF_NAME}_APB_reg_access_wrapper ${RF_NAME}_APB_access_cg;

    //--------------------------------------------------------------------
    // new
    //--------------------------------------------------------------------
    function new(string name = "${rf_name}_reg_block");
      super.new(name, build_coverage(UVM_CVR_ADDR_MAP));
    endfunction

    //--------------------------------------------------------------------
    // build
    //--------------------------------------------------------------------
    virtual function void build();

      if (has_coverage(UVM_CVR_ADDR_MAP)) begin
        ${RF_NAME}_APB_access_cg = ${RF_NAME}_APB_reg_access_wrapper::type_id::create("${RF_NAME}_APB_access_cg");
        void'(set_coverage(UVM_CVR_ADDR_MAP));
      end

%     foreach_array entry $entry_list {
      ${entry(name)}_r = ${entry(name)}_t::type_id::create("${rf_name}_${entry(name)}");
      ${entry(name)}_r.configure(this, null, "");
      ${entry(name)}_r.build();

%     }

      ${rf_name}_map = create_map("${rf_name}_map", 'h0, 4, UVM_LITTLE_ENDIAN, 1);

      default_map = ${rf_name}_map;

%     foreach_array entry $entry_list {
      ${rf_name}_map.add_reg(.rg(${entry(name)}_r), .offset([format "'h%x" $entry(address)]), .rights("RW"));
%     }

      lock_model();
    endfunction

    protected function void sample(uvm_reg_addr_t offset, bit is_read, uvm_reg_map  map);
    if (get_coverage(UVM_CVR_ADDR_MAP)) begin
      if (map.get_name() == "APB_map") begin
        void'(${RF_NAME}_APB_access_cg.sample(offset, is_read));
      end
    end
    endfunction: sample

  endclass
endpackage
%# vim: sw=2 ts=2 et
