`timescale 1ns/1ps
`include "class.sv"
`include "add.v"

module tb_hp_add_subract;

    reg [NEXP+NSIG:0]a, b;
    wire [NEXP+NSIG:0]result;
    wire [NTYPES-1:0]bfFlags;
    wire [NEXCEPTIONS-1:0]exception;
    
    localparam signbit = NEXP+NSIG;
    reg sign;

    hp_add_subract #(.NEXP(NEXP),.NSIG(NSIG)) dut(.*);
    
    function string fp_str(input [NEXP+NSIG:0]fp);
     automatic logic sign = fp[NEXP+NSIG];
     automatic logic [NEXP-1:0] exp = fp[NEXP+NSIG-1:NSIG];
     automatic logic [NSIG-1:0] sig = fp[NSIG-1:0];
     return $sformatf("%s %8b %7b", sign ? "-" : "+", exp, sig);
    endfunction

   initial begin
     $dumpfile("hp_add_subtract.vcd");
     $dumpvars(0, tb_hp_add_subtract);
     
      $monitor("Time=%0t a=%s | b=%s | res=%s | Flags=%b | Excp=%b", 
             $time, fp_str(a), fp_str(b), fp_str(result), bfFlags, exception);
    
    // Test 1: Positive + Positive (Same Exponent)
    a = {1'b0, 8'h80, 7'h00};  // +1.0
    b = {1'b0, 8'h80, 7'h40};  // +1.5
    #10;
    
    // Test 2: Positive + Negative (A > B)
    a = {1'b0, 8'h81, 7'h00};  // +2.0
    b = {1'b1, 8'h80, 7'h00};  // -1.0
    #10;
    
    // Test 3: Positive + Negative (B > A)
    a = {1'b0, 8'h80, 7'h00};  // +1.0
    b = {1'b1, 8'h81, 7'h00};  // -2.0
    #10;
    
    // Test 4: Negative + Negative
    a = {1'b1, 8'h81, 7'h00};  // -2.0
    b = {1'b1, 8'h80, 7'h00};  // -1.0
    #10;
    
    // Test 5: Zero Handling
    a = {1'b0, 8'h00, 7'h00};  // +0
    b = {1'b0, 8'h00, 7'h00};  // +0
    #10;
    
    // Test 6: Infinity Handling
    a = {1'b0, 8'hFF, 7'h00};  // +inf
    b = {1'b0, 8'h80, 7'h00};  // +1.0
    #10;
    
    // Test 7: NaN Propagation
    a = {1'b0, 8'hFF, 7'h01};  // NaN
    b = {1'b0, 8'h80, 7'h00};  // +1.0
    #10;

    $finish;

   end
endmodule