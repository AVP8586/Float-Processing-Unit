module round# (parameter NEXP = 8,
parameter NSIG = 7)(
    input [2*NSIG+1:0]pSig,
    output reg [NSIG-1:0]roundedSig,
    output reg overFlow
);
//roundties to even by default
reg guardBit; // 7
reg roundBit; // 6
reg stickyBits; // 5 to 0 
reg [NSIG-1:0]retainedBits; // 14 to 8

always @(*) begin
    guardBit = pSig[NSIG];
    roundBit = pSig[NSIG-1]; // 6
    stickyBits = |pSig[NSIG-2:0]; // 5 to 0 
    retainedBits = pSig[2*NSIG:NSIG+1]; // 14 to 8
    overFlow = 1'b0;
    if (guardBit == 1'b0) roundedSig = retainedBits;
    else if (guardBit == 1'b1) begin
        if (roundBit == 1'b1 || stickyBits == 1'b1) begin
            {overFlow, roundedSig} = retainedBits + 1'b1;
        end
        else if (roundBit == 1'b0 && stickyBits == 1'b0) begin
            if (retainedBits[0] == 1'b1) begin
                {overFlow, roundedSig} = retainedBits + 1'b1;
            end
            else roundedSig = retainedBits;
        end
    end
end
endmodule
