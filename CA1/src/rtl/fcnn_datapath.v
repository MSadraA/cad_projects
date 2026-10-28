`default_nettype none
module fcnn_datapath #(
    parameter integer N_INPUTS=784, N_HIDDEN=8, N_OUTPUTS=10, LANES=7, SRAM_LATENCY=7,
    parameter FC1_WEIGHTS_FILE="fc1_weights.mem", FC2_WEIGHTS_FILE="fc2_weights.mem",
    parameter INPUT_FILE="test_image.mem", FC1_BIAS_FILE="fc1_bias.mem", FC2_BIAS_FILE="fc2_bias.mem"
) (
    clk,
    rst,
    run_init,
    fc1_active,
    fc2_active,
    fc1_finished,
    fc2_finished,
    logits,
    predicted_digit
);
    // Step 1: derived sizes and named interconnect. No user configuration here.
    localparam integer FC1_ROWS=(N_INPUTS+LANES-1)/LANES;
    localparam integer FC2_ROWS=(N_HIDDEN*N_OUTPUTS+LANES-1)/LANES;
    localparam integer H_W=(N_HIDDEN>1)?$clog2(N_HIDDEN):1;
    localparam integer INDEX_W=(N_OUTPUTS>1)?$clog2(N_OUTPUTS):1;
    localparam integer MAX_NEURONS=(N_HIDDEN>N_OUTPUTS)?N_HIDDEN:N_OUTPUTS;
    localparam integer DEST_W=(MAX_NEURONS>1)?$clog2(MAX_NEURONS):1;
    localparam integer R1_W=(FC1_ROWS>1)?$clog2(FC1_ROWS):1;
    localparam integer R2_W=(FC2_ROWS>1)?$clog2(FC2_ROWS):1;
    localparam integer ROW_W=$clog2(((FC1_ROWS>FC2_ROWS)?FC1_ROWS:FC2_ROWS)+1);
    localparam integer META_W=1+H_W+ROW_W;
    localparam integer ADDR_W=(N_HIDDEN*FC1_ROWS+FC2_ROWS>1)?$clog2(N_HIDDEN*FC1_ROWS+FC2_ROWS):1;
    localparam integer LANE_W=(LANES>1)?$clog2(LANES):1;

    // Port widths are declared after derived constants for ModelSim 2020.
    input wire clk;
    input wire rst;
    input wire run_init;
    input wire fc1_active;
    input wire fc2_active;
    output wire fc1_finished;
    output wire fc2_finished;
    output wire [16*N_OUTPUTS-1:0] logits;
    output wire [INDEX_W-1:0] predicted_digit;

    wire [H_W-1:0] request_neuron;
    wire [R1_W-1:0] request_fc1_row, input_addr;
    wire [R2_W-1:0] request_fc2_row;
    wire [ADDR_W-1:0] weight_addr;
    wire [META_W-1:0] weight_request_meta, input_request_meta;
    wire request_layer, weight_req, input_req, consume_weight_row, consume_input_row;
    wire [LANE_W-1:0] lane_idx;
    wire mul_issue, group_last;
    wire weight_sram_valid, input_sram_valid, weight_available, input_available;
    wire [16*LANES-1:0] weight_sram_data, input_sram_data, weight_stage_data, input_stage_data;
    wire [META_W-1:0] weight_sram_meta, input_sram_meta, weight_stage_meta, input_stage_meta;
    wire compute_layer=weight_stage_meta[META_W-1];
    wire [ROW_W-1:0] compute_row=weight_stage_meta[ROW_W-1:0];
    wire [H_W-1:0] hidden_rd_idx, bias_neuron, fc1_final_idx;
    wire [15:0] hidden_rd_data, mul_weight, mul_input, mul_result;
    wire term_valid, term_last, activation_last_term;
    wire [DEST_W-1:0] term_dest;
    wire product_ready, pp_wr_ready, pp_wr_valid, pp_wr_last, pp_wr_group_last;
    wire [15:0] pp_wr_data, pp_rd_data;
    wire [DEST_W-1:0] pp_wr_dest, pp_rd_dest;
    wire pp_rd_valid, pp_rd_ready, pp_rd_last;
    wire [15:0] add_a, add_b, add_result, fc1_bias, fc1_final_value, relu_out;
    wire [16*N_OUTPUTS-1:0] fc2_biases, fc2_results;
    wire add_commit, fc1_final_valid, hidden_all_valid, fc2_all_committed;
    wire rf_final_we, final_ready, argmax_valid;
    wire pipe_reset=rst || run_init;
    // Step 2: request address ownership and the two synchronous SRAM row paths.
    fcnn_address_generator #(
        .N_INPUTS(N_INPUTS),.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS),.LANES(LANES)
    ) address_inst (
        .clk(clk),.rst(rst),.run_init(run_init),.request_layer(request_layer),.advance_row(weight_req),
        .fc1_neuron(request_neuron),.fc1_row(request_fc1_row),.fc2_row(request_fc2_row),
        .weight_addr(weight_addr),.input_addr(input_addr),.weight_meta(weight_request_meta),.input_meta(input_request_meta)
    );
    fcnn_row_sram #(
        .N_INPUTS(N_INPUTS),.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS),.LANES(LANES),
        .SRAM_LATENCY(SRAM_LATENCY),.SOURCE_KIND(1),
        .INIT_FILE(FC1_WEIGHTS_FILE),.FC2_WEIGHTS_FILE(FC2_WEIGHTS_FILE)
    ) weight_sram_inst (
        .clk(clk),.rst(pipe_reset),.req_valid(weight_req),.req_addr(weight_addr),.req_meta(weight_request_meta),
        .row_valid(weight_sram_valid),.row_data(weight_sram_data),.row_meta(weight_sram_meta)
    );
    fcnn_row_sram #(
        .N_INPUTS(N_INPUTS),.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS),.LANES(LANES),
        .SRAM_LATENCY(SRAM_LATENCY),.SOURCE_KIND(0),.INIT_FILE(INPUT_FILE),.FC2_WEIGHTS_FILE(FC2_WEIGHTS_FILE)
    ) input_sram_inst (
        .clk(clk),.rst(pipe_reset),.req_valid(input_req),.req_addr(input_addr),.req_meta(input_request_meta),
        .row_valid(input_sram_valid),.row_data(input_sram_data),.row_meta(input_sram_meta)
    );
    fcnn_row_stage #(.LANES(LANES),.META_W(META_W)) weight_stage_inst (
        .clk(clk),.rst(pipe_reset),.in_valid(weight_sram_valid),.in_data(weight_sram_data),.in_meta(weight_sram_meta),
        .consume_row(consume_weight_row),.can_accept(),.stored_valid(weight_available),
        .stored_data(weight_stage_data),.stored_meta(weight_stage_meta)
    );
    fcnn_row_stage #(.LANES(LANES),.META_W(META_W)) input_stage_inst (
        .clk(clk),.rst(pipe_reset),.in_valid(input_sram_valid),.in_data(input_sram_data),.in_meta(input_sram_meta),
        .consume_row(consume_input_row),.can_accept(),.stored_valid(input_available),
        .stored_data(input_stage_data),.stored_meta(input_stage_meta)
    );
    // Step 3: Scheduler controls handshakes; Router owns arithmetic operand tags.
    fcnn_local_scheduler #(
        .N_INPUTS(N_INPUTS),.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS),.LANES(LANES)
    ) scheduler_inst (
        .clk(clk),.rst(rst),.run_init(run_init),.fc1_active(fc1_active),.fc2_active(fc2_active),
        .request_neuron(request_neuron),.request_fc1_row(request_fc1_row),.request_fc2_row(request_fc2_row),
        .weight_available(weight_available),.input_available(input_available),
        .compute_layer(compute_layer),.compute_row(compute_row),.product_ready(product_ready),.pp_wr_ready(pp_wr_ready),
        .term_last(term_last),.hidden_all_valid(hidden_all_valid),.activation_last_use(mul_issue && activation_last_term),
        .fc2_all_committed(fc2_all_committed),.final_ready(final_ready),.argmax_valid(argmax_valid),
        .request_layer(request_layer),.weight_req(weight_req),.input_req(input_req),
        .consume_weight_row(consume_weight_row),.consume_input_row(consume_input_row),
        .lane_idx(lane_idx),.mul_issue(mul_issue),.group_last(group_last),.rf_final_we(rf_final_we),
        .fc1_finished(fc1_finished),.fc2_finished(fc2_finished)
    );
    fcnn_operand_router #(
        .N_INPUTS(N_INPUTS),.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS),.LANES(LANES)
    ) router_inst (
        .weight_row(weight_stage_data),.input_row(input_stage_data),
        .weight_meta(weight_stage_meta),.input_meta(input_stage_meta),.lane_idx(lane_idx),
        .hidden_value(hidden_rd_data),.hidden_rd_idx(hidden_rd_idx),
        .mul_weight(mul_weight),.mul_input(mul_input),.term_valid(term_valid),
        .term_dest(term_dest),.term_last(term_last),.activation_last_term(activation_last_term)
    );
    // Step 4: the only FP16 multiplier; registered products enter two-bank PP.
    fcnn_fp16_multiplier multiplier_inst (.a(mul_weight),.b(mul_input),.result(mul_result));
    fcnn_product_register #(.DEST_W(DEST_W)) product_inst (
        .clk(clk),.rst(pipe_reset),.in_valid(mul_issue && term_valid),.in_ready(product_ready),
        .in_data(mul_result),.in_dest(term_dest),.in_last(term_last),.in_group_last(group_last),
        .out_valid(pp_wr_valid),.out_ready(pp_wr_ready),.out_data(pp_wr_data),.out_dest(pp_wr_dest),
        .out_last(pp_wr_last),.out_group_last(pp_wr_group_last)
    );
    fcnn_ping_pong_buffer #(.LANES(LANES),.DEST_W(DEST_W)) ping_pong_inst (
        .clk(clk),.rst(pipe_reset),.wr_valid(pp_wr_valid),.wr_ready(pp_wr_ready),
        .wr_data(pp_wr_data),.wr_dest(pp_wr_dest),.wr_last(pp_wr_last),.wr_group_last(pp_wr_group_last),
        .rd_valid(pp_rd_valid),.rd_ready(pp_rd_ready),.rd_data(pp_rd_data),.rd_dest(pp_rd_dest),.rd_last(pp_rd_last),
        .bank_full(),.bank_empty(),.bank_select()
    );
    // Step 5: the only FP16 adder; the backend mux schedules the separate bias.
    fcnn_fp16_adder adder_inst (.a(add_a),.b(add_b),.result(add_result));
    fcnn_bias_rom #(
        .N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS),.FC1_BIAS_FILE(FC1_BIAS_FILE),.FC2_BIAS_FILE(FC2_BIAS_FILE)
    ) bias_inst (.fc1_neuron(bias_neuron),.fc1_bias(fc1_bias),.fc2_biases(fc2_biases));
    fcnn_accumulator_bank #(.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS)) accumulator_inst (
        .clk(clk),.rst(rst),.run_init(run_init),.layer_sel(fc2_active),
        .product_valid(pp_rd_valid),.product_ready(pp_rd_ready),.product_data(pp_rd_data),
        .product_dest(pp_rd_dest),.product_last(pp_rd_last),.bias_neuron(bias_neuron),
        .fc1_bias(fc1_bias),.fc2_biases(fc2_biases),.add_a(add_a),.add_b(add_b),.add_result(add_result),
        .add_commit(add_commit),.fc1_final_valid(fc1_final_valid),.fc1_final_value(fc1_final_value),
        .fc1_final_idx(fc1_final_idx),.fc2_all_committed(fc2_all_committed),.fc2_results(fc2_results)
    );
    // Step 6: ReLU -> reused RF -> balanced parallel argmax.
    fcnn_relu_fp16 relu_inst (.x(fc1_final_value),.y(relu_out));
    fcnn_activation_regfile #(.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS)) regfile_inst (
        .clk(clk),.rst(rst),.run_init(run_init),.hidden_wr_en(fc1_final_valid),
        .hidden_wr_idx(fc1_final_idx),.hidden_wr_data(relu_out),.hidden_rd_idx(hidden_rd_idx),.hidden_rd_data(hidden_rd_data),
        .hidden_all_valid(hidden_all_valid),.final_wr_en(rf_final_we),.final_wr_data(fc2_results),.final_ready(final_ready),.logits(logits)
    );
    fcnn_argmax #(.N_OUTPUTS(N_OUTPUTS)) argmax_inst (
        .logits(logits),.logits_valid(final_ready),.predicted_digit(predicted_digit),.argmax_valid(argmax_valid)
    );
    // Step 7: local contracts cover phase/tag errors and premature RF reuse.
    // synthesis translate_off
    always @(posedge clk) if (!pipe_reset) begin
        if (mul_issue && !term_valid)
            begin $display("[FAIL] DATAPATH invalid operand metadata or padding"); $finish; end
    end
    // synthesis translate_on
endmodule
`default_nettype wire
