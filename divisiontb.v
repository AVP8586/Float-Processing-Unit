`include "class.sv"
`include "round.v"
`timescale 1ns/1ps

module tb_hp_div;
    localparam NEXP = 8;
    localparam NSIG = 7;

    reg [NEXP+NSIG:0] a, b;
    wire [NEXP+NSIG:0] q;
    wire [5:0] bfFlags;
    wire [4:0] exception;

    // Instantiate DUT
    hp_div #(.NEXP(NEXP), .NSIG(NSIG)) dut (
        .a(a),
        .b(b),
        .q(q),
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
        $display("Starting HP Division Tests");
        $display("---------------------------");

        // Test 1: Zero ÷ Non-Zero = Zero
        a = 16'h0000; b = 16'h3F80; #10;
        $display("Test 1: Zero ÷ Non-Zero");
        $display("a: %s (0.0)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 2: Non-Zero ÷ Zero = Infinity (Division by zero)
        a = 16'h3F80; b = 16'h0000; #10;
        $display("Test 2: Non-Zero ÷ Zero");
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (0.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 3: Zero ÷ Zero = NaN (Invalid operation)
        a = 16'h0000; b = 16'h0000; #10;
        $display("Test 3: Zero ÷ Zero");
        $display("a: %s (0.0)", fp_str(a));
        $display("b: %s (0.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 4: Infinity ÷ Infinity = NaN (Invalid operation)
        a = 16'h7F80; b = 16'h7F80; #10;
        $display("Test 4: Infinity ÷ Infinity");
        $display("a: %s (Infinity)", fp_str(a));
        $display("b: %s (Infinity)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 5: 1.0 ÷ 2.0 = 0.5
        a = 16'h3F80; b = 16'h4000; #10;
        $display("Test 5: 1.0 ÷ 2.0");
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (2.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 6: 2.0 ÷ 1.0 = 2.0
        a = 16'h4000; b = 16'h3F80; #10;
        $display("Test 6: 2.0 ÷ 1.0");
        $display("a: %s (2.0)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 7: -1.0 ÷ 1.0 = -1.0
        a = 16'hBF80; b = 16'h3F80; #10;
        $display("Test 7: -1.0 ÷ 1.0");
        $display("a: %s (-1.0)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 8: 1.0 ÷ -1.0 = -1.0
        a = 16'h3F80; b = 16'hBF80; #10;
        $display("Test 8: 1.0 ÷ -1.0");
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (-1.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 9: Subnormal ÷ Normal
        a = 16'h0040; b = 16'h3F80; #10;
        $display("Test 9: Subnormal ÷ Normal");
        $display("a: %s (Subnormal ~2^-126)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 10: Normal ÷ Subnormal (should result in a large value or infinity)
        a = 16'h3F80; b = 16'h0040; #10;
        $display("Test 10: Normal ÷ Subnormal");
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (Subnormal ~2^-126)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 11: NaN ÷ Any = NaN
        a = 16'h7FC0; b = 16'h3F80; #10;
        $display("Test 11: NaN ÷ Normal");
        $display("a: %s (NaN)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 12: Any ÷ NaN = NaN
        a = 16'h3F80; b = 16'h7FC0; #10;
        $display("Test 12: Normal ÷ NaN");
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (NaN)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 13: Infinity ÷ Normal = Infinity
        a = 16'h7F80; b = 16'h3F80; #10;
        $display("Test 13: Infinity ÷ Normal");
        $display("a: %s (Infinity)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 14: Normal ÷ Infinity = Zero
        a = 16'h3F80; b = 16'h7F80; #10;
        $display("Test 14: Normal ÷ Infinity");
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (Infinity)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 15: Overflow test - Large value ÷ Small value
        a = 16'h7F00; b = 16'h0100; #10;
        $display("Test 15: Overflow test");
        $display("a: %s (Large ~2^127)", fp_str(a));
        $display("b: %s (Small ~2^-126)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 16: Underflow test - Small value ÷ Large value
        a = 16'h0100; b = 16'h7F00; #10;
        $display("Test 16: Underflow test");
        $display("a: %s (Small ~2^-126)", fp_str(a));
        $display("b: %s (Large ~2^127)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 17: Non-trivial division - 1.5 ÷ 1.25 = 1.2
        a = 16'h3FC0; b = 16'h3FA0; #10;
        $display("Test 17: 1.5 ÷ 1.25");
        $display("a: %s (1.5 = 1 + 0.5)", fp_str(a));
        $display("b: %s (1.25 = 1 + 0.25)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        // Test 18: Division resulting in exact power of 2 - 4.0 ÷ 2.0 = 2.0
        a = 16'h4080; b = 16'h4000; #10;
        $display("Test 18: 4.0 ÷ 2.0");
        $display("a: %s (4.0)", fp_str(a));
        $display("b: %s (2.0)", fp_str(b));
        $display("q: %s | Flag: %s | Exc: %b", fp_str(q), flag_str(bfFlags), exception);
        $display("---------------------------");

        $finish;
    end
endmodule
