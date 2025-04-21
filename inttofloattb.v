`timescale 1ns/1ps

module tb_cvtsw; 
    // Parameters
    parameter INTn = 32;
    parameter NEXP = 8;
    parameter NSIG = 7;
    parameter BIAS = 127;

    // Signals
    reg signed [INTn-1:0] in;
    wire [NEXP+NSIG:0] out;
    wire inexact;
    wire overflow;

    // DUT instantiation
    hp_cvtsw #(
        .INTn(INTn),
        .NEXP(NEXP),
        .NSIG(NSIG)
    ) dut (
        .in(in),
        .out(out),
        .inexact(inexact),
        .overflow(overflow)
    );

    // Helper function to format floating point for display
    function [8*50:1] fp_str;
        input [NEXP+NSIG:0] fp;
        reg sign;
        reg [NEXP-1:0] exp;
        reg [NSIG-1:0] sig;
        begin
            sign = fp[NEXP+NSIG];
            exp = fp[NEXP+NSIG-1:NSIG];
            sig = fp[NSIG-1:0];
            $sformat(fp_str, "%s %8b %7b", sign ? "-" : "+", exp, sig);
        end
    endfunction

    // Test sequence
    initial begin
        $dumpfile("cvtsw.vcd");
        $dumpvars(0, tb_cvtsw);
        
        // Test 1: Zero Conversion
        in = 0;
        #10;
        $display("Zero:     in=%0d → %s | inexact=%b", 
            in, fp_str(out), inexact);

        // Test 2: Exact positive integer
        in = 128;
        #10;
        $display("Exact+:   in=%0d → %s | inexact=%b", 
            in, fp_str(out), inexact);  

        // Test 3: Exact negative integer
        in = -64;
        #10;
        $display("Exact-:   in=%0d → %s | inexact=%b", 
            in, fp_str(out), inexact); 

        // Test 4: Inexact conversion (requires rounding)
        in = 12345;  // Needs rounding in significand
        #10;  
        $display("Inexact:  in=%0d → %s | inexact=%b", 
            in, fp_str(out), inexact);  

        // Test 5: Maximum 32-bit integer (stress test)
        in = 2147483647;  // 2^31-1
        #10;
        $display("Max int:  in=%0d → %s | overflow=%b", 
            in, fp_str(out), overflow);
            
        // Test 6: Minimum 32-bit integer
        in = 32'h80000000;  // -2^31
        #10;
        $display("Min int:  in=%0d → %s | overflow=%b", 
            in, fp_str(out), overflow);

        // Test 7: Powers of 2 (exact conversions)
        in = 16384;  // 2^14
        #10;
        $display("Power2:   in=%0d → %s | inexact=%b", 
            in, fp_str(out), inexact);

        // Test 8: Rounding test cases
        in = 15;  // 1111 → 1.111*2^3
        #10;
        $display("Round:    in=%0d → %s | inexact=%b", 
            in, fp_str(out), inexact);

        $finish;
    end
endmodule
