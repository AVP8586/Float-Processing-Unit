`timescale 1ns/1ps

module tb_reciprocal;
    localparam NEXP = 8;
    localparam NSIG = 7;

    reg [NSIG:0] A;
    wire [NSIG:0] R;
    
    // Instantiate DUT
    reciprocal #(.NEXP(NEXP), .NSIG(NSIG)) dut (
        .A(A),
        .R(R)
    );
    
    initial begin
        $display("===== Reciprocal Module Test (2/input) =====");
        $display("| Input (Binary) | Output (Binary) |");
        $display("|---------------|----------------|");

        // Test 1: Reciprocal of 1.0
        A = 8'b10000000; #10;
        $display("| %b | %b |", A, R);

        // Test 2: Reciprocal of 1.5
        A = 8'b11000000; #10;
        $display("| %b | %b |", A, R);

        // Test 3: Reciprocal of 1.25
        A = 8'b10100000; #10;
        $display("| %b | %b |", A, R);

        // Test 4: Reciprocal of 1.75
        A = 8'b11100000; #10;
        $display("| %b | %b |", A, R);

        // Test 5: Reciprocal of 1.9375
        A = 8'b11111000; #10;
        $display("| %b | %b |", A, R);

        // Test 6: Reciprocal of 1.0625
        A = 8'b10001000; #10;
        $display("| %b | %b |", A, R);

        $display("==========================================");
        $finish;
    end
endmodule
