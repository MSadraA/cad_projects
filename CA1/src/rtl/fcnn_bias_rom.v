`default_nettype none
module fcnn_bias_rom #(
    parameter integer N_HIDDEN=8, N_OUTPUTS=10,
    parameter FC1_BIAS_FILE="fc1_bias.mem", FC2_BIAS_FILE="fc2_bias.mem"
) (
    fc1_neuron,
    fc1_bias,
    fc2_biases
);
    localparam integer H_W=(N_HIDDEN>1)?$clog2(N_HIDDEN):1;
    // Step 1: independent scalar bias ROMs.

    // Port widths are declared after derived constants for ModelSim 2020.
    input wire [H_W-1:0] fc1_neuron;
    output wire [15:0] fc1_bias;
    output wire [16*N_OUTPUTS-1:0] fc2_biases;

    reg [15:0] fc1_mem[0:N_HIDDEN-1], fc2_mem[0:N_OUTPUTS-1];
    initial begin
        $readmemh(FC1_BIAS_FILE,fc1_mem);
        $readmemh(FC2_BIAS_FILE,fc2_mem);
    end
    // Step 2: FC1 is indexed by the backend destination, never request progress.
    assign fc1_bias=(fc1_neuron<N_HIDDEN)?fc1_mem[fc1_neuron]:16'd0;
    genvar j;
    generate for (j=0;j<N_OUTPUTS;j=j+1) begin: g_bias
        assign fc2_biases[16*j+:16]=fc2_mem[j];
    end endgenerate
endmodule
`default_nettype wire
