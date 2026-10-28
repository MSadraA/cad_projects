`default_nettype none
module fcnn_address_generator #(
    parameter integer N_INPUTS=784, N_HIDDEN=8, N_OUTPUTS=10, LANES=7
) (
    clk,
    rst,
    run_init,
    request_layer,
    advance_row,
    fc1_neuron,
    fc1_row,
    fc2_row,
    weight_addr,
    input_addr,
    weight_meta,
    input_meta
);
    // Step 1: one owner for request progress; Scheduler reads these counters.
    localparam integer FC1_ROWS=(N_INPUTS+LANES-1)/LANES;
    localparam integer FC2_ROWS=(N_HIDDEN*N_OUTPUTS+LANES-1)/LANES;
    localparam integer H_W=(N_HIDDEN>1)?$clog2(N_HIDDEN):1;
    localparam integer R1_W=(FC1_ROWS>1)?$clog2(FC1_ROWS):1;
    localparam integer R2_W=(FC2_ROWS>1)?$clog2(FC2_ROWS):1;
    localparam integer ROW_W=$clog2(((FC1_ROWS>FC2_ROWS)?FC1_ROWS:FC2_ROWS)+1);
    localparam integer META_W=1+H_W+ROW_W;
    localparam integer ADDR_W=(N_HIDDEN*FC1_ROWS+FC2_ROWS>1)?$clog2(N_HIDDEN*FC1_ROWS+FC2_ROWS):1;

    // Port widths are declared after derived constants for ModelSim 2020.
    input wire clk;
    input wire rst;
    input wire run_init;
    input wire request_layer;
    input wire advance_row;
    output wire [H_W-1:0] fc1_neuron;
    output wire [R1_W-1:0] fc1_row;
    output wire [R2_W-1:0] fc2_row;
    output wire [ADDR_W-1:0] weight_addr;
    output wire [R1_W-1:0] input_addr;
    output wire [META_W-1:0] weight_meta;
    output wire [META_W-1:0] input_meta;

    reg [H_W-1:0] neuron_reg;
    reg [R1_W-1:0] row1_reg;
    reg [R2_W-1:0] row2_reg;
    wire [ROW_W-1:0] row1_meta=row1_reg, row2_meta=row2_reg;
    // Step 2: advance exactly once per accepted request.
    always @(posedge clk) begin
        if (rst || run_init) begin
            neuron_reg<=0; row1_reg<=0; row2_reg<=0;
        end else if (advance_row) begin
            if (!request_layer) begin
                if (row1_reg==FC1_ROWS-1) begin
                    row1_reg<=0;
                    case (neuron_reg)
                        N_HIDDEN-1: neuron_reg<=neuron_reg;
                        default: neuron_reg<=neuron_reg+1'b1;
                    endcase
                end else row1_reg<=row1_reg+1'b1;
            end else begin
                case (row2_reg)
                    FC2_ROWS-1: row2_reg<=row2_reg;
                    default: row2_reg<=row2_reg+1'b1;
                endcase
            end
        end
    end
    // Step 3: physical row addresses. Metadata = {layer, hidden_neuron, row}.
    wire [31:0] physical_addr = request_layer ? N_HIDDEN*FC1_ROWS+row2_reg : neuron_reg*FC1_ROWS+row1_reg;
    assign weight_addr = physical_addr[ADDR_W-1:0];
    assign input_addr = row1_reg;
    assign weight_meta = request_layer ? {1'b1, {H_W{1'b0}}, row2_meta} : {1'b0, neuron_reg, row1_meta};
    assign input_meta = {1'b0, neuron_reg, row1_meta};
    assign fc1_neuron=neuron_reg;
    assign fc1_row=row1_reg;
    assign fc2_row=row2_reg;
endmodule
`default_nettype wire
