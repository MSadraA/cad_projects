`timescale 1ns/1ps
`default_nettype none

module Zero_detector (input wire [15:0] in, output wire valid);
    wire or_f9_to_f6, or_f5_to_f2, or_f9_to_f0, or_e4_to_e1;
    c2 u_c2_1 (.D00(in[6]), .D01(1'b1), .D10(1'b1), .D11(1'b1), .A1(in[9]), .B1(in[8]), .A0(in[7]), .B0(in[7]), .out(or_f9_to_f6));
    c2 u_c2_2 (.D00(in[2]), .D01(1'b1), .D10(1'b1), .D11(1'b1), .A1(in[5]), .B1(in[4]), .A0(in[3]), .B0(in[3]), .out(or_f5_to_f2));
    c2 u_c2_3 (.D00(in[0]), .D01(1'b1), .D10(1'b1), .D11(1'b1), .A1(or_f9_to_f6), .B1(or_f5_to_f2), .A0(in[1]), .B0(in[1]), .out(or_f9_to_f0));
    c2 u_c2_4 (.D00(in[11]), .D01(1'b1), .D10(1'b1), .D11(1'b1), .A1(in[14]), .B1(in[13]), .A0(in[12]), .B0(in[12]), .out(or_e4_to_e1));
    c2 u_c2_5 (.D00(1'b0), .D01(or_f9_to_f0), .D10(or_f9_to_f0), .D11(or_f9_to_f0), .A1(1'b0), .B1(or_e4_to_e1), .A0(in[10]), .B0(in[10]), .out(valid));
endmodule

module Comparator_15_bit (input wire [14:0] a, input wire [14:0] b, output wire out);
    wire [14:0] c;
    c1 u_comp_0 (.A0(b[0]), .A1(1'b0), .SA(a[0]), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(c[0]));
    genvar i;
    generate for (i = 1; i < 15; i = i + 1) begin : gen_comp
        c1 u_comp_i (.A0(c[i-1]), .A1(1'b1), .SA(b[i]), .B0(1'b0), .B1(c[i-1]), .SB(b[i]), .S0(a[i]), .S1(1'b0), .f(c[i]));
    end endgenerate
    assign out = c[14];
endmodule

module Sub_5_bit (input wire [4:0] a, input wire [4:0] b, output wire [4:0] d, output wire Co);
    wire [4:0] c;
    full_adder_b_invert u_sub0 (.a(a[0]), .b(b[0]), .c(1'b1), .Sum(d[0]), .Co(c[0]));
    full_adder_b_invert u_sub1 (.a(a[1]), .b(b[1]), .c(c[0]), .Sum(d[1]), .Co(c[1]));
    full_adder_b_invert u_sub2 (.a(a[2]), .b(b[2]), .c(c[1]), .Sum(d[2]), .Co(c[2]));
    full_adder_b_invert u_sub3 (.a(a[3]), .b(b[3]), .c(c[2]), .Sum(d[3]), .Co(c[3]));
    full_adder_b_invert u_sub4 (.a(a[4]), .b(b[4]), .c(c[3]), .Sum(d[4]), .Co(c[4]));
    assign Co = c[4];
endmodule

module Sub_exp_pe_5_bit (input wire [4:0] a, input wire [3:0] b, output wire [4:0] d, output wire Co);
    wire [3:0] c;
    full_adder_b_invert u_sub0 (.a(a[0]), .b(b[0]), .c(1'b1), .Sum(d[0]), .Co(c[0]));
    full_adder_b_invert u_sub1 (.a(a[1]), .b(b[1]), .c(c[0]), .Sum(d[1]), .Co(c[1]));
    full_adder_b_invert u_sub2 (.a(a[2]), .b(b[2]), .c(c[1]), .Sum(d[2]), .Co(c[2]));
    full_adder_b_invert u_sub3 (.a(a[3]), .b(b[3]), .c(c[2]), .Sum(d[3]), .Co(c[3]));
    c2 u_diff4 (.D00(1'b1), .D01(1'b0), .D10(1'b0), .D11(1'b1), .A1(a[4]), .B1(a[4]), .A0(c[3]), .B0(c[3]), .out(d[4]));
    c1 u_carry4 (.A0(a[4]), .A1(1'b1), .SA(c[3]), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(Co));
endmodule

module Adder_11_bit (input wire [10:0] a, input wire [10:0] b, input wire Cin, output wire [10:0] out, output wire Co);
    wire [10:0] c;
    full_adder u_fa0 (.a(a[0]), .b(b[0]), .c(Cin), .Sum(out[0]), .Co(c[0]));
    genvar i;
    generate for (i = 1; i < 11; i = i + 1) begin : gen_fa11
        full_adder u_fa (.a(a[i]), .b(b[i]), .c(c[i-1]), .Sum(out[i]), .Co(c[i]));
    end endgenerate
    assign Co = c[10];
endmodule

module Adder_5_bit (input wire [4:0] a, input wire [4:0] b, input wire Cin, output wire [4:0] out, output wire Co);
    wire [4:0] c;
    full_adder u_fa0 (.a(a[0]), .b(b[0]), .c(Cin),  .Sum(out[0]), .Co(c[0]));
    full_adder u_fa1 (.a(a[1]), .b(b[1]), .c(c[0]), .Sum(out[1]), .Co(c[1]));
    full_adder u_fa2 (.a(a[2]), .b(b[2]), .c(c[1]), .Sum(out[2]), .Co(c[2]));
    full_adder u_fa3 (.a(a[3]), .b(b[3]), .c(c[2]), .Sum(out[3]), .Co(c[3]));
    full_adder u_fa4 (.a(a[4]), .b(b[4]), .c(c[3]), .Sum(out[4]), .Co(c[4]));
    assign Co = c[4];
endmodule

module Shift_right_11_bit (input wire [10:0] in, input wire [4:0] d, output wire [10:0] out);
    wire [10:0] s0, s1, s2, s3;
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : st0
            MUX_2_to_1_1bit u_m (.i0(in[i]), .i1(in[i+1]), .Sel(d[0]), .out(s0[i]));
        end
        MUX_2_to_1_1bit u_m0_10 (.i0(in[10]), .i1(1'b0), .Sel(d[0]), .out(s0[10]));
        for (i = 0; i < 9; i = i + 1) begin : st1
            MUX_2_to_1_1bit u_m (.i0(s0[i]), .i1(s0[i+2]), .Sel(d[1]), .out(s1[i]));
        end
        for (i = 9; i < 11; i = i + 1) begin : st1_z
            MUX_2_to_1_1bit u_m (.i0(s0[i]), .i1(1'b0), .Sel(d[1]), .out(s1[i]));
        end
        for (i = 0; i < 7; i = i + 1) begin : st2
            MUX_2_to_1_1bit u_m (.i0(s1[i]), .i1(s1[i+4]), .Sel(d[2]), .out(s2[i]));
        end
        for (i = 7; i < 11; i = i + 1) begin : st2_z
            MUX_2_to_1_1bit u_m (.i0(s1[i]), .i1(1'b0), .Sel(d[2]), .out(s2[i]));
        end
        for (i = 0; i < 3; i = i + 1) begin : st3
            MUX_2_to_1_1bit u_m (.i0(s2[i]), .i1(s2[i+8]), .Sel(d[3]), .out(s3[i]));
        end
        for (i = 3; i < 11; i = i + 1) begin : st3_z
            MUX_2_to_1_1bit u_m (.i0(s2[i]), .i1(1'b0), .Sel(d[3]), .out(s3[i]));
        end
        for (i = 0; i < 11; i = i + 1) begin : st4_z
            MUX_2_to_1_1bit u_m (.i0(s3[i]), .i1(1'b0), .Sel(d[4]), .out(out[i]));
        end
    endgenerate
endmodule

module Shift_left_10_bit (input wire [9:0] in, input wire [3:0] d, output wire [9:0] out);
    wire [9:0] s0, s1, s2;
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : sl0
            if (i == 0) MUX_2_to_1_1bit u_m (.i0(in[i]), .i1(1'b0), .Sel(d[0]), .out(s0[i]));
            else MUX_2_to_1_1bit u_m (.i0(in[i]), .i1(in[i-1]), .Sel(d[0]), .out(s0[i]));
        end
        for (i = 0; i < 10; i = i + 1) begin : sl1
            if (i < 2) MUX_2_to_1_1bit u_m (.i0(s0[i]), .i1(1'b0), .Sel(d[1]), .out(s1[i]));
            else MUX_2_to_1_1bit u_m (.i0(s0[i]), .i1(s0[i-2]), .Sel(d[1]), .out(s1[i]));
        end
        for (i = 0; i < 10; i = i + 1) begin : sl2
            if (i < 4) MUX_2_to_1_1bit u_m (.i0(s1[i]), .i1(1'b0), .Sel(d[2]), .out(s2[i]));
            else MUX_2_to_1_1bit u_m (.i0(s1[i]), .i1(s1[i-4]), .Sel(d[2]), .out(s2[i]));
        end
        for (i = 0; i < 10; i = i + 1) begin : sl3
            if (i < 8) MUX_2_to_1_1bit u_m (.i0(s2[i]), .i1(1'b0), .Sel(d[3]), .out(out[i]));
            else MUX_2_to_1_1bit u_m (.i0(s2[i]), .i1(s2[i-8]), .Sel(d[3]), .out(out[i]));
        end
    endgenerate
endmodule

module Increment_5_bit (input wire [4:0] a, input wire Cin, output wire [4:0] out);
    wire [3:0] carry;
    a_xor_b u_xor0 (.a(a[0]), .b(Cin), .out(out[0]));
    c2 u_and0 (.D00(1'b0), .D01(1'b0), .D10(1'b0), .D11(1'b1), .A1(a[0]), .B1(a[0]), .A0(Cin), .B0(Cin), .out(carry[0]));
    genvar j;
    generate for (j = 1; j < 5; j = j + 1) begin : gen_increment
        a_xor_b u_xor (.a(a[j]), .b(carry[j-1]), .out(out[j]));
        if (j < 4) c2 u_and (.D00(1'b0), .D01(1'b0), .D10(1'b0), .D11(1'b1), .A1(a[j]), .B1(a[j]), .A0(carry[j-1]), .B0(carry[j-1]), .out(carry[j]));
    end endgenerate
endmodule

module Priority_encoder (input wire [10:0] in, output wire [3:0] out, output wire valid_any);
    wire v0, p0, v1, p1, v2, p2, v3, p3, v4, p4;
    c1 u_or_v0 (.A0(in[9]), .A1(1'b1), .SA(in[10]), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(v0));
    Not u_not_p0 (.a(in[10]), .out(p0));
    c1 u_or_v1 (.A0(in[7]), .A1(1'b1), .SA(in[8]),  .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(v1));
    Not u_not_p1 (.a(in[8]), .out(p1));
    c1 u_or_v2 (.A0(in[5]), .A1(1'b1), .SA(in[6]),  .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(v2));
    Not u_not_p2 (.a(in[6]), .out(p2));
    c1 u_or_v3 (.A0(in[3]), .A1(1'b1), .SA(in[4]),  .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(v3));
    Not u_not_p3 (.a(in[4]), .out(p3));
    c1 u_or_v4 (.A0(in[1]), .A1(1'b1), .SA(in[2]),  .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(v4));
    Not u_not_p4 (.a(in[2]), .out(p4));

    wire v_q0, v_q1, v_q2;
    wire [1:0] p_q0, p_q1, p_q2;
    c1 u_or_vq0 (.A0(v1), .A1(1'b1), .SA(v0), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(v_q0));
    Not u_not_pq0_1 (.a(v0), .out(p_q0[1]));
    MUX_2_to_1_1bit u_mux_pq0_0 (.i0(p1), .i1(p0), .Sel(v0), .out(p_q0[0]));
    c1 u_or_vq1 (.A0(v3), .A1(1'b1), .SA(v2), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(v_q1));
    Not u_not_pq1_1 (.a(v2), .out(p_q1[1]));
    MUX_2_to_1_1bit u_mux_pq1_0 (.i0(p3), .i1(p2), .Sel(v2), .out(p_q1[0]));
    c1 u_or_vq2 (.A0(in[0]), .A1(1'b1), .SA(v4), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(v_q2));
    Not u_not_pq2_1 (.a(v4), .out(p_q2[1]));
    MUX_2_to_1_1bit u_mux_pq2_0 (.i0(1'b0), .i1(p4), .Sel(v4), .out(p_q2[0]));

    wire v_o0;
    wire [2:0] p_o0;
    c1 u_or_vo0 (.A0(v_q1), .A1(1'b1), .SA(v_q0), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(v_o0));
    Not u_not_po0_2 (.a(v_q0), .out(p_o0[2]));
    MUX_2_to_1_1bit u_mux_po0_1 (.i0(p_q1[1]), .i1(p_q0[1]), .Sel(v_q0), .out(p_o0[1]));
    MUX_2_to_1_1bit u_mux_po0_0 (.i0(p_q1[0]), .i1(p_q0[0]), .Sel(v_q0), .out(p_o0[0]));

    c1 u_or_vall (.A0(v_q2), .A1(1'b1), .SA(v_o0), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(valid_any));
    Not u_not_out3 (.a(v_o0), .out(out[3]));
    MUX_2_to_1_1bit u_mux_out2 (.i0(1'b0), .i1(p_o0[2]), .Sel(v_o0), .out(out[2]));
    MUX_2_to_1_1bit u_mux_out1 (.i0(p_q2[1]), .i1(p_o0[1]), .Sel(v_o0), .out(out[1]));
    MUX_2_to_1_1bit u_mux_out0 (.i0(p_q2[0]), .i1(p_o0[0]), .Sel(v_o0), .out(out[0]));
endmodule
`default_nettype wire