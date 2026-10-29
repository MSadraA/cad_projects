// ============================================================================
// File: fp16_multiplier_core.v
// ============================================================================

module fp16_multiplier_core (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [15:0] out
);

    wire        a_sign = a[15];
    wire [4:0]  a_exp  = a[14:10];
    wire [9:0]  a_frac = a[9:0];

    wire        b_sign = b[15];
    wire [4:0]  b_exp  = b[14:10];
    wire [9:0]  b_frac = b[9:0];

    wire a_valid, b_valid;
    Zero_detector u_a_zd (.in(a), .valid(a_valid));
    Zero_detector u_b_zd (.in(b), .valid(b_valid));

    wire a_is_zero, b_is_zero, any_input_zero;
    Not u_not_a_valid (.a(a_valid), .out(a_is_zero));
    Not u_not_b_valid (.a(b_valid), .out(b_is_zero));
    
    Or_2bit u_any_z (.a(a_is_zero), .b(b_is_zero), .y(any_input_zero));

    wire final_sign;
    a_xor_b u_sign_xor (.a(a_sign), .b(b_sign), .out(final_sign));

    wire [10:0] a_mant_11 = {1'b1, a_frac};
    wire [10:0] b_mant_11 = {1'b1, b_frac};
    wire [21:0] mant_product;
    array_mul_11bit u_array_mul (.a(a_mant_11), .b(b_mant_11), .mul(mant_product));
    wire norm_shift = mant_product[21];

    wire [5:0] exp_sum1;
    wire c1_0, c1_1, c1_2, c1_3, c1_4, c1_5;
    
    full_adder u_fa1_0 (.a(a_exp[0]), .b(b_exp[0]), .c(1'b0), .Sum(exp_sum1[0]), .Co(c1_0));
    full_adder u_fa1_1 (.a(a_exp[1]), .b(b_exp[1]), .c(c1_0), .Sum(exp_sum1[1]), .Co(c1_1));
    full_adder u_fa1_2 (.a(a_exp[2]), .b(b_exp[2]), .c(c1_1), .Sum(exp_sum1[2]), .Co(c1_2));
    full_adder u_fa1_3 (.a(a_exp[3]), .b(b_exp[3]), .c(c1_2), .Sum(exp_sum1[3]), .Co(c1_3));
    full_adder u_fa1_4 (.a(a_exp[4]), .b(b_exp[4]), .c(c1_3), .Sum(exp_sum1[4]), .Co(c1_4));
    assign exp_sum1[5] = c1_4;
    assign c1_5 = 1'b0;

    wire [5:0] exp_norm;
    wire c2_0, c2_1, c2_2, c2_3, c2_4;
    a_xor_b u_norm_sum0 (.a(exp_sum1[0]), .b(norm_shift), .out(exp_norm[0]));
    And_2bit u_norm_carry0 (.a(exp_sum1[0]), .b(norm_shift), .y(c2_0));
    a_xor_b u_norm_sum1 (.a(exp_sum1[1]), .b(c2_0), .out(exp_norm[1]));
    And_2bit u_norm_carry1 (.a(exp_sum1[1]), .b(c2_0), .y(c2_1));
    a_xor_b u_norm_sum2 (.a(exp_sum1[2]), .b(c2_1), .out(exp_norm[2]));
    And_2bit u_norm_carry2 (.a(exp_sum1[2]), .b(c2_1), .y(c2_2));
    a_xor_b u_norm_sum3 (.a(exp_sum1[3]), .b(c2_2), .out(exp_norm[3]));
    And_2bit u_norm_carry3 (.a(exp_sum1[3]), .b(c2_2), .y(c2_3));
    a_xor_b u_norm_sum4 (.a(exp_sum1[4]), .b(c2_3), .out(exp_norm[4]));
    And_2bit u_norm_carry4 (.a(exp_sum1[4]), .b(c2_3), .y(c2_4));
    a_xor_b u_norm_sum5 (.a(exp_sum1[5]), .b(c2_4), .out(exp_norm[5]));

    wire [5:0] final_e;
    wire c3_1, c3_2, c3_3, c3_4, final_co;
    
    Not u_s3_0_not (.a(exp_norm[0]), .out(final_e[0]));
    wire c3_0 = exp_norm[0];
    
    half_adder u_s3_1_ha (.a(exp_norm[1]), .b(c3_0), .Sum(final_e[1]), .Co(c3_1));
    half_adder u_s3_2_ha (.a(exp_norm[2]), .b(c3_1), .Sum(final_e[2]), .Co(c3_2));
    half_adder u_s3_3_ha (.a(exp_norm[3]), .b(c3_2), .Sum(final_e[3]), .Co(c3_3));
    // Adding constant one at these positions simplifies each full adder.
    c2 u_s3_4_xnor (
        .D00(1'b1), .D01(1'b0), .D10(1'b0), .D11(1'b1),
        .A1(exp_norm[4]), .B1(exp_norm[4]),
        .A0(c3_3), .B0(c3_3), .out(final_e[4])
    );
    Or_2bit u_s3_4_carry (.a(exp_norm[4]), .b(c3_3), .y(c3_4));
    c2 u_s3_5_xnor (
        .D00(1'b1), .D01(1'b0), .D10(1'b0), .D11(1'b1),
        .A1(exp_norm[5]), .B1(exp_norm[5]),
        .A0(c3_4), .B0(c3_4), .out(final_e[5])
    );
    Or_2bit u_s3_5_carry (.a(exp_norm[5]), .b(c3_4), .y(final_co));

    wire not_final_co;
    Not u_not_fco (.a(final_co), .out(not_final_co));

    wire e_or1, e_or2, e_or3, e_nz;
    Or_2bit u_ez1(.a(final_e[0]), .b(final_e[1]), .y(e_or1));
    Or_2bit u_ez2(.a(final_e[2]), .b(final_e[3]), .y(e_or2));
    Or_2bit u_ez3(.a(e_or1),      .b(e_or2),      .y(e_or3));
    Or_2bit u_ez4(.a(e_or3),      .b(final_e[4]), .y(e_nz));
    
    wire e_is_0;
    Not u_ez_not(.a(e_nz), .out(e_is_0));

    wire underflow;
    Or_2bit u_underflow_or (.a(not_final_co), .b(e_is_0), .y(underflow));

    wire a1, a2, a3, e_is_31;
    And_2bit u_a1(.a(final_e[0]), .b(final_e[1]), .y(a1));
    And_2bit u_a2(.a(final_e[2]), .b(final_e[3]), .y(a2));
    And_2bit u_a3(.a(a1),         .b(a2),         .y(a3));
    And_2bit u_a4(.a(a3),         .b(final_e[4]), .y(e_is_31));

    wire exp_over_thresh, overflow;
    Or_2bit u_or_thresh (.a(final_e[5]), .b(e_is_31), .y(exp_over_thresh));
    And_2bit u_and_over (.a(final_co), .b(exp_over_thresh), .y(overflow));

    wire force_zero;
    Or_2bit u_force_z_or (.a(underflow), .b(any_input_zero), .y(force_zero));

    // Merge normalization selection, overflow, and zeroing in one c2 per
    // fraction bit. zero_frac is asserted for overflow or forced-zero cases.
    wire zero_frac;
    Or_2bit u_zero_frac (.a(overflow), .b(force_zero), .y(zero_frac));
    genvar k;
    generate
        for (k = 0; k < 10; k = k + 1) begin : gen_fraction_out
            c2 u_out_bit (
                .D00(mant_product[k+10]), .D01(mant_product[k+11]),
                .D10(1'b0), .D11(1'b0),
                .A1(zero_frac), .B1(1'b0),
                .A0(norm_shift), .B0(1'b1), .out(out[k])
            );
        end
        for (k = 0; k < 5; k = k + 1) begin : gen_exponent_out
            c1 u_out_bit (
                .A0(final_e[k]), .A1(1'b0), .SA(force_zero),
                .B0(1'b1), .B1(1'b0), .SB(force_zero),
                .S0(overflow), .S1(1'b0), .f(out[k+10])
            );
        end
    endgenerate

    c1 u_sign_out (
        .A0(final_sign), .A1(1'b0), .SA(force_zero),
        .B0(1'b0), .B1(1'b0), .SB(1'b0),
        .S0(1'b0), .S1(1'b0), .f(out[15])
    );
endmodule