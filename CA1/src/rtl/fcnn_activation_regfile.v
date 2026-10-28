`default_nettype none
module fcnn_activation_regfile #(
    parameter integer N_HIDDEN=8, N_OUTPUTS=10
) (
    clk,
    rst,
    run_init,
    hidden_wr_en,
    hidden_wr_idx,
    hidden_wr_data,
    hidden_rd_idx,
    hidden_rd_data,
    hidden_all_valid,
    final_wr_en,
    final_wr_data,
    final_ready,
    logits
);
    localparam integer H_W=(N_HIDDEN>1)?$clog2(N_HIDDEN):1;
    localparam integer RF_DEPTH=(N_HIDDEN>N_OUTPUTS)?N_HIDDEN:N_OUTPUTS;
    // Step 1: reuse one RF; no duplicate hidden/output storage array.

    // Port widths are declared after derived constants for ModelSim 2020.
    input wire clk;
    input wire rst;
    input wire run_init;
    input wire hidden_wr_en;
    input wire [H_W-1:0] hidden_wr_idx;
    input wire [15:0] hidden_wr_data;
    input wire [H_W-1:0] hidden_rd_idx;
    output wire [15:0] hidden_rd_data;
    output wire hidden_all_valid;
    input wire final_wr_en;
    input wire [16*N_OUTPUTS-1:0] final_wr_data;
    output reg final_ready;
    output wire [16*N_OUTPUTS-1:0] logits;

    reg [15:0] rf_mem[0:RF_DEPTH-1];
    reg [N_HIDDEN-1:0] hidden_mask;
    integer j;
    // Step 2: validity clears for each run; reset also clears RF payload.
    always @(posedge clk) begin
        if (rst) begin
            hidden_mask<=0;final_ready<=0;
            for (j=0;j<RF_DEPTH;j=j+1) rf_mem[j]<=0;
        end else if (run_init) begin
            hidden_mask<=0;final_ready<=0;
        end else if (final_wr_en) begin
            for (j=0;j<N_OUTPUTS;j=j+1) rf_mem[j]<=final_wr_data[16*j+:16];
            final_ready<=1;
        end else if (hidden_wr_en) begin
            rf_mem[hidden_wr_idx]<=hidden_wr_data;
            hidden_mask[hidden_wr_idx]<=1;
        end
        // synthesis translate_off
        if (!rst && hidden_wr_en && final_wr_en)
            begin $display("[FAIL] RF conflicting hidden/final writes"); $finish; end
        // synthesis translate_on
    end
    // Step 3: asynchronous read and parallel packed logits, index zero in LSBs.
    assign hidden_rd_data=(hidden_rd_idx<N_HIDDEN)?rf_mem[hidden_rd_idx]:16'd0;
    assign hidden_all_valid=&hidden_mask;
    genvar k;
    generate for (k=0;k<N_OUTPUTS;k=k+1) begin: g_logits
        assign logits[16*k+:16]=rf_mem[k];
    end endgenerate
endmodule
`default_nettype wire
