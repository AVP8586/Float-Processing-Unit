`include "class.sv"

module hp_add #(parameter NEXP = 8, parameter NSIG = 7)(
    input [NEXP+NSIG:0] a, b,
    input operation,  // 0 = add, 1 = subtract
    output reg [NEXP+NSIG:0] s,
    output reg [5:0] bfFlags,
    output reg [4:0] exception
);
flags_defs #(.NEXP(NEXP), .NSIG(NSIG)) flags();
wire [NSIG:0] abfSig, bbfSig;
wire [5:0] abfFlags, bbfFlags;
wire [NEXP-1:0] asubnormalShift, bsubnormalShift;

// Modified classification with sign handling
hp_class #(.NEXP(NEXP), .NSIG(NSIG)) aclass(.bf16(a), .bfSig(abfSig), .subnormalShift(asubnormalShift), .bfFlags(abfFlags));
hp_class #(.NEXP(NEXP), .NSIG(NSIG)) bclass(.bf16(b), .bfSig(bbfSig), .subnormalShift(bsubnormalShift), .bfFlags(bbfFlags));

// Effective sign of b after considering operation
wire effective_b_sign = b[NEXP+NSIG] ^ operation;

// Signals for arithmetic operations
reg result_sign;
reg [NEXP-1:0] result_exp;
reg [NSIG+3:0] a_sig, b_sig;
reg [NSIG+3:0] aligned_a_sig, aligned_b_sig;
reg [NSIG+3:0] sum_sig;
reg [NEXP-1:0] a_exp, b_exp, max_exp;
reg [7:0] exp_diff;
reg add_sigs;
reg a_larger;
reg [4:0] leading_zeros;
reg carry;
reg is_zero_result;

// For rounding
reg guard, round_bit, sticky;
integer i;

always @(*) begin
    bfFlags = 6'b000000;
    exception = 5'b00000;
    result_sign = 1'b0;
    result_exp = 0;
    a_sig = 0;
    b_sig = 0;
    aligned_a_sig = 0;
    aligned_b_sig = 0;
    sum_sig = 0;
    a_exp = 0;
    b_exp = 0;
    max_exp = 0;
    exp_diff = 0;
    add_sigs = 0;
    a_larger = 0;
    leading_zeros = 0;
    carry = 0;
    is_zero_result = 0;
    guard = 0;
    round_bit = 0;
    sticky = 0;
    
    // 1. Exceptional cases first
    if (abfFlags[flags.SNAN] || bbfFlags[flags.SNAN]) begin
        bfFlags[flags.QNAN] = 1'b1;
        s = {1'b0, {NEXP{1'b1}}, 1'b1, {(NSIG-1){1'b0}}};
        exception[flags.INVALID] = 1'b1;
    end
    else if (abfFlags[flags.QNAN] || bbfFlags[flags.QNAN]) begin
        bfFlags[flags.QNAN] = 1'b1;
        s = {1'b0, {NEXP{1'b1}}, 1'b1, {(NSIG-1){1'b0}}};
    end
    else if ((abfFlags[flags.INFINITY] && bbfFlags[flags.INFINITY]) && 
                (a[NEXP+NSIG] != effective_b_sign)) begin
        bfFlags[flags.QNAN] = 1'b1;
        s = {1'b0, {NEXP{1'b1}}, 1'b1, {(NSIG-1){1'b0}}};
        exception[flags.INVALID] = 1'b1;
    end
    else if (abfFlags[flags.INFINITY]) begin
        bfFlags[flags.INFINITY] = 1'b1;
        s = {a[NEXP+NSIG], {NEXP{1'b1}}, {NSIG{1'b0}}};
    end
    else if (bbfFlags[flags.INFINITY]) begin
        bfFlags[flags.INFINITY] = 1'b1;
        s = {effective_b_sign, {NEXP{1'b1}}, {NSIG{1'b0}}};
    end
    else if (abfFlags[flags.ZERO] && bbfFlags[flags.ZERO]) begin
        if (a[NEXP+NSIG] == effective_b_sign) begin
            bfFlags[flags.ZERO] = 1'b1;
            s = {a[NEXP+NSIG], {(NEXP+NSIG){1'b0}}};
        end
        else begin
            bfFlags[flags.ZERO] = 1'b1;
            s = {1'b0, {(NEXP+NSIG){1'b0}}};
        end
    end

    // 2. Subnormal and normal cases
    else if (abfFlags[flags.ZERO]) begin
        if (bbfFlags[flags.NORMAL])
            bfFlags[flags.NORMAL] = 1'b1;
        else if (bbfFlags[flags.SUBNORMAL])
            bfFlags[flags.SUBNORMAL] = 1'b1;
        else
            bfFlags[flags.ZERO] = 1'b1;
        s = {effective_b_sign, b[NEXP+NSIG-1:0]};
    end
    else if (bbfFlags[flags.ZERO]) begin
        if (abfFlags[flags.NORMAL])
            bfFlags[flags.NORMAL] = 1'b1;
        else if (abfFlags[flags.SUBNORMAL])
            bfFlags[flags.SUBNORMAL] = 1'b1;
        else
            bfFlags[flags.ZERO] = 1'b1;
        s = a;
    end
    else begin
        add_sigs = (a[NEXP+NSIG] == effective_b_sign);
        a_exp = abfFlags[flags.SUBNORMAL] ? 1 : a[NEXP+NSIG-1:NSIG];
        b_exp = bbfFlags[flags.SUBNORMAL] ? 1 : b[NEXP+NSIG-1:NSIG];
        
        a_sig = {1'b0, abfFlags[flags.NORMAL] ? 1'b1 : 1'b0, a[NSIG-1:0], 3'b000};
        b_sig = {1'b0, bbfFlags[flags.NORMAL] ? 1'b1 : 1'b0, b[NSIG-1:0], 3'b000};
        
        if (abfFlags[flags.SUBNORMAL])
            a_sig = {1'b0, abfSig, 3'b000};
        if (bbfFlags[flags.SUBNORMAL])
            b_sig = {1'b0, bbfSig, 3'b000};
        
        if (a_exp > b_exp || (a_exp == b_exp && a_sig > b_sig)) begin
            a_larger = 1'b1;
            exp_diff = a_exp - b_exp;
            max_exp = a_exp;
            
            aligned_a_sig = a_sig;
            if (exp_diff > NSIG+3) begin
                aligned_b_sig = 0;
                sticky = |b_sig;
            end else begin
                if (exp_diff > 0) begin
                    sticky = 0;
                    for (i = 0; i < NSIG+3; i = i + 1) begin
                        if (i < exp_diff && b_sig[i])
                            sticky = 1;
                    end
                    aligned_b_sig = b_sig >> exp_diff;
                    if (sticky)
                        aligned_b_sig[0] = 1'b1; 
                end else begin
                    aligned_b_sig = b_sig;
                end
            end
        end
        else begin
            a_larger = 1'b0;
            exp_diff = b_exp - a_exp;
            max_exp = b_exp;
            
            aligned_b_sig = b_sig;
            if (exp_diff > NSIG+3) begin
                aligned_a_sig = 0;
                sticky = |a_sig;
            end else begin
                if (exp_diff > 0) begin
                    sticky = 0;
                    for (i = 0; i < NSIG+3; i = i + 1) begin
                        if (i < exp_diff && a_sig[i])
                            sticky = 1;
                    end
                    aligned_a_sig = a_sig >> exp_diff;
                    if (sticky)
                        aligned_a_sig[0] = 1'b1; 
                end else begin
                    aligned_a_sig = a_sig;
                end
            end
        end
        
        if (add_sigs) begin
            result_sign = a[NEXP+NSIG]; // Both have same sign
        end
        else begin
            result_sign = a_larger ? a[NEXP+NSIG] : effective_b_sign;
        end
        
        if (add_sigs) begin
            {carry, sum_sig} = aligned_a_sig + aligned_b_sig;
            if (carry) begin
                sticky = sum_sig[0];
                sum_sig = sum_sig >> 1;
                if (sticky)
                    sum_sig[0] = 1'b1;
                max_exp = max_exp + 1;
            end
        end
        else begin
            if (a_larger)
                sum_sig = aligned_a_sig - aligned_b_sig;
            else
                sum_sig = aligned_b_sig - aligned_a_sig;
            
            is_zero_result = (sum_sig == 0);
            if (!is_zero_result) begin
                leading_zeros = 0;
                for (i = NSIG+3; i >= 0; i = i-1) begin
                    if (sum_sig[i]) begin
                        leading_zeros = NSIG+3 - i;
                        i = -1; // Breaking loop
                    end
                end
                
                if (leading_zeros > 0) begin
                    if (leading_zeros <= max_exp) begin
                        sum_sig = sum_sig << leading_zeros;
                        max_exp = max_exp - leading_zeros;
                    end
                    else begin
                        sum_sig = sum_sig << (max_exp - 1);
                        max_exp = 0;
                    end
                end
            end
        end
        if (is_zero_result) begin
            bfFlags[flags.ZERO] = 1'b1;
            s = {1'b0, {(NEXP+NSIG){1'b0}}};
        end
        else begin
            guard = sum_sig[2];
            round_bit = sum_sig[1];
            sticky = sum_sig[0] | sticky;
            
            if (guard && (round_bit || sticky || sum_sig[3])) begin
                sum_sig = sum_sig + (1 << 3); // Add 1 to bit 3
                
                if (sum_sig[NSIG+4]) begin
                    sum_sig = sum_sig >> 1;
                    max_exp = max_exp + 1;
                end
            end
            
            if (max_exp >= {NEXP{1'b1}}) begin
                bfFlags[flags.INFINITY] = 1'b1;
                exception[flags.OVERFLOW] = 1'b1;
                s = {result_sign, {NEXP{1'b1}}, {NSIG{1'b0}}};
            end
            else if (max_exp == 0) begin
                if (|sum_sig[NSIG+3:3])
                    bfFlags[flags.SUBNORMAL] = 1'b1;
                else
                    bfFlags[flags.ZERO] = 1'b1;
                
                s = {result_sign, {NEXP{1'b0}}, sum_sig[NSIG+2:3]};
            end
            else begin
                bfFlags[flags.NORMAL] = 1'b1;
                s = {result_sign, max_exp[NEXP-1:0], sum_sig[NSIG+2:3]};
            end
            
            if (guard || round_bit || sticky)
                exception[flags.INEXACT] = 1'b1;
        end
    end
end
endmodule
