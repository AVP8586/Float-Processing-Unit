`include "class.sv"
`include "round.v"

module hp_mul #(parameter NEXP = 8; parameter NSIG = 7)(
    input [NEXP+NSIG:0]a, b,
    output [NEXP+NSIG:0]p,
    output reg [NTYPES-1:0]bfFlags,
    output reg [NEXCEPTIONS-1:0]exception // handle later.
);
`include "flags.v"
wire [NSIG:0]abfSig, bbfSig; // normalised significand of form 1xxxxxxx
wire [NTYPES-1:0]abfFlags, bbfFlags;
wire [NEXP-1:0]asubnormalShift, bsubnormalShift;
hp_class aclass(.bf16(a), .bfSig(abfSig), .subnormalShift(asubnormalShift), .bfFlags(abfFlags));
hp_class bclass(.bf16(b), .bfSig(bbfSig), .subnormalShift(bsubnormalShift), .bfFlags(bbfFlags));

wire [NEXP-1:0]tempExp; //temporarily store the exponent
wire carry, overflow;
assign p[NEXP+NSIG] = a[NEXP+NSIG] ^ b[NEXP+NSIG];
wire [2*NSIG+1:0]pSig = abfSig * bbfSig; //should be of form 1xxx... 16 bits
wire [NSIG-1:0]roundedSig;
assign {carry, tempExp} = a[NEXP+NSIG-1:NSIG] + b[NEXP+NSIG-1:NSIG] - {1'b0, {NEXP-1{1'b1}}}; // to check for the last carry bit

if (abfFlags[SUBNORMAL]) tempExp = tempExp - asubnormalShift;
if (bbfFlags[SUBNORMAL]) tempExp = tempExp - bsubnormalShift;
exception[INEXACT] = |pSig[NSIG:0];

always @(*) begin
    // 1. all three outlier cases
    if (abfFlags[INFINITY] & bbfFlags[INFINITY]) begin
        bfFlags[INFINITY] = 1;
        p[NSIG+NEXP-1:0] = inf;
    end
    else if ((abfFlags[INFINITY] & |bbfFlags[NORMAL:SUBNORMAL]) && (bbfFlags[INFINITY] & abfFlags[NORMAL:SUBNORMAL])) begin
        bfFlags[INFINITY] = 1;
        p[NSIG+NEXP-1:0] = inf;
    end
    else if ((abfFlags[ZERO] & bbfFlags[INFINITY]) || (bbfFlags[ZERO] & abfFlags[INFINITY])) begin
        bfFlags[QNAN] = 1;
        p[NSIG+NEXP-1:0] = nan;
    end
    else if (abfFlags[ZERO] || bbfFlags[ZERO]) begin
        bfFlags[ZERO] = 1;
        p[NSIG+NEXP-1:0] = zero;
    end
    else if (|abfFlags[QNAN:SNAN] || |bbfFlags[QNAN:SNAN]) begin
        bfFlags[QNAN] = 1;
        p[NSIG+NEXP-1:0] = nan;
    end

    // 2. all subnormal cases
    else if (tempExp <= EMIN - NSIG) begin // we lose all significand bits here
        bfFlags[ZERO] = 1;
        p[NSIG+NEXP-1:0] = zero;
    end
    else if (tempExp >= EMIN - NSIG && tempExp < EMIN-1) begin //-133 to -128, we can have some signficand bits remaining
        integer shifts = EMIN - tempExp;
        pSig = pSig >> shifts; // becomes of form 01xxxxx... 16 bits
        round r0(.roundedSig(roundedSig), .pSig(pSig), .overflow()); //yet to make
        tempExp = {NEXP{1'b0}};
        bfFlags[SUBNORMAL] = 1;
        p[NSIG+NEXP-1:0] = {tempExp, roundedSig};  //complete
        exception[UNDERFLOW] = 1;
    end
    else if (tempExp == EMIN-1) begin
        // 1 shift is required, but if the overflow is 1, we dont need to shift anything. then it becomes the smallest normal number
        pSig = pSig >> 1;
        round r0(.roundedSig(roundedSig), .pSig(pSig), .overflow());
        if (overflow == 1'b1) begin
            tempExp = {NEXP-1{1'b0}, 1'b1};
            p[NSIG+NEXP-1:0] = {tempExp, roundedSig};
            bfFlags[NORMAL] = 1;
        end
        else begin
            tempExp = {NEXP{1'b0}};
            p[NSIG+NEXP-1:0] = {tempExp, roundedSig};
            bfFlags[SUBNORMAL] = 1;
            exception[UNDERFLOW] = 1;
        end
    end
    else if (tempExp >= EMIN) begin // no need to shift anything, all good
        round r0(.roundedSig(roundedSig), .pSig(pSig), .overflow(overflow)); //yet to make
        bfFlags[NORMAL] = 1;
        p[NSIG+NEXP-1:0] = {tempExp+overflow, roundedSig};  //complete
    end

    // 3. only normal cases
    // a. if infinity
    else if (tempExp == {NEXP{1'b1}} || carry == 1'b1) begin 
        if ((|abfFlags[QNAN:SNAN] || |bbfFlags[QNAN:SNAN]) || (abfFlags[ZERO] & bbfFlags[INFINITY]) || (bbfFlags[ZERO] & abfFlags[INFINITY])) begin
            p[NSIG+NEXP-1:0] = nan;  //complete
            bfFlags[QNAN] = 1;
            exception[INVALID] = 1;
        end
        else begin
            p[NSIG+NEXP-1:0] = inf;
            bfFlags[INFINITY] = 1;  //complete
            exception[OVERFLOW] = 1;
        end
    end
    // b. if normal
    else begin
        round r0(.roundedSig(roundedSig), .pSig(pSig), .overflow(overflow)); //yet to make
        bfFlags[NORMAL] = 1;
        p[NSIG+NEXP-1:0] = {tempExp, roundedSig};
    end
end

// exception handling remains
endmodule