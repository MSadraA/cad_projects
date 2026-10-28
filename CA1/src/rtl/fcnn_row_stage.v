`default_nettype none
module fcnn_row_stage #(
    parameter integer LANES=7, META_W=12
) (
    input wire clk, input wire rst,
    input wire in_valid, input wire [16*LANES-1:0] in_data,
    input wire [META_W-1:0] in_meta, input wire consume_row,
    output wire can_accept, output reg stored_valid,
    output reg [16*LANES-1:0] stored_data, output reg [META_W-1:0] stored_meta
);
    // Step 1: one row only; same-edge replacement does not allocate extra storage.
    assign can_accept=!stored_valid || consume_row;
    // Step 2: reset, accept/replace, consume, otherwise hold.
    always @(posedge clk) begin
        if (rst) begin
            stored_valid<=0; stored_data<=0; stored_meta<=0;
        end else begin
            if (in_valid && can_accept) begin
                stored_valid<=1; stored_data<=in_data; stored_meta<=in_meta;
            end else if (consume_row) stored_valid<=0;
            // Step 3: diagnose a calendar error rather than silently losing data.
            // synthesis translate_off
            if (in_valid && !can_accept)
                begin $display("[FAIL] ROW_STAGE overwrite"); $finish; end
            if (consume_row && !stored_valid)
                begin $display("[FAIL] ROW_STAGE empty consume"); $finish; end
            // synthesis translate_on
        end
    end
endmodule
`default_nettype wire
