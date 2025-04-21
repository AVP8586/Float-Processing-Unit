`timescale 1ns/1ps

module tb_reciprocal;
    localparam NEXP = 8;
    localparam NSIG = 7;

    reg [NEXP+NSIG:0] A;
    wire [NEXP+NSIG:0] Arecip;
    wire [5:0] recipFlags;
    
    // Instantiate DUT
    reciprocal #(.NEXP(NEXP), .NSIG(NSIG)) dut (
        .A(A),
        .Arecip(Arecip),
        .recipFlags(recipFlags)
    );
    
    // Helper function to extract sign, exponent, and significand
    function [23:0] decode_bfloat;
        input [NEXP+NSIG:0] val;
        reg sign;
        reg [NEXP-1:0] exp;
        reg [NSIG-1:0] sig;
        begin
            sign = val[NEXP+NSIG];
            exp = val[NSIG+NEXP-1:NSIG];
            sig = val[NSIG-1:0];
            decode_bfloat = {sign, exp, sig};
        end
    endfunction
    
    initial begin
        $display("===== Reciprocal Module Test (bfloat16) =====");
        $display("| Input (Binary) | Output (Binary) | Flags |");
        $display("|---------------|----------------|-------|");

        // Test 1: Reciprocal of 1.0 (0x3F80)
        A = 16'b0_01111111_0000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        // Test 2: Reciprocal of 2.0 (0x4000)
        A = 16'b0_10000000_0000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        // Test 3: Reciprocal of 0.5 (0x3F00)
        A = 16'b0_01111110_0000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        // Test 4: Reciprocal of 4.0 (0x4080)
        A = 16'b0_10000001_0000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        // Test 5: Reciprocal of 0.25 (0x3E80)
        A = 16'b0_01111101_0000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        // Test 6: Reciprocal of Infinity
        A = 16'b0_11111111_0000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        // Test 7: Reciprocal of Zero
        A = 16'b0_00000000_0000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        // Test 8: Reciprocal of NaN
        A = 16'b0_11111111_1000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        // Test 9: Reciprocal of negative number (-2.0)
        A = 16'b1_10000000_0000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        // Test 10: Reciprocal of subnormal number
        A = 16'b0_00000000_1000000; #10;
        $display("| %b | %b | %b |", A, Arecip, recipFlags);

        $display("==========================================");
        $finish;
    end
endmodule
