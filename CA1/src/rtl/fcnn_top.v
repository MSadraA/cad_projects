`default_nettype none
// Step 1: the public configuration boundary. All user choices enter here.
module fcnn_top #(
    parameter integer N_INPUTS = 784,
    parameter integer N_HIDDEN = 8,
    parameter integer N_OUTPUTS = 10,
    parameter integer LANES = 7,
    parameter integer SRAM_LATENCY = 7,
    parameter FC1_WEIGHTS_FILE = "fc1_weights.mem",
    parameter FC2_WEIGHTS_FILE = "fc2_weights.mem",
    parameter INPUT_FILE = "test_image.mem",
    parameter FC1_BIAS_FILE = "fc1_bias.mem",
    parameter FC2_BIAS_FILE = "fc2_bias.mem"
) (
    input wire clk, input wire rst, input wire start,
    output wire busy, output wire done,
    output wire [16*N_OUTPUTS-1:0] logits,
    output wire [((N_OUTPUTS>1)?$clog2(N_OUTPUTS):1)-1:0] predicted_digit
);
    // Step 2: control/status only; no arithmetic or storage in Top.
    wire run_init, fc1_active, fc2_active, fc1_finished, fc2_finished;
    fcnn_controller controller_inst (
        .clk(clk), .rst(rst), .start(start),
        .fc1_finished(fc1_finished), .fc2_finished(fc2_finished),
        .run_init(run_init), .fc1_active(fc1_active), .fc2_active(fc2_active),
        .busy(busy), .done(done)
    );
    // Step 3: propagate every public setting by name.
    fcnn_datapath #(
        .N_INPUTS(N_INPUTS), .N_HIDDEN(N_HIDDEN), .N_OUTPUTS(N_OUTPUTS),
        .LANES(LANES), .SRAM_LATENCY(SRAM_LATENCY),
        .FC1_WEIGHTS_FILE(FC1_WEIGHTS_FILE), .FC2_WEIGHTS_FILE(FC2_WEIGHTS_FILE),
        .INPUT_FILE(INPUT_FILE), .FC1_BIAS_FILE(FC1_BIAS_FILE), .FC2_BIAS_FILE(FC2_BIAS_FILE)
    ) datapath_inst (
        .clk(clk), .rst(rst), .run_init(run_init),
        .fc1_active(fc1_active), .fc2_active(fc2_active),
        .fc1_finished(fc1_finished), .fc2_finished(fc2_finished),
        .logits(logits), .predicted_digit(predicted_digit)
    );
    // Step 4: configuration errors are explicit simulation failures.
    // synthesis translate_off
    initial begin
        if (N_INPUTS<1 || N_HIDDEN<1 || N_OUTPUTS<1 || LANES<1 || SRAM_LATENCY<1)
            begin $display("[FAIL] CONFIG positive dimensions/latency required"); $finish; end
    end
    // synthesis translate_on
endmodule
`default_nettype wire
