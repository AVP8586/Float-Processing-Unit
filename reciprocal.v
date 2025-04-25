module reciprocal #(parameter NEXP = 8,               
parameter NSIG = 7)(
    input [NEXP+NSIG:0] A,     
    output reg [NEXP+NSIG:0] Arecip,
    output reg [5:0]recipFlags
);
localparam NORMAL    = 0;
localparam SUBNORMAL = NORMAL + 1; // 1
localparam ZERO      = SUBNORMAL + 1; //2 
localparam INFINITY  = ZERO + 1; //3
localparam QNAN      = INFINITY + 1; //4
localparam SNAN      = QNAN + 1; //5

localparam BIAS = ((1 << (NEXP - 1)) - 1); 
localparam EMAX = BIAS; 
localparam EMIN = (1 - EMAX); 

localparam [NEXP+NSIG-1:0]nan = {{NEXP+1{1'b1}}, {NSIG-1{1'b0}}};
localparam [NEXP+NSIG-1:0]inf = {{NEXP{1'b1}}, {NSIG{1'b0}}};
localparam [NEXP+NSIG-1:0]zero = {(NEXP+NSIG){1'b0}};
localparam roundTiesToEven     = 0;
                            
localparam INVALID             = 0;
localparam DIVIDEBYZERO        = 1;
localparam OVERFLOW            = 2;
localparam UNDERFLOW           = 3;
localparam INEXACT             = 4;

assign sign = A[NEXP+NSIG]; // sign bit
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
    if (AbfFlags[INFINITY]) begin
        recipFlags = 6'b000000;
        Arecip = {sign, zero}; //complete
        recipFlags[ZERO] = 1;
    end
    else if (|AbfFlags[SNAN:QNAN]) begin
        recipFlags = 6'b000000;
        Arecip = {sign, nan}; //complete
        recipFlags[QNAN] = 1;
    end
    else if (AbfFlags[ZERO]) begin
        recipFlags = 6'b000000;
        Arecip = {sign, inf}; //complete
        recipFlags[INFINITY] = 1;
    end
    else if (AbfFlags[SUBNORMAL]) begin
        if (Aexp - AsubnormalShift == 0) begin
            recipFlags = 6'b000000;
            ArecipExp = N_max;
            Arecip = {sign, ArecipExp, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[NORMAL] = 1;
        end
        else if (AsubnormalShift - Aexp == 1) begin
            recipFlags = 6'b000000;
            ArecipExp = N_max + 1;
            Arecip = {sign, ArecipExp, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[NORMAL] = 1;
        end
        else begin
            recipFlags = 6'b000000;
            Arecip = {sign, inf}; //complete
            recipFlags[INFINITY] = 1;
        end
    end
    else if (AbfFlags[NORMAL]) begin
        if (Aexp == N_max_1) begin //shift recipsig by 1 pos, ignore leading one
            recipFlags = 6'b000000;
            ArecipSig = ArecipSig >> 1;
            Arecip = {sign, {(NEXP-1){1'b0}}, 1'b1, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[SUBNORMAL] = 1;
        end
        else if (Aexp == N_max) begin
            recipFlags = 6'b000000;
            ArecipSig = ArecipSig >> 2;
            Arecip = {sign, {(NEXP-1){1'b0}}, 1'b1, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[SUBNORMAL] = 1;
        end
        else begin
            recipFlags = 6'b000000;
            ArecipExp = (N_max_1 - Aexp) + 1;
            Arecip = {sign, ArecipExp, ArecipSig[NSIG-1:0]}; //complete
            recipFlags[NORMAL] = 1;
        end
    end
end
endmodule
