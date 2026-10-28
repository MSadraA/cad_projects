`default_nettype none
module fcnn_controller (
    input wire clk, input wire rst, input wire start,
    input wire fc1_finished, input wire fc2_finished,
    output wire run_init, output wire fc1_active, output wire fc2_active,
    output wire busy, output wire done
);
    // Step 1: the four phases are protocol states, not tunable parameters.
    localparam [1:0] IDLE=2'd0, FC1=2'd1, FC2=2'd2, DONE=2'd3;
    reg [1:0] state, next_state;
    // Step 2: synchronous active-high reset.
    always @(posedge clk) begin
        if (rst) state <= IDLE;
        else state <= next_state;
    end
    // Step 3: start is accepted only in IDLE; busy starts are ignored.
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start && !rst) next_state = FC1;
            FC1: if (fc1_finished) next_state = FC2;
            FC2: if (fc2_finished) next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    // Step 4: DONE lasts one cycle. A held start is accepted on returning IDLE.
    assign run_init = (state==IDLE) && start && !rst;
    assign fc1_active = state==FC1;
    assign fc2_active = state==FC2;
    assign busy = fc1_active || fc2_active;
    assign done = state==DONE;
endmodule
`default_nettype wire
