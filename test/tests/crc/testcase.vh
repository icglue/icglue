
initial begin
    #(1000*CLKPERIOD);
    tb_check_failed;
    $display ("TIMEOUT");
    tb_final_check;
end
