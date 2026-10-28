`default_nettype none
module fcnn_operand_router #(
    parameter integer N_INPUTS=784, N_HIDDEN=8, N_OUTPUTS=10, LANES=7
) (
    weight_row,
    input_row,
    weight_meta,
    input_meta,
    lane_idx,
    hidden_value,
    hidden_rd_idx,
    mul_weight,
    mul_input,
    term_valid,
    term_dest,
    term_last,
    activation_last_term
);
    // Step 1: decode request metadata independently of the current request phase.
    localparam integer FC1_ROWS=(N_INPUTS+LANES-1)/LANES;
    localparam integer FC2_ROWS=(N_HIDDEN*N_OUTPUTS+LANES-1)/LANES;
    localparam integer H_W=(N_HIDDEN>1)?$clog2(N_HIDDEN):1;
    localparam integer MAX_NEURONS=(N_HIDDEN>N_OUTPUTS)?N_HIDDEN:N_OUTPUTS;
    localparam integer DEST_W=(MAX_NEURONS>1)?$clog2(MAX_NEURONS):1;
    localparam integer ROW_W=$clog2(((FC1_ROWS>FC2_ROWS)?FC1_ROWS:FC2_ROWS)+1);
    localparam integer META_W=1+H_W+ROW_W;
    localparam integer LANE_W=(LANES>1)?$clog2(LANES):1;
    localparam integer FC2_MAIN=N_OUTPUTS*(N_HIDDEN-1);

    // Port widths are declared after derived constants for ModelSim 2020.
    input wire [16*LANES-1:0] weight_row;
    input wire [16*LANES-1:0] input_row;
    input wire [META_W-1:0] weight_meta;
    input wire [META_W-1:0] input_meta;
    input wire [LANE_W-1:0] lane_idx;
    input wire [15:0] hidden_value;
    output wire [H_W-1:0] hidden_rd_idx;
    output wire [15:0] mul_weight;
    output wire [15:0] mul_input;
    output wire term_valid;
    output wire [DEST_W-1:0] term_dest;
    output wire term_last;
    output wire activation_last_term;

    wire layer=weight_meta[META_W-1];
    wire [ROW_W-1:0] row_num=weight_meta[ROW_W-1:0];
    wire [H_W-1:0] neuron=weight_meta[ROW_W+:H_W];
    wire [31:0] scalar_idx=row_num*LANES+lane_idx;
    wire [31:0] hidden_idx, dest_idx;
    wire fc2_last;
    // Step 2: all but the final hidden input, then final input across outputs.
    // This retains the original 10+2 row layout for 8 hidden / 10 outputs.
    generate
        if (N_HIDDEN>1) begin: g_main
            assign fc2_last=scalar_idx>=FC2_MAIN;
            assign hidden_idx=(scalar_idx<FC2_MAIN)?scalar_idx%(N_HIDDEN-1):N_HIDDEN-1;
            assign dest_idx=(scalar_idx<FC2_MAIN)?scalar_idx/(N_HIDDEN-1):scalar_idx-FC2_MAIN;
        end else begin: g_single_hidden
            assign fc2_last=1;
            assign hidden_idx=0;
            assign dest_idx=scalar_idx;
        end
    endgenerate
    // Step 3: the hidden address has no combinational dependence on hidden data.
    assign hidden_rd_idx=layer ? hidden_idx[H_W-1:0] : {H_W{1'b0}};
    assign mul_weight=(lane_idx<LANES)?weight_row[16*lane_idx+:16]:16'd0;
    assign mul_input=layer ? hidden_value : ((lane_idx<LANES)?input_row[16*lane_idx+:16]:16'd0);
    assign term_valid=(lane_idx<LANES) && (layer ?
        (scalar_idx<N_HIDDEN*N_OUTPUTS) :
        (weight_meta==input_meta && scalar_idx<N_INPUTS && neuron<N_HIDDEN));
    assign term_dest=layer ? dest_idx[DEST_W-1:0] : neuron;
    assign term_last=layer ? fc2_last : scalar_idx==N_INPUTS-1;
    assign activation_last_term=layer && scalar_idx==N_HIDDEN*N_OUTPUTS-1;
endmodule
`default_nettype wire
