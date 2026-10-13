`include "../bfloat16_fpu/class.sv"
`include "../bfloat16_fpu/round.v"
`ifndef MULTIPLY_V
`define MULTIPLY_V

module hp_mul #(parameter NEXP = 8, parameter NSIG = 7)(
    input [NEXP+NSIG:0] a, b,
    output [NEXP+NSIG:0] p,
    output reg [5:0] bfFlags,
    output reg [4:0] exception
);
localparam NORMAL = 0;
localparam SUBNORMAL = NORMAL + 1; // 1
localparam ZERO = SUBNORMAL + 1; //2 
localparam INFINITY  = ZERO + 1; //3
localparam QNAN = INFINITY + 1; //4
localparam SNAN = QNAN + 1; //5

localparam BIAS = ((1 << (NEXP - 1)) - 1); 
localparam EMAX = BIAS; 
localparam EMIN = (1 - EMAX); 
localparam roundTiesToEven = 0;
                            
localparam INVALID = 0;
localparam DIVIDEBYZERO = 1;
localparam OVERFLOW = 2;
localparam UNDERFLOW = 3;
localparam INEXACT = 4;

wire [NEXP+NSIG-1:0] zero = {(NEXP+NSIG){1'b0}};
wire [NEXP+NSIG-1:0] inf = {{NEXP{1'b1}}, {NSIG{1'b0}}};
wire [NEXP+NSIG-1:0] nan = {{NEXP{1'b1}}, 1'b1, {(NSIG-1){1'b0}}};
wire [NSIG:0] abfSig, bbfSig;
wire [5:0] abfFlags, bbfFlags;
wire [NEXP-1:0] asubnormalShift, bsubnormalShift;
wire sign = a[NEXP+NSIG] ^ b[NEXP+NSIG];
wire [NEXP:0] e1 = a[NEXP+NSIG-1:NSIG];
wire [NEXP:0] e2 = b[NEXP+NSIG-1:NSIG];
wire [NSIG:0] m1, m2;
reg [2*NSIG+1:0] m;       
reg signed [NEXP+1:0] e;       
integer i;

hp_class aclass(.bf16(a), .bfSig(abfSig), .subnormalShift(asubnormalShift), .bfFlags(abfFlags));
hp_class bclass(.bf16(b), .bfSig(bbfSig), .subnormalShift(bsubnormalShift), .bfFlags(bbfFlags));

// For subnormals, use raw significand (0.xxxxxxx) with biased exponent 1
assign m1 = abfFlags[NORMAL] ? {1'b1, a[NSIG-1:0]} : abfFlags[SUBNORMAL] ? {1'b0, a[NSIG-1:0]} : 8'h00;
assign m2 = bbfFlags[NORMAL] ? {1'b1, b[NSIG-1:0]} : bbfFlags[SUBNORMAL] ? {1'b0, b[NSIG-1:0]} : 8'h00;

always @(*) begin
    m = m1 * m2;
    // For subnormals, the stored exponent is 0 but true biased exponent is 1
    e = (abfFlags[SUBNORMAL] ? 1 : e1) + (bbfFlags[SUBNORMAL] ? 1 : e2) - BIAS;
    
    if(m[2*NSIG+1] == 1'b1) begin
        m = m >> 1;
        e = e + 1;
    end
    // Normalize products with leading zeros (from subnormal operands)
    // Shift left until MSB is at m[2*NSIG] or exponent underflows
    else begin
        for (i = 0; i < 2*NSIG+1; i = i + 1) begin
            if (m != 0 && !m[2*NSIG] && $signed(e) > $signed(0)) begin
                m = m << 1;
                e = e - 1;
            end
        end
    end
end

wire [2*NSIG+1:0] m_shifted = m << 1;  // Shift left by 1 to align bits

wire [2*NSIG+1:0] round_input;
assign round_input[2*NSIG:NSIG+1] = m_shifted[14:8];  
assign round_input[NSIG] = m_shifted[7];             
assign round_input[NSIG-1] = m_shifted[6];            
assign round_input[NSIG-2:0] = |m_shifted[5:0];      
wire [NSIG-1:0] rounded_sig;
wire round_overflow;
round r0(
    .pSig(round_input),
    .roundedSig(rounded_sig),
    .overFlow(round_overflow)
);

wire signed [NEXP+1:0] final_exp = e + round_overflow;
wire overflow = (final_exp >= 255); // e >= 255 = Inf exponent
wire underflow = (final_exp < 1); // e < 1
wire [31:0] shift_amount = (underflow && final_exp > -NSIG) ? 
                            (1 - final_exp) : 0;
wire [2*NSIG+1:0] shifted_for_subnormal = m_shifted >> shift_amount;
wire [2*NSIG+1:0] subnormal_round_input;
assign subnormal_round_input[2*NSIG:NSIG+1] = shifted_for_subnormal[14:8];  
assign subnormal_round_input[NSIG] = shifted_for_subnormal[7];             
assign subnormal_round_input[NSIG-1] = shifted_for_subnormal[6];           
assign subnormal_round_input[NSIG-2:0] = |shifted_for_subnormal[5:0];      
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

    if (abfFlags[SNAN] || bbfFlags[SNAN]) begin
        result = nan;
        bfFlags[QNAN] = 1'b1;
        exception[INVALID] = 1'b1;
    end
    else if (abfFlags[QNAN] || bbfFlags[QNAN]) begin
        result = nan;
        bfFlags[QNAN] = 1'b1;
    end
    else if ((abfFlags[INFINITY] && bbfFlags[ZERO]) || (abfFlags[ZERO] && bbfFlags[INFINITY])) begin
        result = nan;
        bfFlags[QNAN] = 1'b1;
        exception[INVALID] = 1'b1;
    end
    else if (abfFlags[INFINITY] || bbfFlags[INFINITY]) begin
        result = inf;
        bfFlags[INFINITY] = 1'b1;
    end
    else if (abfFlags[ZERO] || bbfFlags[ZERO]) begin
        result = zero;
        bfFlags[ZERO] = 1'b1;
    end
    else if (overflow) begin
        result = inf;
        bfFlags[INFINITY] = 1'b1;
        exception[OVERFLOW] = 1'b1;
        exception[INEXACT] = 1'b1;
    end
    else if (underflow) begin
        if ($signed(final_exp) <= $signed(-NSIG)) begin
            result = zero;
            bfFlags[ZERO] = 1'b1;
            exception[UNDERFLOW] = 1'b1;
            exception[INEXACT] = 1'b1;
        end
        else begin
            if (subnormal_overflow && shift_amount == 1) begin
                result = {{1'b0, {(NEXP-1){1'b0}}, 1'b1}, subnormal_rounded_sig};
                bfFlags[NORMAL] = 1'b1;
                exception[INEXACT] = subnormal_round_input[NSIG] | subnormal_round_input[NSIG-1] | |subnormal_round_input[NSIG-2:0];
            end
            else begin
                result = {{NEXP{1'b0}}, subnormal_rounded_sig};
                bfFlags[SUBNORMAL] = 1'b1;
                exception[UNDERFLOW] = 1'b1;
                exception[INEXACT] = 1'b1;
            end
        end
    end
    else begin
        result = {final_exp[NEXP-1:0], rounded_sig};
        bfFlags[NORMAL] = 1'b1;
        exception[INEXACT] = round_input[NSIG] | round_input[NSIG-1] | |round_input[NSIG-2:0];
    end
end
assign p = {sign, result};

endmodule

`endif
