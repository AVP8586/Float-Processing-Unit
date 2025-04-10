`include "flags.v"

module cvtsw #(parameter INTn = 32; parameter NEXP = 8; parameter NSIG = 7)(
    input signed [INTn-1:0] in,
    input [LAST_RA:0] ra,
    output reg [NEXP+NSIG:0] out,
    output inexact,
    output reg overflow
);  // more changes to be done
localparam clog_INTn = $clog2(INTn);

reg [INTn-1:0] sigIn;
wire [INTn-1:0] mask;
assign mask = {NEXP+NSIG+1{1'b1}};
integer i;
reg [NEXP-1:0] expIn;

reg [NEXP-1:0] expOut;
reg [NSIG:0] sigOut;
        
always @(*)
begin
    sigIn = w[INTn-1] ? (~w + 1) : w;
    
    if (sigIn == 0)
    begin
        s = {NEXP+NSIG+1{1'b0}};
    end
    else
    begin
        expIn = 0;
        for (i = (1 << (CLOG2_INTn - 1)); i > 0; i = i >> 1)
        begin
            if ((sigIn & (mask << (INTn - i))) == 0)
            begin
                sigIn = sigIn << i;
                expIn = expIn | i;
            end
        end
        expIn = (INTn-1) + BIAS - expIn; 
        overflow = &expOut;
        s[NEXP+NSIG:NSIG] = {w[INTn-1], expOut};
        s[NSIG-1:0] = overflow ? {NSIG{1'b0}} : sigOut;
    end
end

assign inexact = |sigIn[INTn-2-NSIG:0];
round U0(w[INTn-1], expIn, sigIn, ra, expOut, sigOut);
endmodule