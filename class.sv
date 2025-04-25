module hp_class #(parameter NEXP = 8,
parameter NSIG = 7)(
    input [NEXP+NSIG:0]bf16, //nexp+nsig
    output reg [NSIG:0]bfSig, // nsig+1 bits, with implied one
    output reg [NEXP-1:0]subnormalShift, // number of bits shifted right. can be max equal to nsig(7 in our case)
    output [5:0]bfFlags
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

localparam numShifts = NSIG+1;
wire expOnes, expZeros, sigZeros;
reg [NSIG:0]mask;
reg [numShifts-1:0]sa;
reg [NSIG-1:0]sig; // the sig bits used for subnormal case
reg done;

assign expOnes = &bf16[NEXP+NSIG-1:NSIG]; //nexp+nsig-1: nsig
assign expZeros = ~|bf16[NEXP+NSIG-1:NSIG]; 
assign sigZeros = ~|bf16[NSIG-1:0]; //nsig-1:0

assign bfFlags[INFINITY] = expOnes & sigZeros;
assign bfFlags[SNAN] = expOnes & ~bf16[NSIG-1] & ~sigZeros;
assign bfFlags[QNAN] = expOnes & bf16[NSIG-1];
assign bfFlags[ZERO] = expZeros & sigZeros;
assign bfFlags[SUBNORMAL] = expZeros & ~sigZeros;
assign bfFlags[NORMAL] = ~expOnes & ~expZeros;
integer i;

always @(*) begin
    done = 0;
    mask = {NSIG+1{1'b1}};
    subnormalShift = {NEXP-1{1'b0}};
    sig = bf16[NSIG-1:0];
    if (bfFlags[SUBNORMAL]) begin
        for (i = 0; i < 7 && !done; i = i+1) begin
            if (!done) begin
                if (sig[NSIG-1] == 1'b0) begin
                    sig = sig << 1; // shifted left so we get the msb as one 
                    subnormalShift = subnormalShift + 1;
                end
                else begin
                    sig = sig << 1; // shifted so we get the implied bit as one 
                    subnormalShift = subnormalShift + 1; 
                    done = 1; // a final shift
                end 
            end
        end
        // bfSig = {1'b1, sig};
    end
    bfSig = {1'b1, sig};
end
endmodule