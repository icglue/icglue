
integer errors;
integer checks_done;
reg     offensive;

initial begin
    errors      = 0;
    checks_done = 0;
    offensive   = 1'b0;
end

task tb_final_check;
    begin
        $display ("");
        if (checks_done <= 0) begin
            if (offensive == 1'b1) begin
                $display (" #####   ####  ### ### ##  ## ##### #####   ");
                $display (" ##  ## ##  ## ####### ### ## ##    ##  ##  ");
                $display (" ##  ## ###### ## # ## ###### ####  ##  ##  ");
                $display (" ##  ## ##  ## ## # ## ## ### ##    ##  ##  ");
                $display (" #####  ##  ## ##   ## ##  ## ##### #####   ");
                $display ("");
            end
            /* unknown */
            $display (" ##  ## ##  ## ## ## ##  ##  ####  ##   ## ##  ##  ");
            $display (" ##  ## ### ## ####  ### ## ##  ## ## # ## ### ##  ");
            $display (" ##  ## ###### ###   ###### ##  ## ## # ## ######  ");
            $display (" ##  ## ## ### ####  ## ### ##  ## ####### ## ###  ");
            $display ("  ####  ##  ## ## ## ##  ##  ####   ## ##  ##  ##  ");
            $display ("");
            $display ("TBCHECK: UNWNOWN");
        end else if (errors == 0) begin
            if (offensive == 1'b1) begin
                $display (" #####  ##    ####   ####  #####  ##  ##         ##   ## ##### ##    ##      ");
                $display (" ##  ## ##   ##  ## ##  ## ##  ## ##  ##         ## # ## ##    ##    ##      ");
                $display (" #####  ##   ##  ## ##  ## ##  ##  ####          ## # ## ####  ##    ##      ");
                $display (" ##  ## ##   ##  ## ##  ## ##  ##   ##           ####### ##    ##    ##      ");
                $display (" #####  ##### ####   ####  #####    ##            ## ##  ##### ##### #####   ");
                $display ("");
            end
            /* passed */
            $display (" #####   ####   ##### ##### ##### #####   ");
            $display (" ##  ## ##  ## ##    ##     ##    ##  ##  ");
            $display (" #####  ######  ####  ####  ####  ##  ##  ");
            $display (" ##     ##  ##     ##    ## ##    ##  ##  ");
            $display (" ##     ##  ## ##### #####  ##### #####   ");
            $display ("");
            $display ("TBCHECK: PASSED");
        end else begin
            if (offensive == 1'b1) begin
                $display (" ##### ##  ##  ####  ## ## #### ##  ##  #####  ");
                $display (" ##    ##  ## ##  ## ####   ##  ### ## ##      ");
                $display (" ####  ##  ## ##     ###    ##  ###### ## ###  ");
                $display (" ##    ##  ## ##  ## ####   ##  ## ### ##  ##  ");
                $display (" ##     ####   ####  ## ## #### ##  ##  ####   ");
                $display ("");
            end
            /* failed */
            $display (" ##### ####  #### ##    ##### #####   ");
            $display (" ##   ##  ##  ##  ##    ##    ##  ##  ");
            $display (" #### ######  ##  ##    ####  ##  ##  ");
            $display (" ##   ##  ##  ##  ##    ##    ##  ##  ");
            $display (" ##   ##  ## #### ##### ##### #####   ");
            $display ("");
            $display ("TBCHECK: FAILED");
        end
        $finish;
    end
endtask

task tb_final_check_offensive;
    begin
        offensive = 1'b1;
        tb_final_check;
    end
endtask

task tb_check_failed;
    begin
        errors = errors+1;
        checks_done = checks_done+1;
    end
endtask

task tb_check_passed;
    checks_done = checks_done+1;
endtask
