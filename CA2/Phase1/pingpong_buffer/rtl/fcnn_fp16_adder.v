`timescale 1ns/1ps
`default_nettype none
module fcnn_fp16_adder #(
    parameter integer ZERO_FRAC_IS_ZERO=1,
    parameter [4:0] OVERFLOW_EXP=5'd31
)(input [15:0] a,b,output [15:0] result);
    // 1. Classification and magnitude ordering, without modifying the CA1 ports.
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

    // 2. Align the smaller 1.f significand, retaining two low bits and jam.
    wire [12:0] aligned,small_xor,sum,norm;
    wire sum_carry,add_carry;
    ac_rshift_jam13 align({1'b1,small_word[9:0],2'b00},diff,aligned);
    // The large significand has two low zeros and a constant high one.
    // Specialize those three slices rather than instantiating unused full adders.
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

    // 3. Normalize and adjust the exponent in a signed six-bit intermediate.
    wire [3:0] lshift;
    wire [5:0] final_exp,neg_shift;
    wire unused_e;
    wire raw_low_nz;
    ac_normalize13 normalizer(sum,norm,lshift,raw_low_nz);
    generate for(i=0;i<4;i=i+1) begin:delta_bits
        // Carry implies no cancellation: choose delta=+1, otherwise -lshift.
        ac_lut2 #(.T(4'b0001)) n(lshift[i],add_carry,neg_shift[i]);
    end endgenerate
    ac_not nh(add_carry,neg_shift[4]);
    assign neg_shift[5]=neg_shift[4];
    ac_add #(.W(6)) adjust({1'b0,big_word[14:10]},neg_shift,1'b1,final_exp,unused_e);
    wire [9:0] final_fraction;
    ac_muxv #(.W(10)) carry_fraction(norm[11:2],sum[12:3],add_carry,final_fraction);

    // 4. Truncate, flush underflow, and apply explicitly documented zero policy.
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
`default_nettype wire
