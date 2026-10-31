`timescale 1ns/1ps
`default_nettype none
module tb_ping_pong_buffer #(parameter integer LANES=7, DEST_W=4);
    localparam integer ITEMS=1200;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    reg wr_valid=0,rd_ready=0;
    reg [15:0] wr_data=0;
    reg [DEST_W-1:0] wr_dest=0;
    reg wr_last=0,wr_group_last=0;
    wire wr_ready,rd_valid,rd_last;
    wire [15:0] rd_data;
    wire [DEST_W-1:0] rd_dest;
    wire [1:0] full,empty;
    wire select_bank;
    integer writes=0,reads=0,group_id=0,group_pos=0,cycles=0,stalls=0,concurrent=0;
    integer group_len,seed=12587,i;
    integer fifo_group[0:ITEMS-1];
    reg group_complete[0:ITEMS-1];
    reg pushed=0,was_blocked=0,monitor_enabled=1;
    reg [15:0] held_data;
    reg [DEST_W-1:0] held_dest;
    reg held_last;
    fcnn_ping_pong_buffer #(.LANES(LANES),.DEST_W(DEST_W)) dut (
        .clk(clk),.rst(rst),.wr_valid(wr_valid),.wr_ready(wr_ready),.wr_data(wr_data),.wr_dest(wr_dest),
        .wr_last(wr_last),.wr_group_last(wr_group_last),.rd_valid(rd_valid),.rd_ready(rd_ready),
        .rd_data(rd_data),.rd_dest(rd_dest),.rd_last(rd_last),.bank_full(full),.bank_empty(empty),.bank_select(select_bank)
    );
    wire ref_wr_ready,ref_rd_valid,ref_rd_last,ref_bank_select;
    wire [15:0] ref_rd_data;
    wire [DEST_W-1:0] ref_rd_dest;
    wire [1:0] ref_full,ref_empty;
    ca1_ping_pong_reference #(.LANES(LANES),.DEST_W(DEST_W)) baseline(
        .clk(clk),.rst(rst),.wr_valid(wr_valid),.wr_ready(ref_wr_ready),.wr_data(wr_data),.wr_dest(wr_dest),
        .wr_last(wr_last),.wr_group_last(wr_group_last),.rd_valid(ref_rd_valid),.rd_ready(rd_ready),
        .rd_data(ref_rd_data),.rd_dest(ref_rd_dest),.rd_last(ref_rd_last),
        .bank_full(ref_full),.bank_empty(ref_empty),.bank_select(ref_bank_select));
    wire core_wr_ready,core_rd_valid,core_bank_select;
    wire [15:0] core_rd_data;
    wire [1:0] core_full,core_empty;
    ping_pong_buffer #(.LANES(LANES)) payload(
        .clk(clk),.rst(rst),.wr_valid(wr_valid),.wr_ready(core_wr_ready),.wr_data(wr_data),
        .wr_group_last(wr_group_last),.rd_valid(core_rd_valid),.rd_ready(rd_ready),.rd_data(core_rd_data),
        .bank_full(core_full),.bank_empty(core_empty),.bank_select(core_bank_select));
    always @(negedge clk) if(!rst) begin
        if({wr_ready,rd_valid,full,empty,select_bank} !==
           {ref_wr_ready,ref_rd_valid,ref_full,ref_empty,ref_bank_select})
            $fatal(1,"CA1 control mismatch lanes=%0d cycle=%0d got=%b expected=%b",LANES,cycles,
                   {wr_ready,rd_valid,full,empty,select_bank},
                   {ref_wr_ready,ref_rd_valid,ref_full,ref_empty,ref_bank_select});
        if({wr_ready,rd_valid,full,empty,select_bank} !==
           {core_wr_ready,core_rd_valid,core_full,core_empty,core_bank_select})
            $fatal(1,"Payload core control mismatch");
        if(rd_valid && ({rd_data,rd_dest,rd_last} !== {ref_rd_data,ref_rd_dest,ref_rd_last} ||
                        rd_data !== core_rd_data))
            $fatal(1,"CA1 payload mismatch lanes=%0d cycle=%0d",LANES,cycles);
    end
    // Independent FIFO ordering and group-closure checks.
    always @(posedge clk) if (!rst && monitor_enabled) begin
        cycles=cycles+1;pushed=wr_valid && wr_ready;
        if (was_blocked && (!rd_valid || rd_data!==held_data || rd_dest!==held_dest || rd_last!==held_last))
            begin $display("[FAIL] PP changed blocked output");$fatal(1,"Buffer check failed");end
        if (pushed) begin
            fifo_group[writes]=group_id;
            writes=writes+1;group_pos=group_pos+1;
            if (wr_group_last) begin group_complete[group_id]=1;group_id=group_id+1;group_pos=0;end
        end
        if (rd_valid) begin
            if (reads>=writes || !group_complete[fifo_group[reads]])
                begin $display("[FAIL] PP read from incomplete group");$fatal(1,"Buffer check failed");end
            if (rd_ready) begin
                if (rd_data!==(16'h1000+reads) || rd_dest!==(reads%((2**DEST_W)-1)) || rd_last!==(reads%5==0))
                    begin $display("[FAIL] PP FIFO/metadata index=%0d",reads);$fatal(1,"Buffer check failed");end
                reads=reads+1;
            end
        end
        if (wr_valid && !wr_ready) stalls=stalls+1;
        if (pushed && rd_valid && rd_ready) concurrent=concurrent+1;
        was_blocked=rd_valid && !rd_ready;
        held_data=rd_data;held_dest=rd_dest;held_last=rd_last;
        if (writes-reads>2*LANES) begin $display("[FAIL] PP capacity exceeded");$fatal(1,"Buffer check failed");end
        if (cycles>30000) begin $display("[FAIL] PP timeout");$fatal(1,"Buffer check failed");end
    end
    initial begin
        for(i=0;i<ITEMS;i=i+1) group_complete[i]=0;
        repeat(3) @(negedge clk);rst=0;
        while (writes<ITEMS || reads<ITEMS) begin
            @(negedge clk);
            seed=(seed*1664525+1013904223) & 32'h7fffffff;
            // Hold valid while blocked. Payload is based on accepted writes.
            if (writes<ITEMS) begin
                wr_valid=(wr_valid && !pushed) || ((seed%5)!=0);
                wr_data=16'h1000+writes;
                wr_dest=writes%((2**DEST_W)-1);
                wr_last=writes%5==0;
                group_len=(group_id%3==0)?LANES:((group_id%LANES)+1);
                wr_group_last=(group_pos+1==group_len) || writes==ITEMS-1;
            end else begin wr_valid=0;wr_group_last=0;end
            // Periodic long pauses force both banks full; then random stalls.
            rd_ready=(cycles%53>=17) && ((seed%7)!=0);
        end
        @(negedge clk);
        if (stalls==0 || concurrent==0 || empty!==2'b11)
            begin $display("[FAIL] PP insufficient coverage or incomplete drain");$fatal(1,"Buffer check failed");end
        // Reset with unread data: partial group for LANES>1, sealed for LANES=1.
        monitor_enabled=0;wr_valid=1;rd_ready=0;
        wr_data=16'h55aa;wr_dest=0;wr_last=0;wr_group_last=(LANES==1);
        @(negedge clk);wr_valid=0;
        repeat(3) @(negedge clk);
        if (LANES>1 && rd_valid) begin $display("[FAIL] PP partial group visible");$fatal(1,"Buffer check failed");end
        rst=1;@(negedge clk);rst=0;rd_ready=1;
        repeat(3) @(negedge clk);
        if (rd_valid || empty!==2'b11 || full!==0) begin $display("[FAIL] PP reset");$fatal(1,"Buffer check failed");end
        $display("[PASS] PINGPONG lanes=%0d items=%0d blocked=%0d simultaneous=%0d",LANES,ITEMS,stalls,concurrent);
        $finish;
    end
endmodule
`default_nettype wire
