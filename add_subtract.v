`include "class.sv"
`include "add.v"

module hp_add_subtract(
    input [NEXP+NSIG:0]a, b, 
    output [NEXP+NSIG:0]result,
    output reg [NTYPES-1:0]bfFlags,
    output reg [NEXCEPTIONS-1:0]exception // handle later.
);
localparam signbit = NEXP+NSIG;
reg sign;
always @(*) begin
    if (a[signbit] ^ b[signbit] == 1'b1) begin
        if ((a[signbit-1:NSIG] > b[signbit-1:NSIG]) || (a[signbit-1:NSIG] == b[signbit-1:NSIG] && a[NSIG-1:0] > b[NSIG-1:0])) begin
            sign = a[signbit];
        end
        else begin
            sign = b[signbit];
        end
        a[signbit] = sign;
        b[signbit] = sign;
    end
end

hp_add add_subtract(.a(a), .b(b), .s(result), .bfFlags(bfFlags), .exception(exception));

endmodule