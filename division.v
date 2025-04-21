`include "class.sv"
`include "round.v"
`include "reciprocal.v"
`include "mul.v"

module hp_div #(parameter NEXP = 8, parameter NSIG = 7)(
    input [NEXP+NSIG:0] a, b,
    output [NEXP+NSIG:0] q,
    output [5:0] bfFlags,
    output [4:0] exception
);
flags_defs #(.NEXP(8), .NSIG(7)) flags();
wire [NEXP+NSIG-1:0] zero = {(NEXP+NSIG){1'b0}};
wire [NEXP+NSIG-1:0] inf = {{NEXP{1'b1}}, {NSIG{1'b0}}};
wire [NEXP+NSIG-1:0] nan = {{NEXP{1'b1}}, 1'b1, {(NSIG-1){1'b0}}};
wire [NSIG:0] abfSig, bbfSig;
wire [5:0] abfFlags, bbfFlags;
wire [NEXP-1:0] asubnormalShift, bsubnormalShift;
wire [NEXP+NSIG:0] brecip;

hp_class aclass(.bf16(a), .bfSig(abfSig), .subnormalShift(asubnormalShift), .bfFlags(abfFlags));
reciprocal ofB(.A(b), .Arecip(brecip), .recipFlags(bbfFlags)); //we get brecip's flags here.
hp_class bclass(.bf16(brecip), .bfSig(bbfSig), .subnormalShift(bsubnormalShift), .bfFlags());

hp_mul div(.a(a), .b(brecip), .p(q), .bfFlags(bfFlags), .exception(exception));

endmodule