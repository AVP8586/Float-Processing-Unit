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
localparam BIAS = ((1 << (NEXP - 1)) - 1);  
localparam clog_INTn = $clog2(INTn);        
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

reg [INTn-1:0] sigIn;                      
wire [INTn-1:0] mask;                       
assign mask = {INTn{1'b1}};              

reg [NEXP-1:0] expIn;                       
wire [NEXP-1:0] expOut;                    
wire [NSIG-1:0] sigOut;                   
wire rndoverflow;                        
integer i;                                 

wire [2*NSIG+1:0] pSig;                     

assign inexact = |sigIn[INTn-2-NSIG:0];

always @(*) begin
    sigIn = in[INTn-1] ? (~in + 1) : in;
    
    if (sigIn == 0) begin
        out = {(NEXP+NSIG+1){1'b0}};       
        overflow = 1'b0;
    end
    else begin
        expIn = 0;
        for (i = (1 << (clog_INTn - 1)); i > 0; i = i >> 1) begin
            if ((sigIn & (mask << (INTn - i))) == 0) begin
                sigIn = sigIn << i;
                expIn = expIn | i;
            end
        end

        expIn = (INTn-1) + BIAS - expIn;
        overflow = &expOut;
        
        out[NEXP+NSIG] = in[INTn-1];                   
        out[NEXP+NSIG-1:NSIG] = expOut;               
        out[NSIG-1:0] = overflow ? {NSIG{1'b0}} : sigOut; 
    end
end

assign pSig[2*NSIG+1:NSIG+1] = sigIn[INTn-1:INTn-NSIG-1];
assign pSig[NSIG:0] = sigIn[INTn-NSIG-2:INTn-2*NSIG-2];

round #(.NEXP(NEXP), .NSIG(NSIG)) U0 (.pSig(pSig), .roundedSig(sigOut), .overFlow(rndoverflow));

// Adjust exponent based on rounding overflow
assign expOut = rndoverflow ? (expIn + 1'b1) : expIn;
endmodule
