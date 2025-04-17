`include "class.sv"

module hp_add #(parameter NEXP = 8; parameter NSIG = 7)(
    input [NEXP+NSIG:0]a, b, //both are assumed to be of same sign
    output [NEXP+NSIG:0]s,
    output reg [NTYPES-1:0]bfFlags,
    output reg [NEXCEPTIONS-1:0]exception // handle later.
);
`include "flags.v"
wire [NSIG:0]abfSig, bbfSig; // normalised significand of form 1xxxxxxx
wire [NTYPES-1:0]abfFlags, bbfFlags;
wire [NEXP-1:0]asubnormalShift, bsubnormalShift, totalShift; // these shifts here can help while adjusting exponents
hp_class aclass(.bf16(a), .bfSig(abfSig), .subnormalShift(asubnormalShift), .bfFlags(abfFlags));
hp_class bclass(.bf16(b), .bfSig(bbfSig), .subnormalShift(bsubnormalShift), .bfFlags(bbfFlags));

wire pSign;
reg [NEXP-1:0]maxExp;
wire [NEXP-1:0]aExp, bExp;
wire [NSIG-1:0]aSig, bSig;
reg [NSIG-1:0]pSig;
reg carry;
integer ashifts, bshifts, i;
assign pSign = a[NEXP+NSIG] & b[NEXP+NSIG];
assign aExp = a[NEXP+NSIG-1:NSIG]; // 14 to 7
assign bExp = b[NEXP+NSIG-1:NSIG];
assign aSig = a[NSIG-1:0];
assign bSig = b[NSIG-1:0];

always @(*) begin
    // 1. outlier cases
    if (|abfFlags[QNAN:SNAN] || |bbfFlags[QNAN:SNAN]) begin
        bfFlags[QNAN] = 1;
        s[NEXP+NSIG-1:0] = nan; // complete
    end
    else if (abfFlags[INFINITY] || bbfFlags[INFINITY]) begin
        bfFlags[INFINITY] = 1;
        s[NEXP+NSIG-1:0] = inf; // complete
    end
    else if (abfFlags[ZERO] && bbfFlags[ZERO]) begin
        bfFlags[ZERO] = 1;
        s[NEXP+NSIG-1:0] = zero; // complete
    end

    // 2. normal and subnormal cases
    // a. subnormal first
    else begin
        maxExp = aExp >= bExp ? aExp:bExp;
        ashifts = maxExp - aExp;
        bshifts = maxExp - bExp;
        if (abfFlags[SUBNORMAL]) ashifts = ashifts + asubnormalShift;
        if (bbfFlags[SUBNORMAL]) bshifts = bshifts + bsubnormalShift;
        aSig = aSig >> ashifts;
        bSig = bSig >> bshifts; // both in appropriate form, with equal exponents
        {carry, pSig} = aSig + bSig;
        if (carry == 1'b1) begin
            pSig = {1'b1, pSig[NSIG-1:1]};
            maxExp = maxExp + NEXP'x1;
        end

        s = {pSign, maxExp, pSig}; //complete
    end
end
endmodule