localparam NORMAL    = 0;
localparam SUBNORMAL = NORMAL + 1; // 1
localparam ZERO      = SUBNORMAL + 1; //2 
localparam INFINITY  = ZERO + 1; //3
localparam QNAN      = INFINITY + 1; //4
localparam SNAN      = QNAN + 1; //5
localparam NTYPES    = SNAN + 1; //6

localparam BIAS = ((1 << (NEXP - 1)) - 1); 
localparam EMAX = BIAS; 
localparam EMIN = (1 - EMAX); 

localparam [NEXP+NSIG-1:0]nan = {NEXP+1{1'b1}, NSIG-1{1'b0}};
localparam [NEXP+NSIG-1:0]inf = {NEXP{1'b1}, NSIG{1'b0}};
localparam [NEXP+NSIG-1:0]zero = {NEXP+NSIG{1'b0}};
localparam roundTiesToEven     = 0;
                            
localparam INVALID             = 0;
localparam DIVIDEBYZERO        = 1;
localparam OVERFLOW            = 2;
localparam UNDERFLOW           = 3;
localparam INEXACT             = 4;
localparam NEXCEPTIONS     = INEXACT+1;