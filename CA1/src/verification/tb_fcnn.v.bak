`timescale 1ns/1ps
`default_nettype none
// Tasks drive on falling edges; all protocol observations sample rising edges
// before NBA, exactly as synchronous receivers do. Expected words come from
// the independent Python oracle, never from RTL state.
module tb_fcnn #(
    // EDIT HERE for a ModelSim demonstration; paths are relative to project root.
    // Network settings are forwarded unchanged to the DUT's public parameters.
    parameter integer N_INPUTS=784, N_HIDDEN=8, N_OUTPUTS=10,
    parameter integer LANES=7, SRAM_LATENCY=7, CLOCK_PERIOD_NS=10,
    parameter FC1_WEIGHTS_FILE="data/model/fc1_weights.mem",
    parameter FC2_WEIGHTS_FILE="data/model/fc2_weights.mem",
    parameter INPUT_FILE="data/cases/test_image_3_fp16/test_image.mem",
    parameter FC1_BIAS_FILE="data/model/fc1_bias.mem",
    parameter FC2_BIAS_FILE="data/model/fc2_bias.mem",

    // Scenario controls: no command-line plusargs or Python are required.
    parameter integer RUNS=2, RESET_AFTER=0, INJECT_BUSY_START=1,
    parameter integer TIMEOUT_CYCLES=0, DUMP_WAVE=0,
    parameter VCD_FILE="fcnn.vcd",

    // Optional numerical scoreboard. Leave off for a newly supplied image.
    // Protocol/count/order/X checks always run. A protocol PASS is labelled.
    parameter integer CHECK_OUTPUTS=0, EXPECTED_DIGIT=-1,
    parameter EXPECTED_LOGITS_FILE="expected_logits.mem",
    parameter EXPECTED_HIDDEN_FILE="expected_hidden.mem"
);
    localparam integer INDEX_W=(N_OUTPUTS>1)?$clog2(N_OUTPUTS):1;
    localparam integer FC1_TERMS=N_INPUTS*N_HIDDEN;
    localparam integer FC2_TERMS=N_HIDDEN*N_OUTPUTS;
    localparam integer TOTAL_TERMS=FC1_TERMS+FC2_TERMS;
    localparam integer FC1_ROWS=(N_INPUTS+LANES-1)/LANES;
    localparam integer FC2_ROWS=(FC2_TERMS+LANES-1)/LANES;
    localparam integer EXPECTED_ROWS=N_HIDDEN*FC1_ROWS+FC2_ROWS;
    reg clk=0, rst=1, start=0;
    reg simulation_finished=0;
    // Quiesce after completion so ModelSim run -all returns with the design
    // and waves still loaded, rather than executing $finish on a successful run.
    initial begin
        while (!simulation_finished) begin
            #(CLOCK_PERIOD_NS/2.0);
            if (!simulation_finished) clk=~clk;
        end
    end
    wire busy,done;
    wire [16*N_OUTPUTS-1:0] logits;
    wire [INDEX_W-1:0] predicted_digit;
    fcnn_top #(
        .N_INPUTS(N_INPUTS),.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS),.LANES(LANES),.SRAM_LATENCY(SRAM_LATENCY),
        .FC1_WEIGHTS_FILE(FC1_WEIGHTS_FILE),.FC2_WEIGHTS_FILE(FC2_WEIGHTS_FILE),.INPUT_FILE(INPUT_FILE),
        .FC1_BIAS_FILE(FC1_BIAS_FILE),.FC2_BIAS_FILE(FC2_BIAS_FILE)
    ) dut (.clk(clk),.rst(rst),.start(start),.busy(busy),.done(done),.logits(logits),.predicted_digit(predicted_digit));
    reg [15:0] expected_logits[0:N_OUTPUTS-1], expected_hidden[0:N_HIDDEN-1];
    integer expected_digit, runs, timeout_cycles, reset_after, inject_busy_start, dump_wave, check_outputs;
    integer cycle=0, accepted_cycle=-1, issued=0, products_read=0, adds=0;
    integer weight_requests=0, input_requests=0, hidden_writes=0, output_writes=0;
    integer completions=0, accepted_starts=0, failures=0, last_activation_cycle=-1;
    integer idx, scalar, expected_dest, expected_last, expected_input;
    integer request_index, prior_issue=-1, fc1_gaps=0, fc2_gaps=0;
    integer started=0, hidden_index, output_index;
    reg [16*N_OUTPUTS-1:0] saved_logits;
    reg [INDEX_W-1:0] saved_digit;
    reg previous_done=0;
    reg [1023:0] expected_file, hidden_file;

    // Step 1: reusable stimulus tasks. Reset aborts a run and clears scoreboards.
    task require_file;
        input [1023:0] filename;
        integer descriptor;
        begin
            descriptor=$fopen(filename,"r");
            if (descriptor==0) begin
                $display("[FAIL] cannot open file: %0s",filename);
                $display("[INFO] Run from the project root, or use do run_modelsim.do.");
                $finish;
            end
            $fclose(descriptor);
        end
    endtask
    task apply_reset;
        begin
            @(negedge clk); rst=1;start=0;
            repeat(3) @(negedge clk);
            rst=0;
            @(negedge clk);
            if (busy!==0 || done!==0) begin $display("[FAIL] reset status");failures=failures+1;end
        end
    endtask
    task pulse_start;
        begin @(negedge clk);start=1;@(negedge clk);start=0;end
    endtask
    task wait_complete;
        integer waited;
        begin
            waited=0;
            while (!done && waited<timeout_cycles) begin @(negedge clk);waited=waited+1;end
            if (!done) begin $display("[FAIL] TIMEOUT issued=%0d adds=%0d",issued,adds);$finish;end
            // Let the rising-edge monitor compare all outputs and count DONE.
            @(negedge clk);
            saved_logits=logits;saved_digit=predicted_digit;
            repeat(3) @(negedge clk);
            if (logits!==saved_logits || predicted_digit!==saved_digit || busy!==0 || done!==0)
                begin $display("[FAIL] idle output/status stability");failures=failures+1;end
        end
    endtask
    task run_inference;
        begin
            pulse_start;
            if (inject_busy_start!=0) begin
                // The one-cycle busy start must not reset or restart inference.
                @(negedge clk);
                if (busy) begin start=1;@(negedge clk);start=0;end
            end
            wait_complete;
        end
    endtask

    // Step 2: independent transaction counters and expected operation order.
    always @(posedge clk) begin
        cycle=cycle+1;
        if (rst) begin
            accepted_cycle=-1;issued=0;products_read=0;adds=0;weight_requests=0;
            input_requests=0;hidden_writes=0;output_writes=0;prior_issue=-1;
            last_activation_cycle=-1;previous_done=0;started=0;fc1_gaps=0;fc2_gaps=0;
        end else begin
            if (dut.run_init) begin
                accepted_cycle=cycle;accepted_starts=accepted_starts+1;
                issued=0;products_read=0;adds=0;weight_requests=0;input_requests=0;
                hidden_writes=0;output_writes=0;prior_issue=-1;last_activation_cycle=-1;
                fc1_gaps=0;fc2_gaps=0;started=1;
            end
            if (dut.datapath_inst.weight_req) begin
                if (weight_requests<N_HIDDEN*FC1_ROWS) begin
                    if (dut.datapath_inst.weight_addr!==weight_requests || !dut.datapath_inst.input_req)
                        begin $display("[FAIL] FC1 address/request %0d",weight_requests);failures=failures+1;end
                end else if (dut.datapath_inst.weight_addr!==weight_requests || dut.datapath_inst.input_req)
                    begin $display("[FAIL] FC2 address/request %0d",weight_requests);failures=failures+1;end
                weight_requests=weight_requests+1;
            end
            if (dut.datapath_inst.input_req) begin
                if (dut.datapath_inst.input_addr!==input_requests%FC1_ROWS)
                    begin $display("[FAIL] input address");failures=failures+1;end
                input_requests=input_requests+1;
            end
            if (dut.datapath_inst.mul_issue) begin
                if (^dut.datapath_inst.mul_weight===1'bx || ^dut.datapath_inst.mul_input===1'bx)
                    begin $display("[FAIL] unknown multiplier operand at term %0d; check input files and dimensions",issued);$finish;end
                if (issued<FC1_TERMS) begin
                    expected_dest=issued/N_INPUTS;
                    expected_last=issued%N_INPUTS==N_INPUTS-1;
                    if (prior_issue>=0) fc1_gaps=fc1_gaps+cycle-prior_issue-1;
                end else begin
                    scalar=issued-FC1_TERMS;
                    if (scalar<N_OUTPUTS*(N_HIDDEN-1)) begin
                        expected_dest=scalar/((N_HIDDEN>1)?N_HIDDEN-1:1);
                        expected_input=scalar%((N_HIDDEN>1)?N_HIDDEN-1:1);
                        expected_last=0;
                    end else begin
                        expected_dest=scalar-N_OUTPUTS*(N_HIDDEN-1);
                        expected_input=N_HIDDEN-1;expected_last=1;
                    end
                    if (dut.datapath_inst.hidden_rd_idx!==expected_input)
                        begin $display("[FAIL] hidden address at term %0d",scalar);failures=failures+1;end
                    if (scalar!=0) fc2_gaps=fc2_gaps+cycle-prior_issue-1;
                    last_activation_cycle=cycle;
                end
                if (!dut.datapath_inst.term_valid || dut.datapath_inst.term_dest!==expected_dest ||
                    dut.datapath_inst.term_last!==expected_last[0] || issued>=TOTAL_TERMS)
                    begin $display("[FAIL] term metadata issue=%0d",issued);failures=failures+1;end
                issued=issued+1;prior_issue=cycle;
            end
            if (dut.datapath_inst.pp_rd_valid && dut.datapath_inst.pp_rd_ready) products_read=products_read+1;
            if (dut.datapath_inst.add_commit) begin
                if (^dut.datapath_inst.add_a===1'bx || ^dut.datapath_inst.add_b===1'bx)
                    begin $display("[FAIL] unknown adder operand; check bias/model files");$finish;end
                adds=adds+1;
            end
            // Step 3: verify intermediate ReLU outputs before the RF is reused.
            if (dut.datapath_inst.fc1_final_valid) begin
                hidden_index=dut.datapath_inst.fc1_final_idx;
                if (hidden_index!=hidden_writes || (check_outputs && dut.datapath_inst.relu_out!==expected_hidden[hidden_index]))
                    begin $display("[FAIL] hidden %0d got=%h expected=%h",hidden_index,dut.datapath_inst.relu_out,expected_hidden[hidden_index]);failures=failures+1;end
                hidden_writes=hidden_writes+1;
            end
            if (dut.datapath_inst.rf_final_we) begin
                output_writes=output_writes+1;
                if (issued!=TOTAL_TERMS || last_activation_cycle<0 || cycle<=last_activation_cycle ||
                    !dut.datapath_inst.fc2_all_committed)
                    begin $display("[FAIL] early activation RF overwrite");failures=failures+1;end
            end
            // Step 4: check every logit, result, count, and the one-cycle DONE pulse.
            if (done) begin
                completions=completions+1;
                if (previous_done || busy || !started || issued!=TOTAL_TERMS || products_read!=TOTAL_TERMS ||
                    adds!=TOTAL_TERMS+N_HIDDEN+N_OUTPUTS || weight_requests!=EXPECTED_ROWS ||
                    input_requests!=N_HIDDEN*FC1_ROWS || hidden_writes!=N_HIDDEN || output_writes!=1)
                    begin $display("[FAIL] counts/protocol mul=%0d read=%0d add=%0d rows=%0d hidden=%0d out=%0d",issued,products_read,adds,weight_requests,hidden_writes,output_writes);failures=failures+1;end
                if (^logits===1'bx || ^predicted_digit===1'bx || predicted_digit>=N_OUTPUTS)
                    begin $display("[FAIL] unknown or invalid final result");failures=failures+1;end
                if (check_outputs && predicted_digit!==expected_digit)
                    begin $display("[FAIL] predicted got=%0d expected=%0d",predicted_digit,expected_digit);failures=failures+1;end
                for (output_index=0;output_index<N_OUTPUTS;output_index=output_index+1) begin
                    $display("[RESULT] run=%0d logit[%0d]=%h",completions,output_index,logits[16*output_index+:16]);
                    if (check_outputs && logits[16*output_index+:16]!==expected_logits[output_index])
                        begin $display("[FAIL] logit %0d got=%h expected=%h",output_index,logits[16*output_index+:16],expected_logits[output_index]);failures=failures+1;end
                end
                $display("[RESULT] run=%0d predicted_digit=%0d",completions,predicted_digit);
                $display("[MEASURE] run=%0d cycles=%0d mul=%0d add=%0d weight_rows=%0d input_rows=%0d fc1_gaps=%0d fc2_gaps=%0d digit=%0d",completions,cycle-accepted_cycle,issued,adds,weight_requests,input_requests,fc1_gaps,fc2_gaps,predicted_digit);
                started=0;
            end
            previous_done=done;
        end
    end

    // Step 5: TB parameters are the defaults; regression plusargs may override.
    initial begin
        check_outputs=CHECK_OUTPUTS;
        // Retain compatibility with the previous verified runner and benches.
        if (!$value$plusargs("expected_digit=%d",expected_digit)) expected_digit=EXPECTED_DIGIT;
        else check_outputs=1;
        if ($value$plusargs("check_outputs=%d",check_outputs)) begin end
        if (!$value$plusargs("runs=%d",runs)) runs=RUNS;
        if (!$value$plusargs("timeout=%d",timeout_cycles)) timeout_cycles=TIMEOUT_CYCLES;
        if (timeout_cycles==0) timeout_cycles=4*(TOTAL_TERMS+EXPECTED_ROWS+SRAM_LATENCY+N_HIDDEN+N_OUTPUTS+1);
        if (!$value$plusargs("reset_after=%d",reset_after)) reset_after=RESET_AFTER;
        if (!$value$plusargs("busy_start=%d",inject_busy_start)) inject_busy_start=INJECT_BUSY_START;
        if (!$value$plusargs("expected_file=%s",expected_file)) expected_file=EXPECTED_LOGITS_FILE;
        if (!$value$plusargs("hidden_file=%s",hidden_file)) hidden_file=EXPECTED_HIDDEN_FILE;
        if (!$value$plusargs("wave=%d",dump_wave)) dump_wave=DUMP_WAVE;
        if (N_INPUTS<1 || N_HIDDEN<1 || N_OUTPUTS<1 || LANES<1 || SRAM_LATENCY<1 || CLOCK_PERIOD_NS<1 ||
            runs<1 || timeout_cycles<1 || reset_after<0 || (check_outputs!=0 && check_outputs!=1) ||
            (inject_busy_start!=0 && inject_busy_start!=1) || (dump_wave!=0 && dump_wave!=1))
            begin $display("[FAIL] invalid TB settings");$finish;end
        require_file(FC1_WEIGHTS_FILE);require_file(FC2_WEIGHTS_FILE);require_file(INPUT_FILE);
        require_file(FC1_BIAS_FILE);require_file(FC2_BIAS_FILE);
        $display("[CONFIG] inputs=%0d hidden=%0d outputs=%0d lanes=%0d latency=%0d runs=%0d checked_outputs=%0d",N_INPUTS,N_HIDDEN,N_OUTPUTS,LANES,SRAM_LATENCY,runs,check_outputs);
        $display("[CONFIG] image=%0s",INPUT_FILE);
        $display("[CONFIG] fc1_weights=%0s fc2_weights=%0s",FC1_WEIGHTS_FILE,FC2_WEIGHTS_FILE);
        $display("[CONFIG] fc1_bias=%0s fc2_bias=%0s",FC1_BIAS_FILE,FC2_BIAS_FILE);
        $display("[CONFIG] clock_ns=%0d reset_after=%0d busy_start=%0d timeout_cycles=%0d",CLOCK_PERIOD_NS,reset_after,inject_busy_start,timeout_cycles);
        if (check_outputs) begin
            if (expected_digit<0 || expected_digit>=N_OUTPUTS)
                begin $display("[FAIL] CHECK_OUTPUTS requires a valid EXPECTED_DIGIT or +expected_digit");$finish;end
            require_file(expected_file);require_file(hidden_file);
            $readmemh(expected_file,expected_logits);
            $readmemh(hidden_file,expected_hidden);
            for (idx=0;idx<N_OUTPUTS;idx=idx+1)
                if (^expected_logits[idx]===1'bx) begin $display("[FAIL] incomplete/unknown expected logits");$finish;end
            for (idx=0;idx<N_HIDDEN;idx=idx+1)
                if (^expected_hidden[idx]===1'bx) begin $display("[FAIL] incomplete/unknown expected hidden values");$finish;end
        end else $display("[INFO] Protocol/count/order/X checks active; numerical golden comparison disabled.");
        if (dump_wave) begin $dumpfile(VCD_FILE);$dumpvars(0,tb_fcnn);end
        apply_reset;
        if (reset_after>0) begin
            pulse_start;
            repeat(reset_after) @(negedge clk);
            if (done || !busy) begin $display("[FAIL] reset_after must fall within a run");$finish;end
            apply_reset;
        end
        for (idx=0;idx<runs;idx=idx+1) run_inference;
        if (completions!=runs) begin $display("[FAIL] completion count");failures=failures+1;end
        if (accepted_starts!=runs+((reset_after>0)?1:0))
            begin $display("[FAIL] unexpected start acceptance");failures=failures+1;end
        if (failures==0) begin
            if (check_outputs) $display("[PASS] E2E runs=%0d hidden=%0d logits=%0d reset_abort=%0d checked_outputs=1",runs,N_HIDDEN,N_OUTPUTS,reset_after>0);
            else $display("[PASS] E2E_PROTOCOL runs=%0d hidden=%0d logits=%0d reset_abort=%0d checked_outputs=0",runs,N_HIDDEN,N_OUTPUTS,reset_after>0);
        end else begin $display("[FAIL] E2E failures=%0d",failures);$finish;end
        simulation_finished=1;
    end
endmodule
`default_nettype wire
