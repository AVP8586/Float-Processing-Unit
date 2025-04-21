`include "class.sv"
`include "round.v"

module hp_mul #(parameter NEXP = 8, parameter NSIG = 7)(
    input [NEXP+NSIG:0] a, b,
    output [NEXP+NSIG:0] p,
    output reg [5:0] bfFlags,
    output reg [4:0] exception
);
flags_defs #(.NEXP(8), .NSIG(7)) flags();
wire [NEXP+NSIG-1:0] zero = {(NEXP+NSIG){1'b0}};
wire [NEXP+NSIG-1:0] inf = {{NEXP{1'b1}}, {NSIG{1'b0}}};
wire [NEXP+NSIG-1:0] nan = {{NEXP{1'b1}}, 1'b1, {(NSIG-1){1'b0}}};
wire [NSIG:0] abfSig, bbfSig;
wire [5:0] abfFlags, bbfFlags;
wire [NEXP-1:0] asubnormalShift, bsubnormalShift;
wire sign = a[NEXP+NSIG] ^ b[NEXP+NSIG];
wire [NEXP:0] e1 = a[14:7];
wire [NEXP:0] e2 = b[14:7];
wire [NSIG:0] m1, m2;
reg [2*NSIG+1:0] m;       
reg [NEXP:0] e;       

hp_class aclass(.bf16(a), .bfSig(abfSig), .subnormalShift(asubnormalShift), .bfFlags(abfFlags));
hp_class bclass(.bf16(b), .bfSig(bbfSig), .subnormalShift(bsubnormalShift), .bfFlags(bbfFlags));

assign m1 = abfFlags[flags.NORMAL] ? {1'b1, a[NSIG-1:0]} : abfFlags[flags.SUBNORMAL] ? abfSig : 8'h00;
assign m2 = bbfFlags[flags.NORMAL] ? {1'b1, b[NSIG-1:0]} : bbfFlags[flags.SUBNORMAL] ? bbfSig : 8'h00;

always @(*) begin
    m = m1 * m2;
    e = e1 + e2 - 127;
    
    if (abfFlags[flags.SUBNORMAL]) begin
        e = e - asubnormalShift;
    end
    
    if (bbfFlags[flags.SUBNORMAL]) begin
        e = e - bsubnormalShift;
    end
    if(m[15] == 1'b1) begin
        m = m >> 1;
        e = e + 1;
    end
end

wire [2*NSIG+1:0] m_shifted = m << 1;  // Shift left by 1 to align bits

wire [2*NSIG+1:0] round_input;
assign round_input[2*NSIG:NSIG+1] = m_shifted[14:8];  // retainedBits (bits 14:8)
assign round_input[NSIG] = m_shifted[7];              // guardBit (bit 7)
assign round_input[NSIG-1] = m_shifted[6];            // roundBit (bit 6)
assign round_input[NSIG-2:0] = |m_shifted[5:0];       // stickyBits (bits 5:0)
wire [NSIG-1:0] rounded_sig;
wire round_overflow;
round r0(
    .pSig(round_input),
    .roundedSig(rounded_sig),
    .overFlow(round_overflow)
);

wire [NEXP:0] final_exp = e + round_overflow;
wire overflow = final_exp >= 9'b1_0000_0000; // e >= 256
wire underflow = $signed(final_exp) < $signed(9'b0_0000_0001); // e < 1
wire [31:0] shift_amount = (underflow && $signed(final_exp) > $signed(-NSIG)) ? 
                            ($signed(9'b0_0000_0001) - $signed(final_exp)) : 0;
wire [2*NSIG+1:0] shifted_for_subnormal = m_shifted >> shift_amount;
wire [2*NSIG+1:0] subnormal_round_input;
assign subnormal_round_input[2*NSIG:NSIG+1] = shifted_for_subnormal[14:8];  // retainedBits
assign subnormal_round_input[NSIG] = shifted_for_subnormal[7];              // guardBit
assign subnormal_round_input[NSIG-1] = shifted_for_subnormal[6];            // roundBit
assign subnormal_round_input[NSIG-2:0] = |shifted_for_subnormal[5:0];       // stickyBits
wire [NSIG-1:0] subnormal_rounded_sig;
wire subnormal_overflow;
round r1(
    .pSig(subnormal_round_input),
    .roundedSig(subnormal_rounded_sig),
    .overFlow(subnormal_overflow)
);

reg [NEXP+NSIG-1:0] result;

always @(*) begin
    bfFlags = 6'b000000;
    exception = 5'b00000;

    if (abfFlags[flags.SNAN] || bbfFlags[flags.SNAN]) begin
        result = nan;
        bfFlags[flags.QNAN] = 1'b1;
        exception[flags.INVALID] = 1'b1;
    end
    else if (abfFlags[flags.QNAN] || bbfFlags[flags.QNAN]) begin
        result = nan;
        bfFlags[flags.QNAN] = 1'b1;
    end
    else if ((abfFlags[flags.INFINITY] && bbfFlags[flags.ZERO]) || (abfFlags[flags.ZERO] && bbfFlags[flags.INFINITY])) begin
        result = nan;
        bfFlags[flags.QNAN] = 1'b1;
        exception[flags.INVALID] = 1'b1;
    end
    else if (abfFlags[flags.INFINITY] || bbfFlags[flags.INFINITY]) begin
        result = inf;
        bfFlags[flags.INFINITY] = 1'b1;
    end
    else if (abfFlags[flags.ZERO] || bbfFlags[flags.ZERO]) begin
        result = zero;
        bfFlags[flags.ZERO] = 1'b1;
    end
    else if (overflow) begin
        result = inf;
        bfFlags[flags.INFINITY] = 1'b1;
        exception[flags.OVERFLOW] = 1'b1;
        exception[flags.INEXACT] = 1'b1;
    end
    else if (underflow) begin
        if ($signed(final_exp) <= $signed(-NSIG)) begin
            result = zero;
            bfFlags[flags.ZERO] = 1'b1;
            exception[flags.UNDERFLOW] = 1'b1;
            exception[flags.INEXACT] = 1'b1;
        end
        else begin
            if (subnormal_overflow && shift_amount == 1) begin
                result = {{1'b0, {(NEXP-1){1'b0}}, 1'b1}, subnormal_rounded_sig};
                bfFlags[flags.NORMAL] = 1'b1;
                exception[flags.INEXACT] = subnormal_round_input[NSIG] | subnormal_round_input[NSIG-1] | |subnormal_round_input[NSIG-2:0];
            end
            else begin
                result = {{NEXP{1'b0}}, subnormal_rounded_sig};
                bfFlags[flags.SUBNORMAL] = 1'b1;
                exception[flags.UNDERFLOW] = 1'b1;
                exception[flags.INEXACT] = 1'b1;
            end
        end
    end
    else begin
        result = {final_exp[NEXP-1:0], rounded_sig};
        bfFlags[flags.NORMAL] = 1'b1;
        exception[flags.INEXACT] = round_input[NSIG] | round_input[NSIG-1] | |round_input[NSIG-2:0];
    end
end
assign p = {sign, result};

endmodule