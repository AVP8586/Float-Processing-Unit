module reciprocalSub #(parameter NEXP = 8, parameter NSIG = 7)(
    input [NSIG:0] A,  // assume 1.xxxxxxx form
    output reg [NSIG:0] R
);
reg [2*NSIG+1:0] Ax0, diff1, prod1;
reg [2*NSIG+1:0] Ax1, diff2, prod2;
reg [2*NSIG+1:0] Ax2, diff3, prod3;

reg [NSIG+1:0] two;
reg [NSIG:0] guess;

always @(*) begin
    if (A == {1'b1, {NSIG{1'b0}}}) begin
        R = {1'b1, {NSIG{1'b0}}}; 
    end else begin
        two = 2 << NSIG;              // 2.0
        guess = {1'b0, {NSIG{1'b1}}}; // ~0.992 

        // 1st iteration
        Ax0 = A * guess;             // Q2.2NSIG
        Ax0 = Ax0 >> NSIG;           // Back to Q1.NSIG
        diff1 = two - (Ax0 >> 1);    // Q1.NSIG
        prod1 = guess * diff1;       // Q2.2NSIG
        prod1 = prod1 >> NSIG;       // Q1.NSIG

        // 2nd iteration
        Ax1 = A * prod1[NSIG:0];
        Ax1 = Ax1 >> NSIG;
        diff2 = two - (Ax1 >> 1);
        prod2 = prod1[NSIG:0] * diff2;
        prod2 = prod2 >> NSIG;

        // 3rd iteration
        Ax2 = A * prod2[NSIG:0];
        Ax2 = Ax2 >> NSIG;
        diff3 = two - (Ax2 >> 1);
        prod3 = prod2[NSIG:0] * diff3;
        prod3 = prod3 >> NSIG;

        // Final result
        R = prod3[NSIG:0];
    end
end
endmodule
