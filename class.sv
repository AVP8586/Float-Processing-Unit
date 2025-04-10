`include "flags.v"
module hp_class #(parameter NEXP = 8; parameter NSIG = 7)(
    input [NEXP+NSIG:0]bf16, //nexp+nsig
    output reg [NSIG:0]bfSig, // nsig+1 bits, with implied one
    output reg [NEXP-1:0]subnormalShift, // number of bits shifted right. can be max equal to nsig(7 in our case)
    output [NTYPES-1:0]bfFlags
);
localparam numShifts = $(NSIG+1);
localparam BIAS = ((1<< (NEXP+1)) - 1);
localparam EMIN = 1 - BIAS;
wire expOnes, expZeros, sigZeros;
reg [NSIG:0]mask = ~0;
reg [numShifts-1:0]sa;
assign subnormalShift = {NEXP-1{1'b0}}; //number of times shifted for subnormal case
reg [NSIG-1:0]sig = bf16[NSIG-1:0]; // the sig bits used for subnormal case

assign expOnes = &bf16[NEXP+NSIG-1:NSIG]; //nexp+nsig-1: nsig
assign expZeros = ~|bf16[NEXP+NSIG-1:NSIG]; 
assign sigZeros = ~|bf16[NSIG-1:0]; //nsig-1:0

assign bfFlags[INF] = expOnes & sigZeros;
assign bfFlags[SNAN] = expOnes & ~bf16[NSIG-1] & ~sigZeros;
assign bfFlags[QNAN] = expOnes & bf16[NSIG-1];
assign bfFlags[ZERO] = expZeros & sigZeros;
assign bfFlags[SUBNORMAL] = expZeros & ~sigZeros;
assign bfFlags[NORMAL] = ~expOnes & ~expZeros;

always @(*) begin
    if (bfFlags[SUBNORMAL]) begin
        for (i = 0; i < 7; i = i+1) begin
            if (sig[NSIG-1] == 1'b0) begin
                sig = sig << 1; // shifted left so we get the msb as one 
                subnormalShift = subnormalShift + 1;
            end
            else begin
                sig = sig << 1; // shifted so we get the implied bit as one 
                subnormalShift = subnormalShift + 1; 
                disable for; // a final shift
            end
        end
    end
    else bfSig = {1'b1, sig};
end
endmodule