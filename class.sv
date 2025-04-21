module hp_class #(parameter NEXP = 8,
parameter NSIG = 7)(
    input [NEXP+NSIG:0]bf16, //nexp+nsig
    output reg [NSIG:0]bfSig, // nsig+1 bits, with implied one
    output reg [NEXP-1:0]subnormalShift, // number of bits shifted right. can be max equal to nsig(7 in our case)
    output [5:0]bfFlags
);
flags_defs #(.NEXP(8), .NSIG(7)) flags();
localparam numShifts = NSIG+1;
wire expOnes, expZeros, sigZeros;
reg [NSIG:0]mask;
reg [numShifts-1:0]sa;
reg [NSIG-1:0]sig; // the sig bits used for subnormal case
reg done;

assign expOnes = &bf16[NEXP+NSIG-1:NSIG]; //nexp+nsig-1: nsig
assign expZeros = ~|bf16[NEXP+NSIG-1:NSIG]; 
assign sigZeros = ~|bf16[NSIG-1:0]; //nsig-1:0

assign bfFlags[flags.INFINITY] = expOnes & sigZeros;
assign bfFlags[flags.SNAN] = expOnes & ~bf16[NSIG-1] & ~sigZeros;
assign bfFlags[flags.QNAN] = expOnes & bf16[NSIG-1];
assign bfFlags[flags.ZERO] = expZeros & sigZeros;
assign bfFlags[flags.SUBNORMAL] = expZeros & ~sigZeros;
assign bfFlags[flags.NORMAL] = ~expOnes & ~expZeros;
integer i;

always @(*) begin
    done = 0;
    mask = {NSIG+1{1'b1}};
    subnormalShift = {NEXP-1{1'b0}};
    sig = bf16[NSIG-1:0];
    if (bfFlags[flags.SUBNORMAL]) begin
        for (i = 0; i < 7 && !done; i = i+1) begin
            if (sig[NSIG-1] == 1'b0) begin
                sig = sig << 1; // shifted left so we get the msb as one 
                subnormalShift = subnormalShift + 1;
            end
            else begin
                sig = sig << 1; // shifted so we get the implied bit as one 
                subnormalShift = subnormalShift + 1; 
                done = 1;; // a final shift
            end
        end
        // bfSig = {1'b1, sig};
    end
    bfSig = {1'b1, sig};
end
endmodule