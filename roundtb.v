`timescale 1ns/1ps

module tb_round;
  parameter NSIG = 7;
  reg [2*NSIG+1:0] pSig;  // 16-bit input
  wire [NSIG-1:0] roundedSig;
  wire overflow;
  
  // Instantiate DUT
  round #(.NSIG(NSIG)) dut (.pSig(pSig),.roundedSig(roundedSig),.overflow(overflow));
  
  initial begin
    $dumpfile("round.vcd");
    $dumpvars(0, tb_round);
    $monitor("Time=%0t pSig=%h Rounded=%b Overflow=%b", 
             $time, pSig, roundedSig, overflow);
    
    // Test 1: No rounding (guard bit = 0)
    pSig = 16'b00000000_00000000;  // Retained: 0000000
    #10;
    
    // Test 2: Round up (guard=1, round=1)
    pSig = 16'b00000001_11000000;  // Retained: 0000001 → 0000010
    #10;
    
    // Test 3: Round up (guard=1, sticky=1)
    pSig = 16'b00000001_10000001;  // Retained: 0000001 → 0000010
    #10;
    
    // Test 4: Tie to even (even retained)
    pSig = 16'b00000010_10000000;  // Retained: 0000010 (even) → no round
    #10;
    
    // Test 5: Tie to even (odd retained)
    pSig = 16'b00000011_10000000;  // Retained: 0000011 → 0000100
    #10;
    
    // Test 6: Overflow scenario
    pSig = 16'b11111111_10000000;  // Retained: 1111111 → 0000000 (overflow)
    #10;
    
    // Test 7: Maximum no-overflow
    pSig = 16'b11111110_11000000;  // Retained: 1111110 → 1111111
    #10;
    
    $finish;
  end
endmodule
