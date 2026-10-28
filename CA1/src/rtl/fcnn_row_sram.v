`default_nettype none
// Raw scalar memory model. SOURCE_KIND=0: image; SOURCE_KIND=1: weights.
module fcnn_row_sram #(
    parameter integer N_INPUTS=784, N_HIDDEN=8, N_OUTPUTS=10, LANES=7,
    parameter integer SRAM_LATENCY=7, SOURCE_KIND=1,
    parameter INIT_FILE="fc1_weights.mem", FC2_WEIGHTS_FILE="fc2_weights.mem"
) (
    clk,
    rst,
    req_valid,
    req_addr,
    req_meta,
    row_valid,
    row_data,
    row_meta
);
    // Step 1: layout and widths derive only from network parameters.
    localparam integer FC1_ROWS=(N_INPUTS+LANES-1)/LANES;
    localparam integer FC2_ROWS=(N_HIDDEN*N_OUTPUTS+LANES-1)/LANES;
    localparam integer DEPTH=(SOURCE_KIND==1) ? N_HIDDEN*FC1_ROWS+FC2_ROWS : FC1_ROWS;
    localparam integer ADDR_W=(DEPTH>1)?$clog2(DEPTH):1;
    localparam integer H_W=(N_HIDDEN>1)?$clog2(N_HIDDEN):1;
    localparam integer ROW_W=$clog2(((FC1_ROWS>FC2_ROWS)?FC1_ROWS:FC2_ROWS)+1);
    localparam integer META_W=1+H_W+ROW_W;
    localparam integer FC2_MAIN=N_OUTPUTS*(N_HIDDEN-1);

    // Port widths are declared after derived constants for ModelSim 2020.
    input wire clk;
    input wire rst;
    input wire req_valid;
    input wire [ADDR_W-1:0] req_addr;
    input wire [META_W-1:0] req_meta;
    output wire row_valid;
    output wire [16*LANES-1:0] row_data;
    output wire [META_W-1:0] row_meta;

    wire [16*LANES-1:0] selected_row;
    // Step 2: raw files stay 16-bit/neuron-major; rows are assembled inside SRAM.
    generate
        if (SOURCE_KIND==1) begin: g_weights
            reg [15:0] fc1_words [0:N_INPUTS*N_HIDDEN-1];
            reg [15:0] fc2_words [0:N_HIDDEN*N_OUTPUTS-1];
            initial begin
                $readmemh(INIT_FILE, fc1_words);
                $readmemh(FC2_WEIGHTS_FILE, fc2_words);
            end
            genvar lane;
            for (lane=0; lane<LANES; lane=lane+1) begin: g_lane
                wire [31:0] fc1_neuron=req_addr/FC1_ROWS;
                wire [31:0] input_idx=(req_addr%FC1_ROWS)*LANES+lane;
                wire [31:0] term_idx=(req_addr-N_HIDDEN*FC1_ROWS)*LANES+lane;
                wire [31:0] dest_idx, hidden_idx;
                if (N_HIDDEN>1) begin: g_main
                    assign dest_idx=(term_idx<FC2_MAIN)?term_idx/(N_HIDDEN-1):term_idx-FC2_MAIN;
                    assign hidden_idx=(term_idx<FC2_MAIN)?term_idx%(N_HIDDEN-1):N_HIDDEN-1;
                end else begin: g_single_hidden
                    assign dest_idx=term_idx;
                    assign hidden_idx=0;
                end
                assign selected_row[16*lane+:16] =
                    (req_addr<N_HIDDEN*FC1_ROWS) ?
                        ((input_idx<N_INPUTS)?fc1_words[fc1_neuron*N_INPUTS+input_idx]:16'd0) :
                        ((term_idx<N_HIDDEN*N_OUTPUTS)?fc2_words[dest_idx*N_HIDDEN+hidden_idx]:16'd0);
            end
        end else begin: g_image
            reg [15:0] image_words [0:N_INPUTS-1];
            initial $readmemh(INIT_FILE, image_words);
            genvar lane;
            for (lane=0; lane<LANES; lane=lane+1) begin: g_lane
                assign selected_row[16*lane+:16] = (req_addr*LANES+lane<N_INPUTS) ? image_words[req_addr*LANES+lane] : 16'd0;
            end
        end
    endgenerate
    // Step 3: a request sampled at E is sampled downstream at E+SRAM_LATENCY.
    // Pipeline outputs change after NBA at E+SRAM_LATENCY-1; the next receiver
    // samples them at E+SRAM_LATENCY. The TB checks this edge convention.
    reg [SRAM_LATENCY-1:0] valid_pipe;
    reg [META_W-1:0] meta_pipe [0:SRAM_LATENCY-1];
    reg [16*LANES-1:0] data_pipe [0:SRAM_LATENCY-1];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            valid_pipe<=0;
        end else begin
            valid_pipe[0]<=req_valid;
            if (req_valid) begin
                data_pipe[0]<=selected_row;
                meta_pipe[0]<=req_meta;
            end
            for (i=1;i<SRAM_LATENCY;i=i+1) begin
                valid_pipe[i]<=valid_pipe[i-1];
                if (valid_pipe[i-1]) begin
                    data_pipe[i]<=data_pipe[i-1];
                    meta_pipe[i]<=meta_pipe[i-1];
                end
            end
            // synthesis translate_off
            if (req_valid && req_addr>=DEPTH)
                begin $display("[FAIL] SRAM invalid address=%0d depth=%0d",req_addr,DEPTH); $finish; end
            // synthesis translate_on
        end
    end
    assign row_valid=valid_pipe[SRAM_LATENCY-1];
    assign row_data=data_pipe[SRAM_LATENCY-1];
    assign row_meta=meta_pipe[SRAM_LATENCY-1];
endmodule
`default_nettype wire
