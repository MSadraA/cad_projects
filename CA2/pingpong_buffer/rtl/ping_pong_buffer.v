`timescale 1ns/1ps
`default_nettype none
// Phase-1 payload buffer. The optional CA1 metadata extension is a separate top.
module ping_pong_buffer #(parameter integer LANES=7)(
    input clk,rst,wr_valid,output wr_ready,input [15:0] wr_data,input wr_group_last,
    output rd_valid,input rd_ready,output [15:0] rd_data,
    output [1:0] bank_full,bank_empty,output bank_select
);
    ac_pp_core #(.W(16),.LANES(LANES)) core(
        .clk(clk),.rst(rst),.wr_valid(wr_valid),.wr_ready(wr_ready),
        .wr_data(wr_data),.wr_group_last(wr_group_last),.rd_valid(rd_valid),
        .rd_ready(rd_ready),.rd_data(rd_data),.bank_full(bank_full),
        .bank_empty(bank_empty),.bank_select(bank_select));
endmodule
`default_nettype wire
