`include "class.sv"

module hp_divide #(parameter NEXP = 8; parameter NSIG = 7)(
    input [NEXP+NSIG:0]a, b, //both are assumed to be of same sign
    output [NEXP+NSIG:0]q,
    output reg [NTYPES-1:0]bfFlags,
    output reg [NEXCEPTIONS-1:0]exception // handle later.
);
reg limitExp = {NEXP-2{1'b1}, 1'b0, 1'b1};
localparam signbit = NEXP+NSIG;
reg [signbit:0]brecip;
brecip[signbit] = b[signbit];
if (b[signbit:NSIG] >= limitExp) begin
    brecip[signbit:NSIG] = NEXP{1'b0};
end
else begin
    brecip[signbit:NSIG] = limitExp - b[signbit:NSIG];
end
// significand still remains
endmodule