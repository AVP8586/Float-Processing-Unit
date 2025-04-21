`include "flags.v"
`include "round.v"

module hp_cvtsw #(
    parameter INTn = 32,
    parameter NEXP = 8,
    parameter NSIG = 7
)(
    input signed [INTn-1:0] in,
    output reg [NEXP+NSIG:0] out,
    output inexact,
    output reg overflow
);
    // Constants
    localparam BIAS = ((1 << (NEXP - 1)) - 1);  // 127 for bfloat16
    localparam clog_INTn = $clog2(INTn);        // log2 of input width
    flags_defs #(.NEXP(8), .NSIG(7)) flags();
    // Internal signals
    reg [INTn-1:0] sigIn;                       // Absolute value of input
    wire [INTn-1:0] mask;                       // Mask for leading one detection
    assign mask = {INTn{1'b1}};                 // Full mask for comparison
    
    reg [NEXP-1:0] expIn;                       // Calculated exponent
    wire [NEXP-1:0] expOut;                     // Final exponent after rounding
    wire [NSIG-1:0] sigOut;                     // Final significand after rounding
    wire round_overflow;                        // Overflow from rounding
    integer i;                                  // Loop counter
    
    // Prepare significand for rounding
    wire [2*NSIG+1:0] pSig;                     // Double-width significand for rounding
    
    // Inexact flag - set when bits are lost in conversion
    assign inexact = |sigIn[INTn-2-NSIG:0];
    
    always @(*) begin
        // Step 1: Convert to absolute value
        sigIn = in[INTn-1] ? (~in + 1) : in;
        
        // Step 2: Handle zero case
        if (sigIn == 0) begin
            out = {(NEXP+NSIG+1){1'b0}};       // Return +0.0
            overflow = 1'b0;
        end
        else begin
            // Step 3: Find position of leading 1 (binary search)
            expIn = 0;
            for (i = (1 << (clog_INTn - 1)); i > 0; i = i >> 1) begin
                if ((sigIn & (mask << (INTn - i))) == 0) begin
                    sigIn = sigIn << i;
                    expIn = expIn | i;
                end
            end
            
            // Step 4: Calculate exponent
            expIn = (INTn-1) + BIAS - expIn;
            
            // Step 6: Check for overflow in exponent
            overflow = &expOut;
            
            // Step 7: Assemble the result
            out[NEXP+NSIG] = in[INTn-1];                   // Sign bit
            out[NEXP+NSIG-1:NSIG] = expOut;                // Exponent
            out[NSIG-1:0] = overflow ? {NSIG{1'b0}} : sigOut; // Significand
        end
    end
    
    // Prepare significand for rounding
    // The top NSIG+1 bits (including implied 1) are in sigIn[INTn-1:INTn-NSIG-1]
    // We need to format this for the round module
    assign pSig[2*NSIG+1:NSIG+1] = sigIn[INTn-1:INTn-NSIG-1];
    assign pSig[NSIG:0] = sigIn[INTn-NSIG-2:INTn-2*NSIG-2];
    
    // Call the round module
    round #(
        .NEXP(NEXP),
        .NSIG(NSIG)
    ) U0 (
        .pSig(pSig),
        .roundedSig(sigOut),
        .overFlow(round_overflow)
    );
    
    // Adjust exponent based on rounding overflow
    assign expOut = round_overflow ? (expIn + 1'b1) : expIn;
    
endmodule
