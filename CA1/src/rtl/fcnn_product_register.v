`default_nettype none
module fcnn_product_register #(parameter integer DEST_W=4) (
    input wire clk, input wire rst,
    input wire in_valid, output wire in_ready,
    input wire [15:0] in_data, input wire [DEST_W-1:0] in_dest,
    input wire in_last, input wire in_group_last,
    output reg out_valid, input wire out_ready,
    output reg [15:0] out_data, output reg [DEST_W-1:0] out_dest,
    output reg out_last, output reg out_group_last
);
    // Step 1: one elastic payload register, including every sideband bit.
    assign in_ready=!out_valid || out_ready;
    // Step 2: replace on ready, clear valid on a pop without a replacement.
    always @(posedge clk) begin
        if (rst) begin
            out_valid<=0; out_data<=0; out_dest<=0; out_last<=0; out_group_last<=0;
        end else if (in_ready) begin
            out_valid<=in_valid;
            if (in_valid) begin
                out_data<=in_data; out_dest<=in_dest;
                out_last<=in_last; out_group_last<=in_group_last;
            end
        end
    end
endmodule
`default_nettype wire
