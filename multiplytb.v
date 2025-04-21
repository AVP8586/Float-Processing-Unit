`include "class.sv"
`include "round.v"
`timescale 1ns/1ps

module tb_hp_mul;
    localparam NEXP = 8;
    localparam NSIG = 7;

    reg [NEXP+NSIG:0] a, b;
    wire [NEXP+NSIG:0] p;
    wire [5:0] bfFlags;
    wire [4:0] exception;

    // Instantiate DUT
    hp_mul #(.NEXP(NEXP), .NSIG(NSIG)) dut (
        .a(a),
        .b(b),
        .p(p),
        .bfFlags(bfFlags),
        .exception(exception)
    );

    // Helper function to display floating point values
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

    // Helper function to display flags
    function [8*20:1] flag_str;
        input [5:0] flags;
        begin
            if (flags[0]) flag_str = "NORMAL";
            else if (flags[1]) flag_str = "SUBNORMAL";
            else if (flags[2]) flag_str = "ZERO";
            else if (flags[3]) flag_str = "INFINITY";
            else if (flags[4]) flag_str = "QNAN";
            else if (flags[5]) flag_str = "SNAN";
            else flag_str = "UNKNOWN";
        end
    endfunction

    initial begin
        $display("Starting HP Multiplier Tests");
        $display("---------------------------");

        // Test 1: Zero × Zero = Zero
        a = 16'h0000; b = 16'h0000; #10;
        $display("Test 1: Zero × Zero");
        $display("a: %s (0.0)", fp_str(a));
        $display("b: %s (0.0)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 2: Infinity × Zero = NaN (Invalid operation)
        a = 16'h7F80; b = 16'h0000; #10;
        $display("Test 2: Infinity × Zero");
        $display("a: %s (Infinity)", fp_str(a));
        $display("b: %s (0.0)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 3: 1.0 × 2.0 = 2.0
        a = 16'h3F80; b = 16'h4000; #10;
        $display("Test 3: 1.0 × 2.0");
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (2.0)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 4: -1.0 × 1.0 = -1.0
        a = 16'hBF80; b = 16'h3F80; #10;
        $display("Test 4: -1.0 × 1.0");
        $display("a: %s (-1.0)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 5: Subnormal × Normal
        a = 16'h0040; b = 16'h3F80; #10;
        $display("Test 5: Subnormal × Normal");
        $display("a: %s (Subnormal ~2^-126)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 6: NaN × Any = NaN
        a = 16'h7FC0; b = 16'h3F80; #10;
        $display("Test 6: NaN × Normal");
        $display("a: %s (NaN)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 7: Infinity × Normal = Infinity
        a = 16'h7F80; b = 16'h3F80; #10;
        $display("Test 7: Infinity × Normal");
        $display("a: %s (Infinity)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 8: Overflow test - Large values that should overflow
        a = 16'h7F00; b = 16'h7F00; #10;
        $display("Test 8: Overflow test");
        $display("a: %s (Large ~2^127)", fp_str(a));
        $display("b: %s (Large ~2^127)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 9: Underflow test - Tiny values that should underflow
        a = 16'h0001; b = 16'h0001; #10;
        $display("Test 9: Underflow test");
        $display("a: %s (Tiny ~2^-149)", fp_str(a));
        $display("b: %s (Tiny ~2^-149)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 10: Non-zero significand test - 1.5 × 1.25 = 1.875
        a = 16'h3FC0; b = 16'h3FA0; #10;
        $display("Test 10: 1.5 × 1.25");
        $display("a: %s (1.5 = 1 + 0.5)", fp_str(a));
        $display("b: %s (1.25 = 1 + 0.25)", fp_str(b));
        $display("p: %s | Flag: %s | Exc: %b", fp_str(p), flag_str(bfFlags), exception);
        $display("---------------------------");

        $finish;
    end
endmodule
