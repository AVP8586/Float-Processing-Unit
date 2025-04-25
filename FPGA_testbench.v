`include "add.v"
`include "division.v"
`include "multiply.v"
`include "reciprocal.v"
`include "class.sv"
`include "round.v"

module CombinedTester #(parameter NEXP = 8, parameter NSIG = 7)(
    input [5:0]Ainput, 
    input [5:0]Binput,
    input [2:0]operation,
    output reg [NEXP+NSIG:0]dispOut
);
reg [NEXP+NSIG:0]A, B;
wire [NEXP+NSIG:0]disp0, disp1, disp2, disp3, disp4;
localparam [NEXP+NSIG-1:0]nan = {{NEXP+1{1'b1}}, {NSIG-1{1'b0}}};
localparam [NEXP+NSIG-1:0]inf = {{NEXP{1'b1}}, {NSIG{1'b0}}};
localparam [NEXP+NSIG-1:0]zero = {(NEXP+NSIG){1'b0}};
// assign first 6 for a, second 6 for b, and rest 4 for operations (requires 3 bits).
// First 3 for inf, nan, subnormal, default 0, then next 3 for 3 normal numbers, that we know work.

hp_add #(.NEXP(NEXP), .NSIG(NSIG)) dut1 (.a(A), .b(B), .operation(1), .s(disp1), .bfFlags(), .exception()); //subtract
hp_mul #(.NEXP(NEXP), .NSIG(NSIG)) dut2 (.a(A), .b(B), .p(disp2), .bfFlags(), .exception()); //multiply
hp_div #(.NEXP(NEXP), .NSIG(NSIG)) dut3 (.a(A), .b(B), .q(disp3), .bfFlags(), .exception()); //division
reciprocal #(.NEXP(NEXP), .NSIG(NSIG)) dut4 (.A(A), .Arecip(disp4), .recipFlags());
hp_add #(.NEXP(NEXP), .NSIG(NSIG)) dut0 (.a(A), .b(B), .operation(0), .s(disp0), .bfFlags(), .exception()); //add

always @(*) begin
    case (Ainput)
        6'b000001: A = {1'b0, inf};
        6'b000010: A = {1'b0, nan};
        6'b000100: A = 16'h3F80; //1.0
        6'b001000: A = 16'hBF80; //-1.0
        6'b010000: A = 16'hC000; //-2.0
        6'b100000: A = 16'h3E80; //0.25 
        default: A = {1'b0, zero};
    endcase  

    case (Binput)
        6'b000001: B = {1'b0, inf};
        6'b000010: B = {1'b0, nan};
        6'b000100: B = 16'h4000; //2.0
        6'b001000: B = 16'hC080; //-3.0
        6'b010000: B = 16'h4080; //3.0
        6'b100000: B = 16'h3F00; //0.5
        default: B = {1'b0, zero};
    endcase

    case (operation)
        3'b010: dispOut = disp1;
        3'b011: dispOut = disp2;
        3'b100: dispOut = disp3;
        3'b101: dispOut = disp4;
        default: dispOut = disp0;
    endcase
end

    
endmodule