`timescale 1ns/1ps
`default_nettype none

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

    ac_not nw(write_bank,nwb); ac_not nr(read_bank,nrb);
    ac_mux ws(sealed0,sealed1,write_bank,write_sealed); ac_not ready(write_sealed,wr_ready);
    ac_mux rv(sealed0,sealed1,read_bank,rd_valid);
    ac_and push_gate(wr_valid,wr_ready,push); ac_and pop_gate(rd_valid,rd_ready,pop);
    ac_and p0(push,nwb,push0), p1(push,write_bank,push1);
    ac_and q0(pop,nrb,pop0), q1(pop,read_bank,pop1);
    ac_and sw(push,wr_group_last,close_write);
    c1 read_close(.A0(1'b0),.A1(end0),.SA(pop),.B0(1'b0),.B1(end1),.SB(pop), .S0(read_bank),.S1(1'b0),.f(close_read));
    ac_and rel0(pop0,end0,release0), rel1(pop1,end1,release1);
    
    s2 full0(.D00(sealed0),.D01(1'b1),.D10(1'b0),.D11(1'b0),.A1(rst),.B1(release0),.A0(push0),.B0(wr_group_last),.clr(1'b0),.clk(clk),.out(sealed0));
    s2 full1(.D00(sealed1),.D01(1'b1),.D10(1'b0),.D11(1'b0),.A1(rst),.B1(release1),.A0(push1),.B0(wr_group_last),.clr(1'b0),.clk(clk),.out(sealed1));
    c2 wb(.D00(read_bank),.D01(nrb),.D10(nrb),.D11(read_bank),.A1(sealed0),.B1(1'b0),.A0(sealed1),.B0(1'b1),.out(write_bank));
    ac_dffe rb(clk,rst,close_read,nrb,read_bank);
    assign bank_select=write_bank;
    assign bank_full={sealed1,sealed0};
    
    c1 empty0(.A0(1'b0),.A1(1'b0),.SA(1'b0),.B0(1'b1),.B1(1'b0),.SB(sealed0), .S0(write_bank),.S1(wp[0]),.f(bank_empty[0]));
    c1 empty1(.A0(1'b0),.A1(1'b0),.SA(1'b0),.B0(1'b1),.B1(1'b0),.SB(sealed1), .S0(nwb),.S1(wp[0]),.f(bank_empty[1]));

    genvar i;
    generate if(LANES==1) begin:single
        assign wp[0]=1'b1;
    end else begin:multiple
        for(i=0;i<LANES;i=i+1) begin:pointer
            localparam integer PREV=(i+LANES-1)%LANES;
            localparam INIT=(i==0);
            s2 w(.D00(wp[i]),.D01(wp[PREV]),.D10(INIT),.D11(INIT),.A1(rst),.B1(close_write),.A0(push),.B0(1'b1),.clr(1'b0),.clk(clk),.out(wp[i]));
        end
    end endgenerate

    ac_pp_bank #(.W(W),.LANES(LANES)) bank0(clk,push0,pop0,wp,wr_data,h0);
    ac_pp_bank #(.W(W),.LANES(LANES)) bank1(clk,push1,pop1,wp,wr_data,h1);
    ac_pp_ends #(.LANES(LANES)) ends0(clk,push0,pop0,wp,wr_group_last,end0);
    ac_pp_ends #(.LANES(LANES)) ends1(clk,push1,pop1,wp,wr_group_last,end1);
    ac_muxv #(.W(W)) read_head(h0,h1,read_bank,rd_data);
endmodule

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

module ac_sig11_product(input [9:0] a,b,output [21:0] p);
    wire pp_0_0; ac_and pp0_0(a[0],b[0],pp_0_0);
    wire pp_0_1; ac_and pp0_1(a[0],b[1],pp_0_1);
    wire pp_0_2; ac_and pp0_2(a[0],b[2],pp_0_2);
    wire pp_0_3; ac_and pp0_3(a[0],b[3],pp_0_3);
    wire pp_0_4; ac_and pp0_4(a[0],b[4],pp_0_4);
    wire pp_0_5; ac_and pp0_5(a[0],b[5],pp_0_5);
    wire pp_0_6; ac_and pp0_6(a[0],b[6],pp_0_6);
    wire pp_0_7; ac_and pp0_7(a[0],b[7],pp_0_7);
    wire pp_0_8; ac_and pp0_8(a[0],b[8],pp_0_8);
    wire pp_0_9; ac_and pp0_9(a[0],b[9],pp_0_9);
    wire pp_1_0; ac_and pp1_0(a[1],b[0],pp_1_0);
    wire pp_1_1; ac_and pp1_1(a[1],b[1],pp_1_1);
    wire pp_1_2; ac_and pp1_2(a[1],b[2],pp_1_2);
    wire pp_1_3; ac_and pp1_3(a[1],b[3],pp_1_3);
    wire pp_1_4; ac_and pp1_4(a[1],b[4],pp_1_4);
    wire pp_1_5; ac_and pp1_5(a[1],b[5],pp_1_5);
    wire pp_1_6; ac_and pp1_6(a[1],b[6],pp_1_6);
    wire pp_1_7; ac_and pp1_7(a[1],b[7],pp_1_7);
    wire pp_1_8; ac_and pp1_8(a[1],b[8],pp_1_8);
    wire pp_1_9; ac_and pp1_9(a[1],b[9],pp_1_9);
    wire pp_2_0; ac_and pp2_0(a[2],b[0],pp_2_0);
    wire pp_2_1; ac_and pp2_1(a[2],b[1],pp_2_1);
    wire pp_2_2; ac_and pp2_2(a[2],b[2],pp_2_2);
    wire pp_2_3; ac_and pp2_3(a[2],b[3],pp_2_3);
    wire pp_2_4; ac_and pp2_4(a[2],b[4],pp_2_4);
    wire pp_2_5; ac_and pp2_5(a[2],b[5],pp_2_5);
    wire pp_2_6; ac_and pp2_6(a[2],b[6],pp_2_6);
    wire pp_2_7; ac_and pp2_7(a[2],b[7],pp_2_7);
    wire pp_2_8; ac_and pp2_8(a[2],b[8],pp_2_8);
    wire pp_2_9; ac_and pp2_9(a[2],b[9],pp_2_9);
    wire pp_3_0; ac_and pp3_0(a[3],b[0],pp_3_0);
    wire pp_3_1; ac_and pp3_1(a[3],b[1],pp_3_1);
    wire pp_3_2; ac_and pp3_2(a[3],b[2],pp_3_2);
    wire pp_3_3; ac_and pp3_3(a[3],b[3],pp_3_3);
    wire pp_3_4; ac_and pp3_4(a[3],b[4],pp_3_4);
    wire pp_3_5; ac_and pp3_5(a[3],b[5],pp_3_5);
    wire pp_3_6; ac_and pp3_6(a[3],b[6],pp_3_6);
    wire pp_3_7; ac_and pp3_7(a[3],b[7],pp_3_7);
    wire pp_3_8; ac_and pp3_8(a[3],b[8],pp_3_8);
    wire pp_3_9; ac_and pp3_9(a[3],b[9],pp_3_9);
    wire pp_4_0; ac_and pp4_0(a[4],b[0],pp_4_0);
    wire pp_4_1; ac_and pp4_1(a[4],b[1],pp_4_1);
    wire pp_4_2; ac_and pp4_2(a[4],b[2],pp_4_2);
    wire pp_4_3; ac_and pp4_3(a[4],b[3],pp_4_3);
    wire pp_4_4; ac_and pp4_4(a[4],b[4],pp_4_4);
    wire pp_4_5; ac_and pp4_5(a[4],b[5],pp_4_5);
    wire pp_4_6; ac_and pp4_6(a[4],b[6],pp_4_6);
    wire pp_4_7; ac_and pp4_7(a[4],b[7],pp_4_7);
    wire pp_4_8; ac_and pp4_8(a[4],b[8],pp_4_8);
    wire pp_4_9; ac_and pp4_9(a[4],b[9],pp_4_9);
    wire pp_5_0; ac_and pp5_0(a[5],b[0],pp_5_0);
    wire pp_5_1; ac_and pp5_1(a[5],b[1],pp_5_1);
    wire pp_5_2; ac_and pp5_2(a[5],b[2],pp_5_2);
    wire pp_5_3; ac_and pp5_3(a[5],b[3],pp_5_3);
    wire pp_5_4; ac_and pp5_4(a[5],b[4],pp_5_4);
    wire pp_5_5; ac_and pp5_5(a[5],b[5],pp_5_5);
    wire pp_5_6; ac_and pp5_6(a[5],b[6],pp_5_6);
    wire pp_5_7; ac_and pp5_7(a[5],b[7],pp_5_7);
    wire pp_5_8; ac_and pp5_8(a[5],b[8],pp_5_8);
    wire pp_5_9; ac_and pp5_9(a[5],b[9],pp_5_9);
    wire pp_6_0; ac_and pp6_0(a[6],b[0],pp_6_0);
    wire pp_6_1; ac_and pp6_1(a[6],b[1],pp_6_1);
    wire pp_6_2; ac_and pp6_2(a[6],b[2],pp_6_2);
    wire pp_6_3; ac_and pp6_3(a[6],b[3],pp_6_3);
    wire pp_6_4; ac_and pp6_4(a[6],b[4],pp_6_4);
    wire pp_6_5; ac_and pp6_5(a[6],b[5],pp_6_5);
    wire pp_6_6; ac_and pp6_6(a[6],b[6],pp_6_6);
    wire pp_6_7; ac_and pp6_7(a[6],b[7],pp_6_7);
    wire pp_6_8; ac_and pp6_8(a[6],b[8],pp_6_8);
    wire pp_6_9; ac_and pp6_9(a[6],b[9],pp_6_9);
    wire pp_7_0; ac_and pp7_0(a[7],b[0],pp_7_0);
    wire pp_7_1; ac_and pp7_1(a[7],b[1],pp_7_1);
    wire pp_7_2; ac_and pp7_2(a[7],b[2],pp_7_2);
    wire pp_7_3; ac_and pp7_3(a[7],b[3],pp_7_3);
    wire pp_7_4; ac_and pp7_4(a[7],b[4],pp_7_4);
    wire pp_7_5; ac_and pp7_5(a[7],b[5],pp_7_5);
    wire pp_7_6; ac_and pp7_6(a[7],b[6],pp_7_6);
    wire pp_7_7; ac_and pp7_7(a[7],b[7],pp_7_7);
    wire pp_7_8; ac_and pp7_8(a[7],b[8],pp_7_8);
    wire pp_7_9; ac_and pp7_9(a[7],b[9],pp_7_9);
    wire pp_8_0; ac_and pp8_0(a[8],b[0],pp_8_0);
    wire pp_8_1; ac_and pp8_1(a[8],b[1],pp_8_1);
    wire pp_8_2; ac_and pp8_2(a[8],b[2],pp_8_2);
    wire pp_8_3; ac_and pp8_3(a[8],b[3],pp_8_3);
    wire pp_8_4; ac_and pp8_4(a[8],b[4],pp_8_4);
    wire pp_8_5; ac_and pp8_5(a[8],b[5],pp_8_5);
    wire pp_8_6; ac_and pp8_6(a[8],b[6],pp_8_6);
    wire pp_8_7; ac_and pp8_7(a[8],b[7],pp_8_7);
    wire pp_8_8; ac_and pp8_8(a[8],b[8],pp_8_8);
    wire pp_8_9; ac_and pp8_9(a[8],b[9],pp_8_9);
    wire pp_9_0; ac_and pp9_0(a[9],b[0],pp_9_0);
    wire pp_9_1; ac_and pp9_1(a[9],b[1],pp_9_1);
    wire pp_9_2; ac_and pp9_2(a[9],b[2],pp_9_2);
    wire pp_9_3; ac_and pp9_3(a[9],b[3],pp_9_3);
    wire pp_9_4; ac_and pp9_4(a[9],b[4],pp_9_4);
    wire pp_9_5; ac_and pp9_5(a[9],b[5],pp_9_5);
    wire pp_9_6; ac_and pp9_6(a[9],b[6],pp_9_6);
    wire pp_9_7; ac_and pp9_7(a[9],b[7],pp_9_7);
    wire pp_9_8; ac_and pp9_8(a[9],b[8],pp_9_8);
    wire pp_9_9; ac_and pp9_9(a[9],b[9],pp_9_9);
    
    wire s0,c0; ac_fa fa0(pp_0_2,pp_1_1,pp_2_0,s0,c0);
    wire s1,c1; ac_fa fa1(pp_0_3,pp_1_2,pp_2_1,s1,c1);
    wire s2,c2; ac_fa fa2(pp_3_0,c0,s1,s2,c2);
    wire s3,c3; ac_fa fa3(pp_0_4,pp_1_3,pp_2_2,s3,c3);
    wire s4,c4; ac_fa fa4(pp_3_1,pp_4_0,c1,s4,c4);
    wire s5,c5; ac_fa fa5(c2,s3,s4,s5,c5);
    wire s6,c6; ac_fa fa6(pp_0_5,pp_1_4,pp_2_3,s6,c6);
    wire s7,c7; ac_fa fa7(pp_3_2,pp_4_1,pp_5_0,s7,c7);
    wire s8,c8; ac_fa fa8(c3,c4,c5,s8,c8);
    wire s9,c9; ac_fa fa9(s6,s7,s8,s9,c9);
    wire s10,c10; ac_fa fa10(pp_0_6,pp_1_5,pp_2_4,s10,c10);
    wire s11,c11; ac_fa fa11(pp_3_3,pp_4_2,pp_5_1,s11,c11);
    wire s12,c12; ac_fa fa12(pp_6_0,c6,c7,s12,c12);
    wire s13,c13; ac_fa fa13(c8,c9,s10,s13,c13);
    wire s14,c14; ac_fa fa14(s11,s12,s13,s14,c14);
    wire s15,c15; ac_fa fa15(pp_0_7,pp_1_6,pp_2_5,s15,c15);
    wire s16,c16; ac_fa fa16(pp_3_4,pp_4_3,pp_5_2,s16,c16);
    wire s17,c17; ac_fa fa17(pp_6_1,pp_7_0,c10,s17,c17);
    wire s18,c18; ac_fa fa18(c11,c12,c13,s18,c18);
    wire s19,c19; ac_fa fa19(c14,s15,s16,s19,c19);
    wire s20,c20; ac_fa fa20(s17,s18,s19,s20,c20);
    wire s21,c21; ac_fa fa21(pp_0_8,pp_1_7,pp_2_6,s21,c21);
    wire s22,c22; ac_fa fa22(pp_3_5,pp_4_4,pp_5_3,s22,c22);
    wire s23,c23; ac_fa fa23(pp_6_2,pp_7_1,pp_8_0,s23,c23);
    wire s24,c24; ac_fa fa24(c15,c16,c17,s24,c24);
    wire s25,c25; ac_fa fa25(c18,c19,c20,s25,c25);
    wire s26,c26; ac_fa fa26(s21,s22,s23,s26,c26);
    wire s27,c27; ac_fa fa27(s24,s25,s26,s27,c27);
    wire s28,c28; ac_fa fa28(pp_0_9,pp_1_8,pp_2_7,s28,c28);
    wire s29,c29; ac_fa fa29(pp_3_6,pp_4_5,pp_5_4,s29,c29);
    wire s30,c30; ac_fa fa30(pp_6_3,pp_7_2,pp_8_1,s30,c30);
    wire s31,c31; ac_fa fa31(pp_9_0,c21,c22,s31,c31);
    wire s32,c32; ac_fa fa32(c23,c24,c25,s32,c32);
    wire s33,c33; ac_fa fa33(c26,c27,s28,s33,c33);
    wire s34,c34; ac_fa fa34(s29,s30,s31,s34,c34);
    wire s35,c35; ac_fa fa35(s32,s33,s34,s35,c35);
    wire s36,c36; ac_fa fa36(a[0],pp_1_9,pp_2_8,s36,c36);
    wire s37,c37; ac_fa fa37(pp_3_7,pp_4_6,pp_5_5,s37,c37);
    wire s38,c38; ac_fa fa38(pp_6_4,pp_7_3,pp_8_2,s38,c38);
    wire s39,c39; ac_fa fa39(pp_9_1,b[0],c28,s39,c39);
    wire s40,c40; ac_fa fa40(c29,c30,c31,s40,c40);
    wire s41,c41; ac_fa fa41(c32,c33,c34,s41,c41);
    wire s42,c42; ac_fa fa42(c35,s36,s37,s42,c42);
    wire s43,c43; ac_fa fa43(s38,s39,s40,s43,c43);
    wire s44,c44; ac_fa fa44(s41,s42,s43,s44,c44);
    wire s45,c45; ac_fa fa45(a[1],pp_2_9,pp_3_8,s45,c45);
    wire s46,c46; ac_fa fa46(pp_4_7,pp_5_6,pp_6_5,s46,c46);
    wire s47,c47; ac_fa fa47(pp_7_4,pp_8_3,pp_9_2,s47,c47);
    wire s48,c48; ac_fa fa48(b[1],c36,c37,s48,c48);
    wire s49,c49; ac_fa fa49(c38,c39,c40,s49,c49);
    wire s50,c50; ac_fa fa50(c41,c42,c43,s50,c50);
    wire s51,c51; ac_fa fa51(c44,s45,s46,s51,c51);
    wire s52,c52; ac_fa fa52(s47,s48,s49,s52,c52);
    wire s53,c53; ac_fa fa53(s50,s51,s52,s53,c53);
    wire s54,c54; ac_fa fa54(a[2],pp_3_9,pp_4_8,s54,c54);
    wire s55,c55; ac_fa fa55(pp_5_7,pp_6_6,pp_7_5,s55,c55);
    wire s56,c56; ac_fa fa56(pp_8_4,pp_9_3,b[2],s56,c56);
    wire s57,c57; ac_fa fa57(c45,c46,c47,s57,c57);
    wire s58,c58; ac_fa fa58(c48,c49,c50,s58,c58);
    wire s59,c59; ac_fa fa59(c51,c52,c53,s59,c59);
    wire s60,c60; ac_fa fa60(s54,s55,s56,s60,c60);
    wire s61,c61; ac_fa fa61(s57,s58,s59,s61,c61);
    wire s62,c62; ac_fa fa62(a[3],pp_4_9,pp_5_8,s62,c62);
    wire s63,c63; ac_fa fa63(pp_6_7,pp_7_6,pp_8_5,s63,c63);
    wire s64,c64; ac_fa fa64(pp_9_4,b[3],c54,s64,c64);
    wire s65,c65; ac_fa fa65(c55,c56,c57,s65,c65);
    wire s66,c66; ac_fa fa66(c58,c59,c60,s66,c66);
    wire s67,c67; ac_fa fa67(c61,s62,s63,s67,c67);
    wire s68,c68; ac_fa fa68(s64,s65,s66,s68,c68);
    wire s69,c69; ac_fa fa69(a[4],pp_5_9,pp_6_8,s69,c69);
    wire s70,c70; ac_fa fa70(pp_7_7,pp_8_6,pp_9_5,s70,c70);
    wire s71,c71; ac_fa fa71(b[4],c62,c63,s71,c71);
    wire s72,c72; ac_fa fa72(c64,c65,c66,s72,c72);
    wire s73,c73; ac_fa fa73(c67,c68,s69,s73,c73);
    wire s74,c74; ac_fa fa74(s70,s71,s72,s74,c74);
    wire s75,c75; ac_fa fa75(a[5],pp_6_9,pp_7_8,s75,c75);
    wire s76,c76; ac_fa fa76(pp_8_7,pp_9_6,b[5],s76,c76);
    wire s77,c77; ac_fa fa77(c69,c70,c71,s77,c77);
    wire s78,c78; ac_fa fa78(c72,c73,c74,s78,c78);
    wire s79,c79; ac_fa fa79(s75,s76,s77,s79,c79);
    wire s80,c80; ac_fa fa80(a[6],pp_7_9,pp_8_8,s80,c80);
    wire s81,c81; ac_fa fa81(pp_9_7,b[6],c75,s81,c81);
    wire s82,c82; ac_fa fa82(c76,c77,c78,s82,c82);
    wire s83,c83; ac_fa fa83(c79,s80,s81,s83,c83);
    wire s84,c84; ac_fa fa84(a[7],pp_8_9,pp_9_8,s84,c84);
    wire s85,c85; ac_fa fa85(b[7],c80,c81,s85,c85);
    wire s86,c86; ac_fa fa86(c82,c83,s84,s86,c86);
    wire s87,c87; ac_fa fa87(a[8],pp_9_9,b[8],s87,c87);
    wire s88,c88; ac_fa fa88(c84,c85,c86,s88,c88);
    wire s89,c89; ac_fa fa89(a[9],b[9],c87,s89,c89);
    
    assign p[0]=pp_0_0;
    wire r1; ac_ha ha1(pp_0_1,pp_1_0,p[1],r1);
    wire r2; ac_ha ha2(s0,r1,p[2],r2);
    wire r3; ac_ha ha3(s2,r2,p[3],r3);
    wire r4; ac_ha ha4(s5,r3,p[4],r4);
    wire r5; ac_ha ha5(s9,r4,p[5],r5);
    wire r6; ac_ha ha6(s14,r5,p[6],r6);
    wire r7; ac_ha ha7(s20,r6,p[7],r7);
    wire r8; ac_ha ha8(s27,r7,p[8],r8);
    wire r9; ac_ha ha9(s35,r8,p[9],r9);
    wire r10; ac_ha ha10(s44,r9,p[10],r10);
    wire r11; ac_ha ha11(s53,r10,p[11],r11);
    wire r12; ac_fa ripple12(s60,s61,r11,p[12],r12);
    wire r13; ac_fa ripple13(s67,s68,r12,p[13],r13);
    wire r14; ac_fa ripple14(s73,s74,r13,p[14],r14);
    wire r15; ac_fa ripple15(s78,s79,r14,p[15],r15);
    wire r16; ac_fa ripple16(s82,s83,r15,p[16],r16);
    wire r17; ac_fa ripple17(s85,s86,r16,p[17],r17);
    wire r18; ac_fa ripple18(s87,s88,r17,p[18],r18);
    wire r19; ac_fa ripple19(c88,s89,r18,p[19],r19);
    wire r20; ac_fa ripple20(1'b1,c89,r19,p[20],r20);
    assign p[21]=r20;
endmodule

module fcnn_fp16_adder #(
    parameter integer ZERO_FRAC_IS_ZERO=1,
    parameter [4:0] OVERFLOW_EXP=5'd31
)(input [15:0] a,b,output [15:0] result);
    wire va,vb,a_ge_b,swap,sub,sign_big;
    wire [14:0] big_word,small_word;
    wire [4:0] nsmall_exp,diff;
    wire unused_diff;
    ac_fp_valid #(.ZERO_FRAC_IS_ZERO(ZERO_FRAC_IS_ZERO)) ca(a,va),cb(b,vb);
    ac_ge #(.W(15)) cmp(a[14:0],b[14:0],a_ge_b);
    ac_not ns(a_ge_b,swap);
    ac_muxv #(.W(15)) mb(a[14:0],b[14:0],swap,big_word);
    ac_muxv #(.W(15)) ms(b[14:0],a[14:0],swap,small_word);
    ac_mux sg(a[15],b[15],swap,sign_big);
    ac_xor sx(a[15],b[15],sub);
    genvar i;
    generate for(i=0;i<5;i=i+1) begin:neg_exp
        ac_not n(small_word[i+10],nsmall_exp[i]);
    end endgenerate
    ac_add #(.W(5)) ed(big_word[14:10],nsmall_exp,1'b1,diff,unused_diff);

    wire [12:0] aligned,small_xor,sum,norm;
    wire sum_carry,add_carry;
    ac_rshift_jam13 align({1'b1,small_word[9:0],2'b00},diff,aligned);
    wire [12:1] carry_chain;
    assign sum[0]=aligned[0];
    ac_lut2 #(.T(4'b0100)) low_carry(sub,aligned[0],carry_chain[1]);
    ac_xor x1(aligned[1],sub,small_xor[1]);
    ac_ha bit1(small_xor[1],carry_chain[1],sum[1],carry_chain[2]);
    generate for(i=2;i<12;i=i+1) begin:arithmetic_bits
        ac_xor x(aligned[i],sub,small_xor[i]);
        ac_fa f(big_word[i-2],small_xor[i],carry_chain[i],sum[i],carry_chain[i+1]);
    end endgenerate
    ac_xor x12(aligned[12],sub,small_xor[12]);
    ac_lut2 #(.T(4'b1001)) high_sum(small_xor[12],carry_chain[12],sum[12]);
    ac_or high_carry(small_xor[12],carry_chain[12],sum_carry);
    ac_lut2 #(.T(4'b0100)) cg(sum_carry,sub,add_carry);

    wire [3:0] lshift;
    wire [5:0] final_exp,neg_shift;
    wire unused_e;
    wire raw_low_nz;
    ac_normalize13 normalizer(sum,norm,lshift,raw_low_nz);
    generate for(i=0;i<4;i=i+1) begin:delta_bits
        ac_lut2 #(.T(4'b0001)) n(lshift[i],add_carry,neg_shift[i]);
    end endgenerate
    ac_not nh(add_carry,neg_shift[4]);
    assign neg_shift[5]=neg_shift[4];
    ac_add #(.W(6)) adjust({1'b0,big_word[14:10]},neg_shift,1'b1,final_exp,unused_e);
    wire [9:0] final_fraction;
    ac_muxv #(.W(10)) carry_fraction(norm[11:2],sum[12:3],add_carry,final_fraction);

    wire raw_nz,exp_nz,under,over,exp31,normal_ok;
    wire [15:0] packed_finite,packed_inf,computed;
    ac_or rc(raw_low_nz,add_carry,raw_nz);
    ac_reduce_or #(.W(6)) re(final_exp,exp_nz);
    wire exp_negative;
    ac_lut2 #(.T(4'b0100)) neg(final_exp[5],add_carry,exp_negative);
    ac_lut2 #(.T(4'b1101)) uf(exp_negative,exp_nz,under);
    ac_eq_const #(.W(5),.K(5'd31)) of(final_exp[4:0],exp31);
    ac_or ov(final_exp[5],exp31,over);
    ac_lut2 #(.T(4'b0010)) ok(under,raw_nz,normal_ok);
    assign packed_finite={sign_big,final_exp[4:0],final_fraction};
    assign packed_inf={sign_big,OVERFLOW_EXP,10'd0};
    generate for(i=0;i<16;i=i+1) begin:output_bits
        c2 fmt(.D00(1'b0),.D01(1'b0),.D10(packed_finite[i]),.D11(packed_inf[i]),
            .A1(normal_ok),.B1(1'b0),.A0(over),.B0(1'b1),.out(computed[i]));
        c1 select(.A0(1'b0),.A1(b[i]),.SA(vb),.B0(a[i]),.B1(computed[i]),.SB(vb),
            .S0(va),.S1(1'b0),.f(result[i]));
    end endgenerate
endmodule

module fcnn_fp16_multiplier #(
    parameter integer ZERO_FRAC_IS_ZERO=1,
    parameter [4:0] OVERFLOW_EXP=5'd31
)(input [15:0] a,b,output [15:0] result);
    wire va,vb,sign_result;
    ac_fp_valid #(.ZERO_FRAC_IS_ZERO(ZERO_FRAC_IS_ZERO)) ca(a,va),cb(b,vb);
    ac_xor sign_xor(a[15],b[15],sign_result);

    wire [21:0] product;
    ac_sig11_product mantissa(a[9:0],b[9:0],product);

    wire [4:0] es_low;
    wire es_high,unused_exp;
    wire [6:0] exponent;
    ac_add #(.W(5)) exp_sum(a[14:10],b[14:10],product[21],es_low,es_high);
    ac_add_const #(.W(7),.K(7'b1110001)) bias({1'b0,es_high,es_low},1'b0,exponent,unused_exp);

    wire [9:0] fraction;
    ac_muxv #(.W(10)) norm(product[19:10],product[20:11],product[21],fraction);
    wire exp_nz,under,eq31,over,over_pos,normal_ok;
    ac_reduce_or #(.W(6)) nz(exponent[5:0],exp_nz);
    ac_lut2 #(.T(4'b1101)) uf(exponent[6],exp_nz,under);
    ac_eq_const #(.W(5),.K(5'd31)) cmp31(exponent[4:0],eq31);
    ac_or hi(exponent[5],eq31,over_pos);
    ac_lut2 #(.T(4'b0010)) of(exponent[6],over_pos,over);
    ac_not nu(under,normal_ok);
    wire valid_product;
    ac_and3 vp(va,vb,normal_ok,valid_product);
    wire [15:0] finite_word,overflow_word;
    assign finite_word={sign_result,exponent[4:0],fraction};
    assign overflow_word={sign_result,OVERFLOW_EXP,10'd0};
    genvar i;
    generate for(i=0;i<16;i=i+1) begin:pack
        c2 u(.D00(1'b0),.D01(1'b0),.D10(finite_word[i]),.D11(overflow_word[i]),
            .A1(valid_product),.B1(1'b0),.A0(over),.B0(1'b1),.out(result[i]));
    end endgenerate
endmodule
`default_nettype wire