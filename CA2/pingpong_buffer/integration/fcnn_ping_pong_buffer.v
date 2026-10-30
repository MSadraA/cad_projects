`timescale 1ns/1ps
`default_nettype none
// Exact CA1 interface. Independent per-item metadata is retained without loss.
// Its extra storage necessarily exceeds the TA payload-only gate budget.
module fcnn_ping_pong_buffer #(parameter integer LANES=7,DEST_W=4)(
    input clk,rst,wr_valid,output wr_ready,
    input [15:0] wr_data,input [DEST_W-1:0] wr_dest,input wr_last,wr_group_last,
    output rd_valid,input rd_ready,
    output [15:0] rd_data,output [DEST_W-1:0] rd_dest,output rd_last,
    output [1:0] bank_full,bank_empty,output bank_select
);
    ac_pp_core #(.W(17+DEST_W),.LANES(LANES)) core(
        .clk(clk),.rst(rst),.wr_valid(wr_valid),.wr_ready(wr_ready),
        .wr_data({wr_last,wr_dest,wr_data}),.wr_group_last(wr_group_last),
        .rd_valid(rd_valid),.rd_ready(rd_ready),.rd_data({rd_last,rd_dest,rd_data}),
        .bank_full(bank_full),.bank_empty(bank_empty),.bank_select(bank_select));
endmodule
`default_nettype wire
