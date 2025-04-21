`include "class.sv"
`include "add.v"

module hp_add_subtract #(parameter NEXP = 8, NSIG = 7)(
    input [NEXP+NSIG:0] a, b,
    input operation,  // 0 = add, 1 = subtract
    output [NEXP+NSIG:0] result,
    output reg [5:0] bfFlags,
    output reg [4:0] exception
);
    localparam signbit = NEXP + NSIG;
    flags_defs #(.NEXP(8), .NSIG(7)) flags();

    // Effective operands after sign modification
    wire [NEXP+NSIG:0] effective_b = {operation ? ~b[signbit] : b[signbit], b[signbit-1:0]};
    reg actual_operation;
    reg result_sign;

    // Magnitude comparison logic
    always @(*) begin
        // Default values
        actual_operation = operation;
        result_sign = a[signbit];
        
        // Handle sign comparison and magnitude check
        if (a[signbit] ^ effective_b[signbit]) begin
            if (a[signbit-1:0] > effective_b[signbit-1:0]) begin
                result_sign = a[signbit];
                actual_operation = 1'b0;  // Effective subtraction
            end else begin
                result_sign = effective_b[signbit];
                actual_operation = 1'b0;  // Effective subtraction
            end
        end
    end

    // Instantiate the adder core
    hp_add add_core (
        .a({result_sign, a[signbit-1:0]}),
        .b({result_sign, effective_b[signbit-1:0]}),
        .operation(actual_operation),
        .s(result),
        .bfFlags(bfFlags),
        .exception(exception)
    );

    // Final sign assignment
    assign result[signbit] = result_sign;
endmodule
