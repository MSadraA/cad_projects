`timescale 1ns/1ps
`default_nettype none
module fcnn_fp16_multiplier #(
    parameter integer ZERO_FRAC_IS_ZERO=1,
    parameter [4:0] OVERFLOW_EXP=5'd31
)(input [15:0] a,b,output [15:0] result);
    // 1. Explicit course zero policy; exp=0 includes every subnormal.
    wire va,vb,sign_result;
    ac_fp_valid #(.ZERO_FRAC_IS_ZERO(ZERO_FRAC_IS_ZERO)) ca(a,va),cb(b,vb);
    ac_xor sign_xor(a[15],b[15],sign_result);

    // 2. Exact 22-bit product. Constant leading ones eliminate 21 AND cells.
    wire [21:0] product;
    ac_sig11_product mantissa(a[9:0],b[9:0],product);

    // 3. Signed exponent: ea+eb+normalization-15, in seven bits.
    wire [4:0] es_low;
    wire es_high,unused_exp;
    wire [6:0] exponent;
    ac_add #(.W(5)) exp_sum(a[14:10],b[14:10],product[21],es_low,es_high);
    ac_add_const #(.W(7),.K(7'b1110001)) bias({1'b0,es_high,es_low},1'b0,exponent,unused_exp);

    // 4. One normalization mux, then truncation (never RNE).
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
