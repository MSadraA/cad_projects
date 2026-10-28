`default_nettype none
module fcnn_accumulator_bank #(
    parameter integer N_HIDDEN=8, N_OUTPUTS=10
) (
    clk,
    rst,
    run_init,
    layer_sel,
    product_valid,
    product_ready,
    product_data,
    product_dest,
    product_last,
    bias_neuron,
    fc1_bias,
    fc2_biases,
    add_a,
    add_b,
    add_result,
    add_commit,
    fc1_final_valid,
    fc1_final_value,
    fc1_final_idx,
    fc2_all_committed,
    fc2_results
);
    // Step 1: one FC1 accumulator and N_OUTPUTS FC2 accumulators, initially zero.
    localparam integer H_W=(N_HIDDEN>1)?$clog2(N_HIDDEN):1;
    localparam integer O_W=(N_OUTPUTS>1)?$clog2(N_OUTPUTS):1;
    localparam integer MAX_NEURONS=(N_HIDDEN>N_OUTPUTS)?N_HIDDEN:N_OUTPUTS;
    localparam integer DEST_W=(MAX_NEURONS>1)?$clog2(MAX_NEURONS):1;

    // Port widths are declared after derived constants for ModelSim 2020.
    input wire clk;
    input wire rst;
    input wire run_init;
    input wire layer_sel;
    input wire product_valid;
    output wire product_ready;
    input wire [15:0] product_data;
    input wire [DEST_W-1:0] product_dest;
    input wire product_last;
    output wire [H_W-1:0] bias_neuron;
    input wire [15:0] fc1_bias;
    input wire [16*N_OUTPUTS-1:0] fc2_biases;
    output wire [15:0] add_a;
    output wire [15:0] add_b;
    input wire [15:0] add_result;
    output wire add_commit;
    output wire fc1_final_valid;
    output wire [15:0] fc1_final_value;
    output wire [H_W-1:0] fc1_final_idx;
    output wire fc2_all_committed;
    output wire [16*N_OUTPUTS-1:0] fc2_results;

    reg [15:0] fc1_acc;
    reg [15:0] fc2_acc[0:N_OUTPUTS-1];
    reg [N_OUTPUTS-1:0] committed;
    reg bias_pending;
    reg [DEST_W-1:0] pending_dest;
    wire [DEST_W-1:0] active_dest=bias_pending?pending_dest:product_dest;
    wire consume_product=product_valid && product_ready;
    // Step 2: the SAME adder handles products and, one edge later, final bias.
    assign product_ready=!bias_pending;
    assign bias_neuron=active_dest[H_W-1:0];
    assign add_a=layer_sel ? ((active_dest<N_OUTPUTS)?fc2_acc[active_dest[O_W-1:0]]:16'd0) : fc1_acc;
    assign add_b=bias_pending ?
        (layer_sel ? fc2_biases[16*active_dest+:16] : fc1_bias) : product_data;
    assign add_commit=bias_pending || consume_product;
    assign fc1_final_valid=!layer_sel && bias_pending;
    assign fc1_final_value=add_result;
    assign fc1_final_idx=active_dest[H_W-1:0];
    // Step 3: look ahead at the final bias commit, including its live result.
    wire [N_OUTPUTS-1:0] current_final=(layer_sel && bias_pending) ?
        ({{(N_OUTPUTS-1){1'b0}},1'b1}<<active_dest) : {N_OUTPUTS{1'b0}};
    assign fc2_all_committed=&(committed | current_final);
    genvar k;
    generate for (k=0;k<N_OUTPUTS;k=k+1) begin: g_result
        assign fc2_results[16*k+:16]=(layer_sel && add_commit && active_dest==k) ? add_result : fc2_acc[k];
    end endgenerate
    // Step 4: finalize each neuron only after its separate final bias operation.
    integer j;
    always @(posedge clk) begin
        if (rst || run_init) begin
            fc1_acc<=0; committed<=0; bias_pending<=0; pending_dest<=0;
            for (j=0;j<N_OUTPUTS;j=j+1) fc2_acc[j]<=0;
        end else begin
            if (bias_pending) begin
                bias_pending<=0;
                if (layer_sel) begin
                    fc2_acc[pending_dest[O_W-1:0]]<=add_result;
                    committed[pending_dest[O_W-1:0]]<=1;
                end else fc1_acc<=0;
            end else if (consume_product) begin
                if (layer_sel) fc2_acc[product_dest[O_W-1:0]]<=add_result;
                else fc1_acc<=add_result;
                if (product_last) begin bias_pending<=1;pending_dest<=product_dest;end
            end
            // synthesis translate_off
            if (consume_product && (layer_sel ? product_dest>=N_OUTPUTS : product_dest>=N_HIDDEN))
                begin $display("[FAIL] ACCUMULATOR invalid destination"); $finish; end
            // synthesis translate_on
        end
    end
endmodule
`default_nettype wire
