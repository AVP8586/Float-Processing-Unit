`include "class.sv"
`include "reciprocal.v"
`include "mul.v"

module hp_divide #(parameter NEXP = 8; parameter NSIG = 7)(
    input [NEXP+NSIG:0]a, b, //both are assumed to be of same sign
    output [NEXP+NSIG:0]q,
    output reg [NTYPES-1:0]bfFlags,
    output reg [NEXCEPTIONS-1:0]exception // handle later.
);
`include "flags.v"
wire [NSIG:0]abfSig, bbfSig; // normalised significand of form 1xxxxxxx
wire [NTYPES-1:0]abfFlags, bbfFlags;
wire [NEXP-1:0]asubnormalShift, bsubnormalShift, qExp; // for reciprocal we just add these shifts to the exponent.
hp_class aclass(.bf16(a), .bfSig(abfSig), .subnormalShift(asubnormalShift), .bfFlags(abfFlags));
hp_class bclass(.bf16(b), .bfSig(bbfSig), .subnormalShift(bsubnormalShift), .bfFlags(bbfFlags));
reg invLimit = (1 << NEXP) - 2;
localparam signbit = NEXP+NSIG;
reg [signbit:0]brecip;
reg [NSIG:0]bsig;
reg carry, sign;
sign = a[signbit] ^ b[signbit];
brecip[signbit] = b[signbit];

always @(*) begin
    // 1. Outlier cases first
    if ((|abfFlags[INFINITY:SNAN] & |bbfFlags[ZERO:SNAN]) || (abfFlags[ZERO] & bbfFlags[ZERO])) begin
        q = {sign, nan};
        bfFlags[QNAN] = 1;
    end
    else if (abfFlags[ZERO]) begin 
        q = {sign, zero};
        bfFlags[ZERO] = 1;
    end
    else if (|abfFlags[QNAN:SNAN] & |bbfFlags[NORMAL:SUBNORMAL]) begin
        q = {sign, nan};
        bfFlags[QNAN] = 1;
    end
    else if (abfFlags[INFINITY] & |bbfFlags[NORMAL:SUBNORMAL]) begin
        q = {sign, inf};
        bfFlags[INFINITY] = 1;
    end
    else if (bbfFlags[INFINITY] & |abfFlags[NORMAL:SUBNORMAL]) begin
        q = {sign, zero};
        bfFlags[ZERO] = 1;
    end
    else if (|{bbfFlags[QNAN:SNAN], bbfFlags[ZERO]} & |abfFlags[NORMAL:SUBNORMAL]) begin
        q = {sign, nan};
        bfFlags[QNAN] = 1;
    end

    // 2. Normal and subnormal cases
    else begin
        brecip[signbit-1:NSIG] = invLimit - b[signbit-1:NSIG]; // invert the exponent
        {carry, brecip[signbit-1:NSIG]} = brecip[signbit-1:NSIG] + asubnormalShift + bsubnormalShift;
        if (carry || &brecip[signbit-1:NSIG]) q = {sign, zero}; //brecip becomes infinity.
    end

end

// Handling the normalised significand.
reciprocal(.A(b[NSIG-1:0]), .R(bsig));
brecip[NSIG-1:0] = bsig[NSIG-1:0];
hp_mul(.a(a), .b(brecip), .p(q), .bfFlags(bfFlags), .exception(exception));

endmodule