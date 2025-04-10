`include "flags.v"

module round# (parameter NEXP = 8; parameter NSIG = 7)(
    input [2*NSIG+1:0]pSig,
    output reg [NSIG-1:0]roundedSig,
	output reg overflow;
);
//roundties to even by default
reg guardBit = pSig[NSIG]; // 7
reg roundBit = pSig[NSIG-1]; // 6
reg stickyBits = |pSig[NSIG-2:0]; // 5 to 0 
reg [NSIG-1:0]retainedBits = pSig[2*NSIG:NSIG+1]; // 14 to 8
reg overflow = 1'b0;

always @(*) begin
	if (guardBit == 1'b0) roundedSig = retainedBits;
	else if (guardBit == 1'b1) begin
		if (roundBit == 1'b1 || stickyBits == 1'b1) begin
			{overflow, roundedSig} = retainedBits + NSIG'x1;
		end
		else if (oundBit == 1'b0 && stickyBits == 1'b0) begin
			if (retainedBits[0] == 1'b1) begin
				{overflow, roundedSig} = retainedBits + NSIG'x1;
			end
			else roundedSig = retainedBits;
		end
	end
end
endmodule