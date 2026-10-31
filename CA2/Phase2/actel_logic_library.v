`timescale 1ns/1ps
`default_nettype none

module ac_lut2 #(parameter [3:0] T=4'b0000)(input a,b, output y);
    c1 u(.A0(T[0]),.A1(T[1]),.SA(b),.B0(T[2]),.B1(T[3]),.SB(b),.S0(a),.S1(1'b0),.f(y));
endmodule
module ac_not(input a,output y);
    ac_lut2 #(.T(4'b0011)) u(a,1'b0,y);
endmodule
module ac_and(input a,b,output y);
    ac_lut2 #(.T(4'b1000)) u(a,b,y);
endmodule
module ac_or(input a,b,output y);
    ac_lut2 #(.T(4'b1110)) u(a,b,y);
endmodule
module ac_xor(input a,b,output y);
    ac_lut2 #(.T(4'b0110)) u(a,b,y);
endmodule
module ac_mux(input a,b,s,output y);
    c1 u(.A0(a),.A1(b),.SA(s),.B0(1'b0),.B1(1'b0),.SB(1'b0),.S0(1'b0),.S1(1'b0),.f(y));
endmodule
module ac_mux4(input a,b,c,d,input s0,s1,output y);
    c1 u(.A0(a),.A1(b),.SA(s0),.B0(c),.B1(d),.SB(s0),.S0(s1),.S1(1'b0),.f(y));
endmodule
module ac_and3(input a,b,c,output y);
    c2 u(.D00(1'b0),.D01(1'b0),.D10(1'b0),.D11(1'b1),.A1(c),.B1(1'b0),.A0(a),.B0(b),.out(y));
endmodule
module ac_or3(input a,b,c,output y);
    c2 u(.D00(1'b0),.D01(1'b1),.D10(1'b1),.D11(1'b1),.A1(a),.B1(b),.A0(c),.B0(1'b1),.out(y));
endmodule
module ac_muxv #(parameter integer W=1)(input [W-1:0] a,b,input s,output [W-1:0] y);
    genvar i;
    generate for(i=0;i<W;i=i+1) begin:g
        ac_mux u(a[i],b[i],s,y[i]);
    end endgenerate
endmodule
module ac_mask #(parameter integer W=1)(input [W-1:0] a,input en,output [W-1:0] y);
    genvar i;
    generate for(i=0;i<W;i=i+1) begin:g
        ac_and u(a[i],en,y[i]);
    end endgenerate
endmodule
module ac_reduce_or #(parameter integer W=1)(input [W-1:0] a,output y);
    generate
        if(W==1) begin:g_one assign y=a[0]; end
        else if(W==2) begin:g_two ac_or u(a[0],a[1],y); end
        else if(W==3) begin:g_three ac_or3 u(a[0],a[1],a[2],y); end
        else begin:g_tree
            localparam integer L=W/3;
            localparam integer M=(W-L)/2;
            wire lo,mid,hi;
            ac_reduce_or #(.W(L)) a0(a[L-1:0],lo);
            ac_reduce_or #(.W(M)) a1(a[L+M-1:L],mid);
            ac_reduce_or #(.W(W-L-M)) a2(a[W-1:L+M],hi);
            ac_or3 u(lo,mid,hi,y);
        end
    endgenerate
endmodule
module ac_reduce_and #(parameter integer W=1)(input [W-1:0] a,output y);
    generate
        if(W==1) begin:g_one assign y=a[0]; end
        else if(W==2) begin:g_two ac_and u(a[0],a[1],y); end
        else if(W==3) begin:g_three ac_and3 u(a[0],a[1],a[2],y); end
        else begin:g_tree
            localparam integer L=W/3;
            localparam integer M=(W-L)/2;
            wire lo,mid,hi;
            ac_reduce_and #(.W(L)) a0(a[L-1:0],lo);
            ac_reduce_and #(.W(M)) a1(a[L+M-1:L],mid);
            ac_reduce_and #(.W(W-L-M)) a2(a[W-1:L+M],hi);
            ac_and3 u(lo,mid,hi,y);
        end
    endgenerate
endmodule
module ac_fa(input a,b,ci,output s,co);
    wire p;
    ac_xor x0(a,b,p);
    ac_xor x1(p,ci,s);
    c2 cy(.D00(1'b0),.D01(1'b0),.D10(ci),.D11(1'b1),.A1(a),.B1(b),.A0(a),.B0(b),.out(co));
endmodule
module ac_ha(input a,b,output s,co);
    ac_xor x(a,b,s);
    ac_and c(a,b,co);
endmodule
module ac_add #(parameter integer W=1)(input [W-1:0] a,b,input ci,output [W-1:0] s,output co);
    wire [W:0] c;
    assign c[0]=ci;
    assign co=c[W];
    genvar i;
    generate for(i=0;i<W;i=i+1) begin:g
        ac_fa u(a[i],b[i],c[i],s[i],c[i+1]);
    end endgenerate
endmodule
module ac_add_const #(parameter integer W=1,parameter [W-1:0] K=0)(input [W-1:0] a,input ci,output [W-1:0] s,output co);
    wire [W:0] c;
    assign c[0]=ci;
    assign co=c[W];
    genvar i;
    generate for(i=0;i<W;i=i+1) begin:g
        if(K[i]) begin:g_one
            ac_lut2 #(.T(4'b1001)) x(a[i],c[i],s[i]);
            ac_or carry(a[i],c[i],c[i+1]);
        end else begin:g_zero
            ac_ha u(a[i],c[i],s[i],c[i+1]);
        end
    end endgenerate
endmodule
module ac_ge #(parameter integer W=1)(input [W-1:0] a,b,output ge);
    wire [W:0] c;
    assign c[0]=1'b1;
    assign ge=c[W];
    genvar i;
    generate for(i=0;i<W;i=i+1) begin:g
        c2 u(.D00(c[i]),.D01(1'b0),.D10(1'b1),.D11(c[i]),.A1(a[i]),.B1(1'b0),.A0(b[i]),.B0(1'b1),.out(c[i+1]));
    end endgenerate
endmodule
module ac_eq_const #(parameter integer W=1,parameter [W-1:0] K=0)(input [W-1:0] a,output eq);
    wire [W-1:0] match;
    genvar i;
    generate for(i=0;i<W;i=i+1) begin:g
        if(K[i]) begin:g_one assign match[i]=a[i]; end
        else begin:g_zero ac_not u(a[i],match[i]); end
    end endgenerate
    ac_reduce_and #(.W(W)) r(match,eq);
endmodule
module ac_dffe(input clk,rst,en,d,output q);
    s2 u(.D00(q),.D01(d),.D10(1'b0),.D11(1'b0),.A1(rst),.B1(1'b0),.A0(en),.B0(1'b1),.clr(1'b0),.clk(clk),.out(q));
endmodule
module ac_store(input clk,en,d,output q);
    s1 u(.D00(q),.D01(1'b0),.D10(d),.D11(1'b0),.A1(en),.B1(1'b0),.A0(1'b0),.clr(1'b0),.clk(clk),.out(q));
endmodule

module ac_fp_valid #(parameter integer ZERO_FRAC_IS_ZERO=1)(input [15:0] a,output valid);
    wire exp_nz,frac_nz;
    ac_reduce_or #(.W(5)) e(a[14:10],exp_nz);
    generate if(ZERO_FRAC_IS_ZERO) begin:g_literal
        ac_reduce_or #(.W(10)) f(a[9:0],frac_nz);
        ac_and u(exp_nz,frac_nz,valid);
    end else begin:g_hidden_one
        assign frac_nz=1'b1;
        assign valid=exp_nz;
    end endgenerate
endmodule

module ac_rshift_jam13(input [12:0] a,input [4:0] sh,output [12:0] y);
    wire [12:0] first,second;
    wire [3:0] lowjam;
    wire [3:0] midjam;
    assign lowjam[0]=a[0]; assign lowjam[1]=1'b0; assign lowjam[2]=a[2];
    ac_or l3(a[3],a[2],lowjam[3]);
    ac_mux4 ls(lowjam[0],lowjam[1],lowjam[2],lowjam[3],sh[0],sh[1],first[0]);
    assign midjam[0]=first[0];
    ac_reduce_or #(.W(5)) m1(first[4:0],midjam[1]);
    wire midpart;
    ac_reduce_or #(.W(4)) mp(first[8:5],midpart);
    ac_or m2(midjam[1],midpart,midjam[2]);
    assign midjam[3]=1'b1;
    ac_mux4 ms(midjam[0],midjam[1],midjam[2],midjam[3],sh[2],sh[3],second[0]);
    genvar i,j;
    generate for(i=1;i<13;i=i+1) begin:bits
        wire [3:0] lo,hi;
        for(j=0;j<4;j=j+1) begin:choices
            if(i+j<13) begin:l assign lo[j]=a[i+j];end else begin:lz assign lo[j]=1'b0;end
            if(i+4*j<13) begin:h assign hi[j]=first[i+4*j];end else begin:hz assign hi[j]=1'b0;end
        end
        ac_mux4 l(lo[0],lo[1],lo[2],lo[3],sh[0],sh[1],first[i]);
        ac_mux4 h(hi[0],hi[1],hi[2],hi[3],sh[2],sh[3],second[i]);
        ac_lut2 #(.T(4'b0100)) clamp(second[i],sh[4],y[i]);
    end endgenerate
    ac_or last(second[0],sh[4],y[0]);
endmodule

module ac_normalize13(input [12:0] a,output [12:0] y,output [3:0] shift,output nonzero);
    wire [12:0] mid; wire nz8,nz4hi,nz4lo,nz4,nz2,nz1;
    ac_reduce_or #(.W(8)) r8(a[12:5],nz8); ac_not n8(nz8,shift[3]);
    ac_reduce_or #(.W(4)) r4h(a[12:9],nz4hi); ac_reduce_or #(.W(4)) r4l(a[4:1],nz4lo);
    ac_mux m4(nz4hi,nz4lo,shift[3],nz4); ac_not n4(nz4,shift[2]);
    genvar i,j;
    generate for(i=0;i<13;i=i+1) begin:first_bits
        wire [3:0] choice;
        for(j=0;j<4;j=j+1) begin:c
            if(i>=4*j) begin:v assign choice[j]=a[i-4*j];end else begin:z assign choice[j]=1'b0;end
        end
        ac_mux4 u(choice[0],choice[1],choice[2],choice[3],shift[2],shift[3],mid[i]);
    end endgenerate
    ac_reduce_or #(.W(4)) nzero(mid[12:9],nonzero);
    ac_or r2(mid[12],mid[11],nz2); ac_not n2(nz2,shift[1]);
    ac_mux m1(mid[12],mid[10],shift[1],nz1); ac_not n1(nz1,shift[0]);
    assign y[12]=1'b1; assign y[1:0]=2'b00;
    generate for(i=2;i<12;i=i+1) begin:last_bits
        wire [3:0] choice;
        for(j=0;j<4;j=j+1) begin:c
            if(i>=j) begin:v assign choice[j]=mid[i-j];end else begin:z assign choice[j]=1'b0;end
        end
        ac_mux4 u(choice[0],choice[1],choice[2],choice[3],shift[0],shift[1],y[i]);
    end endgenerate
endmodule
`default_nettype wire