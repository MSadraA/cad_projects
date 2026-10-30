`timescale 1ns/1ps
`default_nettype none
// One s2 per payload bit: indexed write, shift to a fixed head on read.
module ac_pp_bank #(parameter integer W=16,LANES=7)(
    input clk,push,pop,input [LANES-1:0] select_slot,
    input [W-1:0] data,output [W-1:0] head
);
    wire [W-1:0] words[0:LANES];
    assign words[LANES]={W{1'b0}};
    assign head=words[0];
    genvar i,j;
    generate for(i=0;i<LANES;i=i+1) begin:slot
        for(j=0;j<W;j=j+1) begin:bit_cell
            s2 u(.D00(words[i][j]),.D01(data[j]),.D10(words[i+1][j]),.D11(data[j]),
                .A1(pop),.B1(1'b0),.A0(select_slot[i]),.B0(push),
                .clr(1'b0),.clk(clk),.out(words[i][j]));
        end
    end endgenerate
endmodule

// The final slot must terminate a legal group, so its end flag is constant 1.
// Earlier flags are stored and shift in parallel with data. No end pointer needed.
module ac_pp_ends #(parameter integer LANES=7)(
    input clk,push,pop,input [LANES-1:0] select_slot,input last,output head
);
    wire [LANES-1:0] words;
    assign words[LANES-1]=1'b1;
    assign head=words[0];
    genvar i;
    generate for(i=0;i<LANES-1;i=i+1) begin:slot
        s2 u(.D00(words[i]),.D01(last),.D10(words[i+1]),.D11(last),
            .A1(pop),.B1(1'b0),.A0(select_slot[i]),.B0(push),
            .clr(1'b0),.clk(clk),.out(words[i]));
    end endgenerate
endmodule

module ac_pp_core #(parameter integer W=16,LANES=7)(
    input clk,rst,wr_valid,output wr_ready,input [W-1:0] wr_data,input wr_group_last,
    output rd_valid,input rd_ready,output [W-1:0] rd_data,
    output [1:0] bank_full,bank_empty,output bank_select
);
    wire write_bank,read_bank,nwb,nrb;
    wire sealed0,sealed1,write_sealed;
    wire push,pop,push0,push1,pop0,pop1,close_write,close_read;
    wire release0,release1,end0,end1;
    wire [W-1:0] h0,h1;
    wire [LANES-1:0] wp;

    // 1. Bank handshakes. Full includes a sealed short group.
    ac_not nw(write_bank,nwb);
    ac_not nr(read_bank,nrb);
    ac_mux ws(sealed0,sealed1,write_bank,write_sealed);
    ac_not ready(write_sealed,wr_ready);
    ac_mux rv(sealed0,sealed1,read_bank,rd_valid);
    ac_and push_gate(wr_valid,wr_ready,push);
    ac_and pop_gate(rd_valid,rd_ready,pop);
    ac_and p0(push,nwb,push0),p1(push,write_bank,push1);
    ac_and q0(pop,nrb,pop0),q1(pop,read_bank,pop1);
    ac_and sw(push,wr_group_last,close_write);
    c1 read_close(.A0(1'b0),.A1(end0),.SA(pop),.B0(1'b0),.B1(end1),.SB(pop),
        .S0(read_bank),.S1(1'b0),.f(close_read));
    ac_and rel0(pop0,end0,release0),rel1(pop1,end1,release1);
    s2 full0(.D00(sealed0),.D01(1'b1),.D10(1'b0),.D11(1'b0),
        .A1(rst),.B1(release0),.A0(push0),.B0(wr_group_last),.clr(1'b0),.clk(clk),.out(sealed0));
    s2 full1(.D00(sealed1),.D01(1'b1),.D10(1'b0),.D11(1'b0),
        .A1(rst),.B1(release1),.A0(push1),.B0(wr_group_last),.clr(1'b0),.clk(clk),.out(sealed1));
    // Invariant: write_bank = read_bank XOR sealed0 XOR sealed1.
    // Reconstruct it in one C2 using read_bank and its shared complement.
    // This removes a redundant 13-gate state cell without restricting traffic.
    c2 wb(.D00(read_bank),.D01(nrb),.D10(nrb),.D11(read_bank),
        .A1(sealed0),.B1(1'b0),.A0(sealed1),.B0(1'b1),.out(write_bank));
    ac_dffe rb(clk,rst,close_read,nrb,read_bank);
    assign bank_select=write_bank;
    assign bank_full={sealed1,sealed0};
    // A fresh writer has wp[0]=1. Bank occupancy is visible even before seal.
    c1 empty0(.A0(1'b0),.A1(1'b0),.SA(1'b0),.B0(1'b1),.B1(1'b0),.SB(sealed0),
        .S0(write_bank),.S1(wp[0]),.f(bank_empty[0]));
    c1 empty1(.A0(1'b0),.A1(1'b0),.SA(1'b0),.B0(1'b1),.B1(1'b0),.SB(sealed1),
        .S0(nwb),.S1(wp[0]),.f(bank_empty[1]));

    // 2. One-hot write pointer: rotate by wiring, with no decoder or adder.
    genvar i;
    generate if(LANES==1) begin:single
        assign wp[0]=1'b1;
    end else begin:multiple
        for(i=0;i<LANES;i=i+1) begin:pointer
            localparam integer PREV=(i+LANES-1)%LANES;
            localparam INIT=(i==0);
            s2 w(.D00(wp[i]),.D01(wp[PREV]),.D10(INIT),.D11(INIT),
                .A1(rst),.B1(close_write),.A0(push),.B0(1'b1),.clr(1'b0),.clk(clk),.out(wp[i]));
        end
    end endgenerate

    // 3. Data registers are not reset. Sealed flags hide stale contents.
    ac_pp_bank #(.W(W),.LANES(LANES)) bank0(clk,push0,pop0,wp,wr_data,h0);
    ac_pp_bank #(.W(W),.LANES(LANES)) bank1(clk,push1,pop1,wp,wr_data,h1);
    ac_pp_ends #(.LANES(LANES)) ends0(clk,push0,pop0,wp,wr_group_last,end0);
    ac_pp_ends #(.LANES(LANES)) ends1(clk,push1,pop1,wp,wr_group_last,end1);
    ac_muxv #(.W(W)) read_head(h0,h1,read_bank,rd_data);
endmodule
`default_nettype wire
