`timescale 1ns/1ps
`default_nettype none
// Parameters describe constant truth tables; no run-time operator is inferred.
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
// a >= b iff the final carry of a + ~b + 1 is one.
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
// DFF with enable; asynchronous primitive reset is tied low.
// Synchronous rst is a mux select INSIDE the same s2 cell, so no external reset gate.
module ac_dffe(input clk,rst,en,d,output q);
    s2 u(.D00(q),.D01(d),.D10(1'b0),.D11(1'b0),.A1(rst),.B1(1'b0),.A0(en),.B0(1'b1),.clr(1'b0),.clk(clk),.out(q));
endmodule
// Payload is not reset, exactly as in CA1; it is never consumed while invalid.
module ac_store(input clk,en,d,output q);
    s1 u(.D00(q),.D01(1'b0),.D10(d),.D11(1'b0),.A1(en),.B1(1'b0),.A0(1'b0),.clr(1'b0),.clk(clk),.out(q));
endmodule
`default_nettype wire
