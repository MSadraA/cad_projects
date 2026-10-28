`timescale 1ns/1ps
`default_nettype none
module tb_pipeline;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    reg in_valid=0,consume=0,out_ready=0;
    reg [15:0] data=0;
    reg [3:0] meta=0;
    reg last=0,group_last=0;
    wire can_accept,stored_valid,in_ready,out_valid,out_last,out_group_last;
    wire [15:0] stored_data,out_data;
    wire [3:0] stored_meta,out_meta;
    integer negative;
    fcnn_row_stage #(.LANES(1),.META_W(4)) stage (
        .clk(clk),.rst(rst),.in_valid(in_valid),.in_data(data),.in_meta(meta),.consume_row(consume),
        .can_accept(can_accept),.stored_valid(stored_valid),.stored_data(stored_data),.stored_meta(stored_meta));
    fcnn_product_register #(.DEST_W(4)) product (
        .clk(clk),.rst(rst),.in_valid(in_valid),.in_ready(in_ready),.in_data(data),.in_dest(meta),
        .in_last(last),.in_group_last(group_last),.out_valid(out_valid),.out_ready(out_ready),
        .out_data(out_data),.out_dest(out_meta),.out_last(out_last),.out_group_last(out_group_last));
    initial begin
        if (!$value$plusargs("negative=%d",negative)) negative=0;
        repeat(3) @(negedge clk);rst=0;
        if (negative==2) begin consume=1;@(negedge clk);$display("[FAIL] expected empty-consume guard missing");$finish;end
        in_valid=1;data=16'h1234;meta=4'd3;last=1;group_last=1;
        @(negedge clk);in_valid=0;
        if (stored_valid!==1 || out_valid!==1 || can_accept!==0 || in_ready!==0)
            begin $display("[FAIL] pipeline capture/readiness");$finish;end
        if (negative==1) begin in_valid=1;@(negedge clk);$display("[FAIL] expected overwrite guard missing");$finish;end
        repeat(3) @(negedge clk);
        if (stored_data!==16'h1234 || out_data!==16'h1234 || out_meta!==3 || !out_last || !out_group_last)
            begin $display("[FAIL] blocked pipeline payload");$finish;end
        // Consume and replace on the same edge in both modules.
        consume=1;out_ready=1;in_valid=1;data=16'h5678;meta=4'd9;last=0;group_last=0;
        @(negedge clk);consume=0;out_ready=0;in_valid=0;
        if (!stored_valid || !out_valid || stored_data!==16'h5678 || out_data!==16'h5678 ||
            stored_meta!==9 || out_meta!==9 || out_last || out_group_last)
            begin $display("[FAIL] same-edge replacement");$finish;end
        consume=1;out_ready=1;
        @(negedge clk);consume=0;out_ready=0;
        if (stored_valid || out_valid || !can_accept || !in_ready)
            begin $display("[FAIL] pipeline drain");$finish;end
        $display("[PASS] PIPELINE hold/replace/drain data and all tags");$finish;
    end
endmodule
`default_nettype wire
