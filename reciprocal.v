module reciprocal#(parameter NEXP = 8; parameter NSIG = 7)(
    input [NSIG:0] A,  // assume 1.xxxxxxx form for now
    output reg[NSIG:0]R
);
localparam reqBits = 2*NSIG - 1;
reg [reqBits:0]Ax0, prod, diff;
reg [reqBits:0]two = {1'b1, (reqBits-1)'b0};
reg [NSIG:0]guess = {1'b0, (NSIG-1)'b1};

always @(*) begin
    Ax0 = A*guess;
    diff = two - Ax0;
    prod = guess * diff[reqBits:NSIG+1];
end
assign R = prod[reqBits:NSIG+1];

endmodule