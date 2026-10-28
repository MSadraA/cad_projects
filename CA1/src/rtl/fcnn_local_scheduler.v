`default_nettype none
module fcnn_local_scheduler #(
    parameter integer N_INPUTS=784, N_HIDDEN=8, N_OUTPUTS=10, LANES=7
) (
    clk,
    rst,
    run_init,
    fc1_active,
    fc2_active,
    request_neuron,
    request_fc1_row,
    request_fc2_row,
    weight_available,
    input_available,
    compute_layer,
    compute_row,
    product_ready,
    pp_wr_ready,
    term_last,
    hidden_all_valid,
    activation_last_use,
    fc2_all_committed,
    final_ready,
    argmax_valid,
    request_layer,
    weight_req,
    input_req,
    consume_weight_row,
    consume_input_row,
    lane_idx,
    mul_issue,
    group_last,
    rf_final_we,
    fc1_finished,
    fc2_finished
);
    // Step 1: control progress, not duplicated address counters.
    localparam integer FC1_ROWS=(N_INPUTS+LANES-1)/LANES;
    localparam integer FC2_ROWS=(N_HIDDEN*N_OUTPUTS+LANES-1)/LANES;
    localparam integer H_W=(N_HIDDEN>1)?$clog2(N_HIDDEN):1;
    localparam integer R1_W=(FC1_ROWS>1)?$clog2(FC1_ROWS):1;
    localparam integer R2_W=(FC2_ROWS>1)?$clog2(FC2_ROWS):1;
    localparam integer ROW_W=$clog2(((FC1_ROWS>FC2_ROWS)?FC1_ROWS:FC2_ROWS)+1);
    localparam integer LANE_W=(LANES>1)?$clog2(LANES):1;
    localparam integer WAIT_W=$clog2(2*LANES+4);
    // Fixed pipeline edges: product register + PP register + phase transition.
    localparam integer PHASE_EDGES=3;
    localparam integer FC1_TAIL=N_INPUTS-(FC1_ROWS-1)*LANES;
    localparam integer FC2_TAIL=N_HIDDEN*N_OUTPUTS-(FC2_ROWS-1)*LANES;

    // Port widths are declared after derived constants for ModelSim 2020.
    input wire clk;
    input wire rst;
    input wire run_init;
    input wire fc1_active;
    input wire fc2_active;
    input wire [H_W-1:0] request_neuron;
    input wire [R1_W-1:0] request_fc1_row;
    input wire [R2_W-1:0] request_fc2_row;
    input wire weight_available;
    input wire input_available;
    input wire compute_layer;
    input wire [ROW_W-1:0] compute_row;
    input wire product_ready;
    input wire pp_wr_ready;
    input wire term_last;
    input wire hidden_all_valid;
    input wire activation_last_use;
    input wire fc2_all_committed;
    input wire final_ready;
    input wire argmax_valid;
    output wire request_layer;
    output wire weight_req;
    output wire input_req;
    output wire consume_weight_row;
    output wire consume_input_row;
    output wire [LANE_W-1:0] lane_idx;
    output wire mul_issue;
    output wire group_last;
    output wire rf_final_we;
    output wire fc1_finished;
    output wire fc2_finished;

    reg [WAIT_W-1:0] request_wait;
    reg fc1_requests_done, fc2_requests_done, hidden_reads_done;
    reg bias_issue_gap;
    reg [LANE_W-1:0] lane_reg;
    wire final_fc1_row=request_fc1_row==FC1_ROWS-1;
    wire final_fc1_request=final_fc1_row && request_neuron==N_HIDDEN-1;
    wire final_fc2_request=request_fc2_row==FC2_ROWS-1;
    // Short FC1 rows still reserve a full bank service window.
    wire [31:0] request_lanes=LANES;
    wire [31:0] compute_lanes=compute_layer ?
        ((compute_row==FC2_ROWS-1)?FC2_TAIL:LANES) :
        ((compute_row==FC1_ROWS-1)?FC1_TAIL:LANES);
    wire [31:0] fc2_start=request_fc2_row*LANES;
    wire [31:0] fc2_end=fc2_start+LANES;
    localparam integer FC2_MAIN=N_OUTPUTS*(N_HIDDEN-1);
    wire [31:0] tail_terms;
    generate
        if (N_HIDDEN==1) begin: g_all_tail
            assign tail_terms=LANES;
        end else begin: g_tail_count
            assign tail_terms=(fc2_end<=FC2_MAIN)?0:
                ((fc2_start>=FC2_MAIN)?LANES:fc2_end-FC2_MAIN);
        end
    endgenerate
    wire [31:0] next_wait_fc1=request_lanes+
        (final_fc1_request ? PHASE_EDGES+LANES : (final_fc1_row?1:0))-1;
    wire [31:0] next_wait_fc2=LANES+tail_terms-1;
    // Step 2: reserve responses at the exact consumption cadence.
    assign request_layer=fc1_requests_done;
    assign weight_req=(fc1_active || fc2_active) && request_wait==0 &&
        (!fc1_requests_done || !fc2_requests_done);
    assign input_req=weight_req && !request_layer;
    assign lane_idx=lane_reg;
    wire fc1_issue=fc1_active && !compute_layer && weight_available && input_available;
    wire fc2_issue=fc2_active && compute_layer && weight_available && hidden_all_valid;
    assign mul_issue=(fc1_issue || fc2_issue) && !bias_issue_gap && product_ready && pp_wr_ready;
    assign group_last=lane_reg==compute_lanes-1;
    assign consume_weight_row=mul_issue && group_last;
    assign consume_input_row=consume_weight_row && !compute_layer;
    // Step 3: completion derives from committed values and last activation read.
    assign fc1_finished=hidden_all_valid;
    assign rf_final_we=fc2_active && fc2_all_committed && hidden_reads_done && !final_ready;
    assign fc2_finished=final_ready && argmax_valid;
    always @(posedge clk) begin
        if (rst || run_init) begin
            request_wait<=0; fc1_requests_done<=0; fc2_requests_done<=0;
            lane_reg<=0; hidden_reads_done<=0; bias_issue_gap<=0;
        end else begin
            if (weight_req) begin
                if (!request_layer) begin
                    if (final_fc1_request) begin
                        fc1_requests_done<=1;
                        request_wait<=next_wait_fc1[WAIT_W-1:0];
                    end else request_wait<=next_wait_fc1[WAIT_W-1:0];
                end else begin
                    request_wait<=next_wait_fc2[WAIT_W-1:0];
                    if (final_fc2_request) fc2_requests_done<=1;
                end
            end else if (request_wait!=0) request_wait<=request_wait-1'b1;
            if (mul_issue) begin
                if (group_last) lane_reg<=0;
                else lane_reg<=lane_reg+1'b1;
            end
            bias_issue_gap<=mul_issue && compute_layer && term_last;
            if (activation_last_use) hidden_reads_done<=1;
            // Step 4: an unexpected stall invalidates the single-row calendar.
            // synthesis translate_off
            if ((fc1_issue || fc2_issue) && !bias_issue_gap && (!product_ready || !pp_wr_ready))
                begin $display("[FAIL] SCHEDULER unexpected arithmetic stall"); $finish; end
            // synthesis translate_on
        end
    end
endmodule
`default_nettype wire
