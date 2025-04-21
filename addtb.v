`include "class.sv"
`timescale 1ns/1ps

module tb_hp_add;
    localparam NEXP = 8;
    localparam NSIG = 7;

    reg [NEXP+NSIG:0] a, b;
    reg operation;  // 0 = add, 1 = subtract
    wire [NEXP+NSIG:0] s;
    wire [5:0] bfFlags;
    wire [4:0] exception;

    // Instantiate DUT
    hp_add #(.NEXP(NEXP), .NSIG(NSIG)) dut (
        .a(a),
        .b(b),
        .operation(operation),
        .s(s),
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

    // Helper function to display operation
    function [8*10:1] op_str;
        input op;
        begin
            op_str = op ? "SUBTRACT" : "ADD";
        end
    endfunction

    initial begin
        $display("Starting HP Adder/Subtractor Tests");
        $display("----------------------------------");

        // Test Group 1: Basic Addition Tests
        operation = 0; // Addition

        // Test 1.1: Zero + Zero = Zero
        a = 16'h0000; b = 16'h0000; #10;
        $display("Test 1.1: Zero + Zero");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (0.0)", fp_str(a));
        $display("b: %s (0.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 1.2: 1.0 + 2.0 = 3.0
        a = 16'h3F80; b = 16'h4000; #10;
        $display("Test 1.2: 1.0 + 2.0");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (2.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 1.3: 1.5 + 1.5 = 3.0 (rounding test)
        a = 16'h3FC0; b = 16'h3FC0; #10;
        $display("Test 1.3: 1.5 + 1.5");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (1.5)", fp_str(a));
        $display("b: %s (1.5)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 1.4: -1.0 + 1.0 = 0.0 (cancellation)
        a = 16'hBF80; b = 16'h3F80; #10;
        $display("Test 1.4: -1.0 + 1.0");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (-1.0)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test Group 2: Basic Subtraction Tests
        operation = 1; // Subtraction

        // Test 2.1: 3.0 - 1.0 = 2.0
        a = 16'h4040; b = 16'h3F80; #10;
        $display("Test 2.1: 3.0 - 1.0");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (3.0)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 2.2: 1.0 - 1.0 = 0.0
        a = 16'h3F80; b = 16'h3F80; #10;
        $display("Test 2.2: 1.0 - 1.0");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 2.3: 1.0 - 2.0 = -1.0
        a = 16'h3F80; b = 16'h4000; #10;
        $display("Test 2.3: 1.0 - 2.0");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (2.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test Group 3: Special Cases - Addition
        operation = 0; // Addition

        // Test 3.1: Infinity + Infinity = Infinity
        a = 16'h7F80; b = 16'h7F80; #10;
        $display("Test 3.1: Infinity + Infinity");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Infinity)", fp_str(a));
        $display("b: %s (Infinity)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 3.2: Infinity + (-Infinity) = NaN (Invalid)
        a = 16'h7F80; b = 16'hFF80; #10;
        $display("Test 3.2: Infinity + (-Infinity)");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Infinity)", fp_str(a));
        $display("b: %s (-Infinity)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 3.3: NaN + Any = NaN
        a = 16'h7FC0; b = 16'h3F80; #10;
        $display("Test 3.3: NaN + Normal");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (NaN)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 3.4: Infinity + Normal = Infinity
        a = 16'h7F80; b = 16'h3F80; #10;
        $display("Test 3.4: Infinity + Normal");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Infinity)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test Group 4: Special Cases - Subtraction
        operation = 1; // Subtraction

        // Test 4.1: Infinity - Infinity = NaN (Invalid)
        a = 16'h7F80; b = 16'h7F80; #10;
        $display("Test 4.1: Infinity - Infinity");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Infinity)", fp_str(a));
        $display("b: %s (Infinity)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 4.2: Infinity - (-Infinity) = Infinity
        a = 16'h7F80; b = 16'hFF80; #10;
        $display("Test 4.2: Infinity - (-Infinity)");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Infinity)", fp_str(a));
        $display("b: %s (-Infinity)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test Group 5: Exponent Alignment and Normalization
        operation = 0; // Addition

        // Test 5.1: 1.0 + 0.0078125 = 1.0078125 (different exponents)
        a = 16'h3F80; b = 16'h3C00; #10;
        $display("Test 5.1: 1.0 + 0.0078125");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (0.0078125)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 5.2: 1.5 + 1.5 = 3.0 (normalization with carry)
        a = 16'h3FC0; b = 16'h3FC0; #10;
        $display("Test 5.2: 1.5 + 1.5");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (1.5)", fp_str(a));
        $display("b: %s (1.5)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 5.3: 1.0 - 0.96875 = 0.03125 (normalization with leading zeros)
        operation = 1; // Subtraction
        a = 16'h3F80; b = 16'h3F78; #10;
        $display("Test 5.3: 1.0 - 0.96875");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (1.0)", fp_str(a));
        $display("b: %s (0.96875)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test Group 6: Subnormal Numbers
        operation = 0; // Addition

        // Test 6.1: Subnormal + Subnormal
        a = 16'h0040; b = 16'h0040; #10;
        $display("Test 6.1: Subnormal + Subnormal");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Subnormal)", fp_str(a));
        $display("b: %s (Subnormal)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 6.2: Subnormal + Normal (small)
        a = 16'h0080; b = 16'h3C00; #10;
        $display("Test 6.2: Subnormal + Small Normal");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Subnormal)", fp_str(a));
        $display("b: %s (0.0625)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 6.3: Normal - Normal = Subnormal (result becomes subnormal)
        operation = 1; // Subtraction
        a = 16'h3C10; b = 16'h3C00; #10;
        $display("Test 6.3: Small Normal - Slightly Smaller Normal");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Small normal)", fp_str(a));
        $display("b: %s (Slightly smaller normal)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test Group 7: Overflow and Underflow
        operation = 0; // Addition

        // Test 7.1: Large + Large = Overflow to Infinity
        a = 16'h7F00; b = 16'h7F00; #10;
        $display("Test 7.1: Large + Large (Overflow)");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Large ~2^127)", fp_str(a));
        $display("b: %s (Large ~2^127)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 7.2: Tiny + Tiny = Underflow (still representable as subnormal)
        a = 16'h0001; b = 16'h0001; #10;
        $display("Test 7.2: Tiny + Tiny (Underflow)");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (Tiny ~2^-149)", fp_str(a));
        $display("b: %s (Tiny ~2^-149)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test Group 8: Mixed Sign Operations
        
        // Test 8.1: Positive + Negative (different magnitudes)
        operation = 0; // Addition
        a = 16'h4040; b = 16'hBF80; #10;
        $display("Test 8.1: 3.0 + (-1.0)");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (3.0)", fp_str(a));
        $display("b: %s (-1.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 8.2: Negative - Negative (different magnitudes)
        operation = 1; // Subtraction
        a = 16'hBF80; b = 16'hC000; #10;
        $display("Test 8.2: -1.0 - (-2.0)");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (-1.0)", fp_str(a));
        $display("b: %s (-2.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 8.3: Negative + Negative
        operation = 0; // Addition
        a = 16'hBF80; b = 16'hC000; #10;
        $display("Test 8.3: -1.0 + (-2.0)");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (-1.0)", fp_str(a));
        $display("b: %s (-2.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test Group 9: Rounding Tests
        operation = 0; // Addition

        // Test 9.1: Addition with rounding
        a = 16'h3F81; b = 16'h3D00; #10;
        $display("Test 9.1: Addition with rounding");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (1.0 + small)", fp_str(a));
        $display("b: %s (small value)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 9.2: Subtraction with rounding
        operation = 1; // Subtraction
        a = 16'h4000; b = 16'h3F81; #10;
        $display("Test 9.2: Subtraction with rounding");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (2.0)", fp_str(a));
        $display("b: %s (1.0 + small)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test Group 10: Zero Tests
        operation = 0; // Addition

        // Test 10.1: Zero + Normal = Normal
        a = 16'h0000; b = 16'h3F80; #10;
        $display("Test 10.1: Zero + Normal");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (0.0)", fp_str(a));
        $display("b: %s (1.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        // Test 10.2: Zero - Zero = Zero
        operation = 1; // Subtraction
        a = 16'h0000; b = 16'h0000; #10;
        $display("Test 10.2: Zero - Zero");
        $display("Operation: %s", op_str(operation));
        $display("a: %s (0.0)", fp_str(a));
        $display("b: %s (0.0)", fp_str(b));
        $display("s: %s | Flag: %s | Exc: %b", fp_str(s), flag_str(bfFlags), exception);
        $display("----------------------------------");

        $finish;
    end
endmodule
