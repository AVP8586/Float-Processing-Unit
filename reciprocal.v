`include "recipSub.v"

module reciprocal #(parameter NEXP = 8,               
parameter NSIG = 7)(
    input [NEXP+NSIG:0] A,     
    output reg [NEXP+NSIG:0] Arecip,
    output reg [5:0]recipFlags
);

assign sign = A[NEXP+NSIG]; // sign bit
flags_defs #(.NEXP(8), .NSIG(7)) flags();
wire [NSIG:0] ASig;
wire [5:0] AbfFlags;
wire [NEXP-1:0] AsubnormalShift;
reg [NEXP-1:0]Aexp, ArecipExp, N_max_1, N_max;
wire [NSIG:0]ArecipSig_wire;
reg [NSIG:0]ArecipSig;
hp_class aclass(.bf16(A), .bfSig(ASig), .subnormalShift(AsubnormalShift), .bfFlags(AbfFlags));
reciprocalSub recipA(.A(ASig), .R(ArecipSig_wire));

always @(*) begin
    N_max = (1 << NEXP) - 2;
    N_max_1 = N_max - 1;
    Aexp = A[NSIG+NEXP-1:NSIG];
    ArecipSig = ArecipSig_wire;
    recipFlags = 6'b000000;
    if (AbfFlags[flags.INFINITY]) begin
        recipFlags = 6'b000000;
        Arecip = {sign, flags.zero}; //complete
        recipFlags[flags.ZERO] = 1;
    end
    else if (|AbfFlags[flags.SNAN:flags.QNAN]) begin
        recipFlags = 6'b000000;
        Arecip = {sign, flags.nan}; //complete
        recipFlags[flags.QNAN] = 1;
    end
    else if (AbfFlags[flags.ZERO]) begin
        recipFlags = 6'b000000;
        Arecip = {sign, flags.inf}; //complete
        recipFlags[flags.INFINITY] = 1;
    end
    else if (AbfFlags[flags.SUBNORMAL]) begin
        if (Aexp - AsubnormalShift == 0) begin
            recipFlags = 6'b000000;
            ArecipExp = N_max;
            Arecip = {sign, ArecipExp, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[flags.NORMAL] = 1;
        end
        else if (AsubnormalShift - Aexp == 1) begin
            recipFlags = 6'b000000;
            ArecipExp = N_max + 1;
            Arecip = {sign, ArecipExp, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[flags.NORMAL] = 1;
        end
        else begin
            recipFlags = 6'b000000;
            Arecip = {sign, flags.inf}; //complete
            recipFlags[flags.INFINITY] = 1;
        end
    end
    else if (AbfFlags[flags.NORMAL]) begin
        if (Aexp == N_max_1) begin //shift recipsig by 1 pos, ignore leading one
            recipFlags = 6'b000000;
            ArecipSig = ArecipSig >> 1;
            Arecip = {sign, {(NEXP-1){1'b0}}, 1'b1, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[flags.SUBNORMAL] = 1;
        end
        else if (Aexp == N_max) begin
            recipFlags = 6'b000000;
            ArecipSig = ArecipSig >> 2;
            Arecip = {sign, {(NEXP-1){1'b0}}, 1'b1, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[flags.SUBNORMAL] = 1;
        end
        else begin
            recipFlags = 6'b000000;
            ArecipExp = (N_max_1 - Aexp) + 1;
            Arecip = {sign, ArecipExp, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[flags.NORMAL] = 1;
        end
    end
end
endmodule
