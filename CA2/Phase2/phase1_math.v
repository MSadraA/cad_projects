`timescale 1ns/1ps
`default_nettype none

module bit_multiplier (input xi, yi, ci, pi, output xo, yo, co, po);
    wire xy, xypi;
    assign xo = xi;
    assign yo = yi;
    c1 u_partial_product (.A0(1'b0), .A1(1'b0), .SA(1'b0), .B0(1'b0), .B1(yi), .SB(xi), .S0(1'b1), .S1(1'b0), .f(xy));
    a_xor_b u_xor_partial_pi (.a(xy), .b(pi), .out(xypi));
    a_xor_b u_xor_sum (.a(xypi), .b(ci), .out(po));
    c1 u_carry_mux (.A0(xy), .A1(ci), .SA(xypi), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(co));
endmodule

module array_mul_11bit (input wire [10:0] a, input wire [10:0] b, output wire [21:0] mul);
    wire [11:0][11:0] xv, yv, pv, cv;
    genvar i, j;
    generate for (i = 0; i < 11; i = i + 1) begin : row
        for (j = 0; j < 11; j = j + 1) begin : column
            if ((i == 0) && (j == 0)) begin : corner_cell
                wire xy;
                assign xv[i][j+1] = xv[i][j]; assign yv[i+1][j] = yv[i][j];
                c1 u_partial_product (.A0(1'b0), .A1(1'b0), .SA(1'b0), .B0(1'b0), .B1(yv[i][j]), .SB(xv[i][j]), .S0(1'b1), .S1(1'b0), .f(xy));
                assign pv[i+1][j] = xy; assign cv[i][j+1] = 1'b0;
            end else if (i == 0) begin : top_row_cell
                assign xv[i][j+1] = xv[i][j]; assign yv[i+1][j] = yv[i][j];
                c2 u_sum (.D00(1'b0), .D01(1'b1), .D10(1'b1), .D11(1'b0), .A1(cv[i][j]), .B1(1'b0), .A0(xv[i][j]), .B0(yv[i][j]), .out(pv[i+1][j]));
                c1 u_carry (.A0(1'b0), .A1(1'b0), .SA(1'b0), .B0(1'b0), .B1(yv[i][j]), .SB(xv[i][j]), .S0(1'b0), .S1(cv[i][j]), .f(cv[i][j+1]));
            end else if (j == 0) begin : left_column_cell
                assign xv[i][j+1] = xv[i][j]; assign yv[i+1][j] = yv[i][j];
                c2 u_sum (.D00(1'b0), .D01(1'b1), .D10(1'b1), .D11(1'b0), .A1(pv[i][j+1]), .B1(1'b0), .A0(xv[i][j]), .B0(yv[i][j]), .out(pv[i+1][j]));
                c1 u_carry (.A0(1'b0), .A1(1'b0), .SA(1'b0), .B0(1'b0), .B1(yv[i][j]), .SB(xv[i][j]), .S0(1'b0), .S1(pv[i][j+1]), .f(cv[i][j+1]));
            end else if ((i == 10) && (j == 10)) begin : fixed_one_corner
                assign xv[i][j+1] = xv[i][j]; assign yv[i+1][j] = yv[i][j];
                wire xypi; a_xor_b u_xor_pi (.a(1'b1), .b(pv[i][j+1]), .out(xypi));
                a_xor_b u_sum (.a(xypi), .b(cv[i][j]), .out(pv[i+1][j]));
                c1 u_carry (.A0(1'b1), .A1(cv[i][j]), .SA(xypi), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(cv[i][j+1]));
            end else if (i == 10) begin : fixed_a_msb_row
                assign xv[i][j+1] = xv[i][j]; assign yv[i+1][j] = yv[i][j];
                wire xypi; a_xor_b u_xor_pi (.a(yv[i][j]), .b(pv[i][j+1]), .out(xypi));
                a_xor_b u_sum (.a(xypi), .b(cv[i][j]), .out(pv[i+1][j]));
                c1 u_carry (.A0(yv[i][j]), .A1(cv[i][j]), .SA(xypi), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(cv[i][j+1]));
            end else if (j == 10) begin : fixed_b_msb_column
                assign xv[i][j+1] = xv[i][j]; assign yv[i+1][j] = yv[i][j];
                wire xypi; a_xor_b u_xor_pi (.a(xv[i][j]), .b(pv[i][j+1]), .out(xypi));
                a_xor_b u_sum (.a(xypi), .b(cv[i][j]), .out(pv[i+1][j]));
                c1 u_carry (.A0(xv[i][j]), .A1(cv[i][j]), .SA(xypi), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(cv[i][j+1]));
            end else begin : inner_cell
                bit_multiplier inst(.xi(xv[i][j]), .yi(yv[i][j]), .pi(pv[i][j+1]), .ci(cv[i][j]), .xo(xv[i][j+1]), .yo(yv[i+1][j]), .po(pv[i+1][j]), .co(cv[i][j+1]));
            end
        end
    end endgenerate
    generate for (i = 0; i < 11; i = i + 1) begin : init_and_output
        assign xv[i][0] = a[i]; assign yv[0][i] = b[i]; assign cv[i][0] = 1'b0;
        assign pv[0][i + 1] = 1'b0; assign pv[i + 1][11] = cv[i][11];
        assign mul[i] = pv[i + 1][0]; assign mul[i + 11] = pv[11][i + 1];
    end endgenerate
endmodule

module fp16_multiplier_core (input wire [15:0] a, input wire [15:0] b, output wire [15:0] out);
    wire a_sign = a[15]; wire [4:0] a_exp = a[14:10]; wire [9:0] a_frac = a[9:0];
    wire b_sign = b[15]; wire [4:0] b_exp = b[14:10]; wire [9:0] b_frac = b[9:0];
    wire a_valid, b_valid;
    Zero_detector u_a_zd (.in(a), .valid(a_valid)); Zero_detector u_b_zd (.in(b), .valid(b_valid));
    wire a_is_zero, b_is_zero, any_input_zero;
    Not u_not_a_valid (.a(a_valid), .out(a_is_zero)); Not u_not_b_valid (.a(b_valid), .out(b_is_zero));
    Or_2bit u_any_z (.a(a_is_zero), .b(b_is_zero), .y(any_input_zero));
    wire final_sign; a_xor_b u_sign_xor (.a(a_sign), .b(b_sign), .out(final_sign));
    wire [10:0] a_mant_11 = {1'b1, a_frac}; wire [10:0] b_mant_11 = {1'b1, b_frac};
    wire [21:0] mant_product;
    array_mul_11bit u_array_mul (.a(a_mant_11), .b(b_mant_11), .mul(mant_product));
    wire norm_shift = mant_product[21];
    wire [5:0] exp_sum1; wire c1_0, c1_1, c1_2, c1_3, c1_4, c1_5;
    full_adder u_fa1_0 (.a(a_exp[0]), .b(b_exp[0]), .c(1'b0), .Sum(exp_sum1[0]), .Co(c1_0));
    full_adder u_fa1_1 (.a(a_exp[1]), .b(b_exp[1]), .c(c1_0), .Sum(exp_sum1[1]), .Co(c1_1));
    full_adder u_fa1_2 (.a(a_exp[2]), .b(b_exp[2]), .c(c1_1), .Sum(exp_sum1[2]), .Co(c1_2));
    full_adder u_fa1_3 (.a(a_exp[3]), .b(b_exp[3]), .c(c1_2), .Sum(exp_sum1[3]), .Co(c1_3));
    full_adder u_fa1_4 (.a(a_exp[4]), .b(b_exp[4]), .c(c1_3), .Sum(exp_sum1[4]), .Co(c1_4));
    assign exp_sum1[5] = c1_4; assign c1_5 = 1'b0;
    wire [5:0] exp_norm; wire c2_0, c2_1, c2_2, c2_3, c2_4;
    a_xor_b u_norm_sum0 (.a(exp_sum1[0]), .b(norm_shift), .out(exp_norm[0])); And_2bit u_norm_carry0 (.a(exp_sum1[0]), .b(norm_shift), .y(c2_0));
    a_xor_b u_norm_sum1 (.a(exp_sum1[1]), .b(c2_0), .out(exp_norm[1])); And_2bit u_norm_carry1 (.a(exp_sum1[1]), .b(c2_0), .y(c2_1));
    a_xor_b u_norm_sum2 (.a(exp_sum1[2]), .b(c2_1), .out(exp_norm[2])); And_2bit u_norm_carry2 (.a(exp_sum1[2]), .b(c2_1), .y(c2_2));
    a_xor_b u_norm_sum3 (.a(exp_sum1[3]), .b(c2_2), .out(exp_norm[3])); And_2bit u_norm_carry3 (.a(exp_sum1[3]), .b(c2_2), .y(c2_3));
    a_xor_b u_norm_sum4 (.a(exp_sum1[4]), .b(c2_3), .out(exp_norm[4])); And_2bit u_norm_carry4 (.a(exp_sum1[4]), .b(c2_3), .y(c2_4));
    a_xor_b u_norm_sum5 (.a(exp_sum1[5]), .b(c2_4), .out(exp_norm[5]));
    wire [5:0] final_e; wire c3_1, c3_2, c3_3, c3_4, final_co;
    Not u_s3_0_not (.a(exp_norm[0]), .out(final_e[0])); wire c3_0 = exp_norm[0];
    half_adder u_s3_1_ha (.a(exp_norm[1]), .b(c3_0), .Sum(final_e[1]), .Co(c3_1));
    half_adder u_s3_2_ha (.a(exp_norm[2]), .b(c3_1), .Sum(final_e[2]), .Co(c3_2));
    half_adder u_s3_3_ha (.a(exp_norm[3]), .b(c3_2), .Sum(final_e[3]), .Co(c3_3));
    c2 u_s3_4_xnor (.D00(1'b1), .D01(1'b0), .D10(1'b0), .D11(1'b1), .A1(exp_norm[4]), .B1(exp_norm[4]), .A0(c3_3), .B0(c3_3), .out(final_e[4]));
    Or_2bit u_s3_4_carry (.a(exp_norm[4]), .b(c3_3), .y(c3_4));
    c2 u_s3_5_xnor (.D00(1'b1), .D01(1'b0), .D10(1'b0), .D11(1'b1), .A1(exp_norm[5]), .B1(exp_norm[5]), .A0(c3_4), .B0(c3_4), .out(final_e[5]));
    Or_2bit u_s3_5_carry (.a(exp_norm[5]), .b(c3_4), .y(final_co));
    wire not_final_co; Not u_not_fco (.a(final_co), .out(not_final_co));
    wire e_or1, e_or2, e_or3, e_nz;
    Or_2bit u_ez1(.a(final_e[0]), .b(final_e[1]), .y(e_or1)); Or_2bit u_ez2(.a(final_e[2]), .b(final_e[3]), .y(e_or2));
    Or_2bit u_ez3(.a(e_or1), .b(e_or2), .y(e_or3)); Or_2bit u_ez4(.a(e_or3), .b(final_e[4]), .y(e_nz));
    wire e_is_0; Not u_ez_not(.a(e_nz), .out(e_is_0));
    wire underflow; Or_2bit u_underflow_or (.a(not_final_co), .b(e_is_0), .y(underflow));
    wire a1, a2, a3, e_is_31;
    And_2bit u_a1(.a(final_e[0]), .b(final_e[1]), .y(a1)); And_2bit u_a2(.a(final_e[2]), .b(final_e[3]), .y(a2));
    And_2bit u_a3(.a(a1), .b(a2), .y(a3)); And_2bit u_a4(.a(a3), .b(final_e[4]), .y(e_is_31));
    wire exp_over_thresh, overflow;
    Or_2bit u_or_thresh (.a(final_e[5]), .b(e_is_31), .y(exp_over_thresh));
    And_2bit u_and_over (.a(final_co), .b(exp_over_thresh), .y(overflow));
    wire force_zero; Or_2bit u_force_z_or (.a(underflow), .b(any_input_zero), .y(force_zero));
    wire zero_frac; Or_2bit u_zero_frac (.a(overflow), .b(force_zero), .y(zero_frac));
    genvar k;
    generate
        for (k = 0; k < 10; k = k + 1) begin : gen_fraction_out
            c2 u_out_bit (.D00(mant_product[k+10]), .D01(mant_product[k+11]), .D10(1'b0), .D11(1'b0), .A1(zero_frac), .B1(1'b0), .A0(norm_shift), .B0(1'b1), .out(out[k]));
        end
        for (k = 0; k < 5; k = k + 1) begin : gen_exponent_out
            c1 u_out_bit (.A0(final_e[k]), .A1(1'b0), .SA(force_zero), .B0(1'b1), .B1(1'b0), .SB(force_zero), .S0(overflow), .S1(1'b0), .f(out[k+10]));
        end
    endgenerate
    c1 u_sign_out (.A0(final_sign), .A1(1'b0), .SA(force_zero), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(out[15]));
endmodule

module Data_path (input wire [15:0] a, input wire [15:0] b, output wire [15:0] out);
    wire A_valid_raw, B_valid_raw;
    Zero_detector u_zd_a (.in(a), .valid(A_valid_raw)); Zero_detector u_zd_b (.in(b), .valid(B_valid_raw));
    wire comp_raw; wire comp_out; wire [15:0] A_num, B_num;
    Comparator_15_bit u_comp (.a(a[14:0]), .b(b[14:0]), .out(comp_raw));
    c1 u_comp_valid (.A0(1'b0), .A1(1'b0), .SA(1'b0), .B0(1'b1), .B1(comp_raw), .SB(A_valid_raw), .S0(B_valid_raw), .S1(1'b0), .f(comp_out));
    genvar mux_i;
    generate for (mux_i = 0; mux_i < 16; mux_i = mux_i + 1) begin : gen_valid_swap
        c1 u_mux_A_num (.A0(1'b0), .A1(a[mux_i]), .SA(A_valid_raw), .B0(1'b0), .B1(b[mux_i]), .SB(B_valid_raw), .S0(comp_out), .S1(1'b0), .f(A_num[mux_i]));
        c1 u_mux_B_num (.A0(1'b0), .A1(b[mux_i]), .SA(B_valid_raw), .B0(1'b0), .B1(a[mux_i]), .SB(A_valid_raw), .S0(comp_out), .S1(1'b0), .f(B_num[mux_i]));
    end endgenerate
    wire Avalid, Bvalid;
    MUX_2_to_1_1bit u_mux_avalid (.i0(A_valid_raw), .i1(B_valid_raw), .Sel(comp_out), .out(Avalid));
    MUX_2_to_1_1bit u_mux_bvalid (.i0(B_valid_raw), .i1(A_valid_raw), .Sel(comp_out), .out(Bvalid));
    wire Asign = A_num[15]; wire [4:0] Aexp = A_num[14:10]; wire [9:0] Afrac = A_num[9:0];
    wire Bsign = B_num[15]; wire [4:0] Bexp = B_num[14:10]; wire [9:0] Bfrac = B_num[9:0];
    wire [4:0] exp_diff; wire sub_exp_co_unused;
    Sub_5_bit u_sub_exp (.a(Aexp), .b(Bexp), .d(exp_diff), .Co(sub_exp_co_unused));
    wire [10:0] B_mant_in = {Bvalid, Bfrac}; wire [10:0] B_mant_shifted;
    Shift_right_11_bit u_shift_right (.in(B_mant_in), .d(exp_diff), .out(B_mant_shifted));
    wire sign_xor; wire [10:0] B_mant_xored;
    a_xor_b u_sign_xor (.a(Asign), .b(Bsign), .out(sign_xor));
    Xor_11_bit u_xor_11 (.a(B_mant_shifted), .b(sign_xor), .out(B_mant_xored));
    wire [10:0] A_mant_in = {Avalid, Afrac}; wire [10:0] adder_out; wire adder_Co;
    Adder_11_bit u_adder_11 (.a(A_mant_in), .b(B_mant_xored), .Cin(sign_xor), .out(adder_out), .Co(adder_Co));
    wire real_overflow_co;
    c1 u_real_co (.A0(adder_Co), .A1(1'b0), .SA(sign_xor), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(real_overflow_co));
    wire [3:0] pe_out; wire mant_nonzero; wire [9:0] shift_left_out;
    Priority_encoder u_pe (.in(adder_out), .out(pe_out), .valid_any(mant_nonzero));
    Shift_left_10_bit u_shift_left (.in(adder_out[9:0]), .d(pe_out), .out(shift_left_out));
    wire [4:0] exp_add_out; Increment_5_bit u_exp_increment (.a(Aexp), .Cin(real_overflow_co), .out(exp_add_out));
    wire [4:0] exp_sub_out; wire exp_sub_Co;
    Sub_exp_pe_5_bit u_exp_sub (.a(Aexp), .b(pe_out), .d(exp_sub_out), .Co(exp_sub_Co));
    wire sub_path_valid;
    c1 u_sub_valid (.A0(1'b0), .A1(mant_nonzero), .SA(exp_sub_Co), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(sub_path_valid));
    wire valid_out_sel; MUX_2_to_1_1bit u_mux_valid_out (.i0(sub_path_valid), .i1(Avalid), .Sel(real_overflow_co), .out(valid_out_sel));
    genvar out_i;
    generate
        for (out_i = 0; out_i < 10; out_i = out_i + 1) begin : gen_final_frac
            c1 u_final_frac (.A0(1'b0), .A1(shift_left_out[out_i]), .SA(valid_out_sel), .B0(1'b0), .B1(adder_out[out_i+1]), .SB(valid_out_sel), .S0(real_overflow_co), .S1(1'b0), .f(out[out_i]));
        end
        for (out_i = 0; out_i < 5; out_i = out_i + 1) begin : gen_final_exp
            c1 u_final_exp (.A0(1'b0), .A1(exp_sub_out[out_i]), .SA(valid_out_sel), .B0(1'b0), .B1(exp_add_out[out_i]), .SB(valid_out_sel), .S0(real_overflow_co), .S1(1'b0), .f(out[out_i+10]));
        end
    endgenerate
    MUX_2_to_1_1bit u_final_sign (.i0(1'b0), .i1(Asign), .Sel(valid_out_sel), .out(out[15]));
endmodule
`default_nettype wire