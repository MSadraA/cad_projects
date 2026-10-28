`default_nettype none
module fcnn_relu_fp16 (input wire [15:0] x, output wire [15:0] y);
    // Step 1: canonicalize any NaN; map every non-NaN negative to positive zero.
    wire is_nan=(x[14:10]==5'h1f) && (x[9:0]!=0);
    assign y=is_nan ? 16'h7e00 : (x[15] ? 16'h0000 : x);
endmodule
`default_nettype wire
