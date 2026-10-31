// ============================================================================
// File: base_blocks.v
// ============================================================================

module Not (input wire a, output wire out);
    c1 u_not (.A0(1'b1), .A1(1'b0), .SA(a), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(out));
endmodule

module Or_2bit (input wire a, input wire b, output wire y);
    c1 u_or (.A0(1'b0), .A1(1'b1), .SA(a), .B0(1'b1), .B1(1'b1), .SB(1'b1), .S0(b), .S1(b), .f(y));
endmodule

module And_2bit (input wire a, input wire b, output wire y);
    // One c1 mux implements AND directly: a ? b : 0.
    c1 u_and (.A0(1'b0), .A1(1'b0), .SA(1'b0),
              .B0(1'b0), .B1(b), .SB(a),
              .S0(1'b1), .S1(1'b0), .f(y));
endmodule

module a_xor_b (input wire a, input wire b, output wire out);
    c2 u_xor (.D00(1'b0), .D01(1'b1), .D10(1'b1), .D11(1'b0), .A1(a), .B1(a), .A0(b), .B0(b), .out(out));
endmodule

module half_adder (input wire a, input wire b, output wire Sum, output wire Co);
    a_xor_b u_sum (.a(a), .b(b), .out(Sum));
    c2 u_co (.D00(1'b0), .D01(1'b0), .D10(1'b0), .D11(1'b1), .A1(a), .B1(a), .A0(b), .B0(b), .out(Co));
endmodule

module full_adder (input wire a, input wire b, input wire c, output wire Sum, output wire Co);
    wire not_b;
    Not u_not (.a(b), .out(not_b));
    c2 u_sum (.D00(b), .D01(not_b), .D10(not_b), .D11(b), .A1(a), .B1(a), .A0(c), .B0(c), .out(Sum));
    c2 u_co (.D00(1'b0), .D01(c), .D10(c), .D11(1'b1), .A1(b), .B1(b), .A0(a), .B0(a), .out(Co));
endmodule

module MUX_2_to_1_1bit (input wire i0, input wire i1, input wire Sel, output wire out);
    c1 u_mux (.A0(i0), .A1(i1), .SA(Sel), .B0(1'b0), .B1(1'b0), .SB(1'b0), .S0(1'b0), .S1(1'b0), .f(out));
endmodule

module MUX_2_to_1_10bit (input wire [9:0] a, input wire [9:0] b, input wire Sel, output wire [9:0] out);
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : gen_mux10
            MUX_2_to_1_1bit u_m (.i0(a[i]), .i1(b[i]), .Sel(Sel), .out(out[i]));
        end
    endgenerate
endmodule

module MUX_2_to_1_16bit (input wire [15:0] a, input wire [15:0] b, input wire Sel, output wire [15:0] out);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_mux16
            MUX_2_to_1_1bit u_m (.i0(a[i]), .i1(b[i]), .Sel(Sel), .out(out[i]));
        end
    endgenerate
endmodule

// ============================================================================
// File: components.v
// ============================================================================

module Zero_detector (
    input  wire [15:0] in,
    output wire        valid
);
    wire or_f9_to_f6, or_f5_to_f2, or_f9_to_f0, or_e4_to_e1;

    c2 u_c2_1 (
        .D00(in[6]), .D01(1'b1), .D10(1'b1), .D11(1'b1),
        .A1(in[9]),  .B1(in[8]), .A0(in[7]), .B0(in[7]),
        .out(or_f9_to_f6)
    );

    c2 u_c2_2 (
        .D00(in[2]), .D01(1'b1), .D10(1'b1), .D11(1'b1),
        .A1(in[5]),  .B1(in[4]), .A0(in[3]), .B0(in[3]),
        .out(or_f5_to_f2)
    );

    c2 u_c2_3 (
        .D00(in[0]),       .D01(1'b1),        .D10(1'b1), .D11(1'b1),
        .A1(or_f9_to_f6),  .B1(or_f5_to_f2),  .A0(in[1]), .B0(in[1]),
        .out(or_f9_to_f0)
    );

    c2 u_c2_4 (
        .D00(in[11]), .D01(1'b1),  .D10(1'b1),  .D11(1'b1),
        .A1(in[14]),  .B1(in[13]), .A0(in[12]), .B0(in[12]),
        .out(or_e4_to_e1)
    );

    c2 u_c2_5 (
        .D00(1'b0), .D01(or_f9_to_f0), .D10(or_f9_to_f0), .D11(or_f9_to_f0),
        .A1(1'b0),  .B1(or_e4_to_e1),  .A0(in[10]),       .B0(in[10]),
        .out(valid)
    );
endmodule

// ============================================================================
// File: array_mul_11bit.v
// Structural 11x11 unsigned array multiplier using only the provided cells.
// Boundary cells are specialized because one adder input is constant zero.
// ============================================================================

module bit_multiplier (
    input xi, yi, ci, pi,
    output xo, yo, co, po
);
    wire xy;
    wire xypi;

    assign xo = xi;
    assign yo = yi;

    // Partial product: xi * yi
    c1 u_partial_product (
        .A0(1'b0), .A1(1'b0), .SA(1'b0),
        .B0(1'b0), .B1(yi), .SB(xi),
        .S0(1'b1), .S1(1'b0), .f(xy)
    );

    // Sum = (xi*yi) XOR pi XOR ci
    a_xor_b u_xor_partial_pi (.a(xy), .b(pi), .out(xypi));
    a_xor_b u_xor_sum       (.a(xypi), .b(ci), .out(po));

    // Carry of a full adder: if (xy XOR pi), carry=ci; otherwise carry=xy.
    c1 u_carry_mux (
        .A0(xy), .A1(ci), .SA(xypi),
        .B0(1'b0), .B1(1'b0), .SB(1'b0),
        .S0(1'b0), .S1(1'b0), .f(co)
    );
endmodule

module array_mul_11bit (
    input  wire [10:0] a,
    input  wire [10:0] b,
    output wire [21:0] mul
);
    wire [11:0][11:0] xv, yv, pv, cv;
    genvar i, j;

    generate
        for (i = 0; i < 11; i = i + 1) begin : row
            for (j = 0; j < 11; j = j + 1) begin : column
                if ((i == 0) && (j == 0)) begin : corner_cell
                    wire xy;
                    assign xv[i][j+1] = xv[i][j];
                    assign yv[i+1][j] = yv[i][j];
                    c1 u_partial_product (
                        .A0(1'b0), .A1(1'b0), .SA(1'b0),
                        .B0(1'b0), .B1(yv[i][j]), .SB(xv[i][j]),
                        .S0(1'b1), .S1(1'b0), .f(xy)
                    );
                    assign pv[i+1][j] = xy;
                    assign cv[i][j+1] = 1'b0;
                end else if (i == 0) begin : top_row_cell
                    // Half-adder sum is implemented directly by c2 using
                    // controls (xv & yv) and cv; carry is a three-input AND.
                    assign xv[i][j+1] = xv[i][j];
                    assign yv[i+1][j] = yv[i][j];
                    c2 u_sum (
                        .D00(1'b0), .D01(1'b1), .D10(1'b1), .D11(1'b0),
                        .A1(cv[i][j]), .B1(1'b0),
                        .A0(xv[i][j]), .B0(yv[i][j]), .out(pv[i+1][j])
                    );
                    c1 u_carry (
                        .A0(1'b0), .A1(1'b0), .SA(1'b0),
                        .B0(1'b0), .B1(yv[i][j]), .SB(xv[i][j]),
                        .S0(1'b0), .S1(cv[i][j]), .f(cv[i][j+1])
                    );
                end else if (j == 0) begin : left_column_cell
                    assign xv[i][j+1] = xv[i][j];
                    assign yv[i+1][j] = yv[i][j];
                    c2 u_sum (
                        .D00(1'b0), .D01(1'b1), .D10(1'b1), .D11(1'b0),
                        .A1(pv[i][j+1]), .B1(1'b0),
                        .A0(xv[i][j]), .B0(yv[i][j]), .out(pv[i+1][j])
                    );
                    c1 u_carry (
                        .A0(1'b0), .A1(1'b0), .SA(1'b0),
                        .B0(1'b0), .B1(yv[i][j]), .SB(xv[i][j]),
                        .S0(1'b0), .S1(pv[i][j+1]), .f(cv[i][j+1])
                    );
                end else if ((i == 10) && (j == 10)) begin : fixed_one_corner
                    // Both leading mantissa bits are implicit ones: xy = 1.
                    assign xv[i][j+1] = xv[i][j];
                    assign yv[i+1][j] = yv[i][j];
                    wire xypi;
                    a_xor_b u_xor_pi (.a(1'b1), .b(pv[i][j+1]), .out(xypi));
                    a_xor_b u_sum (.a(xypi), .b(cv[i][j]), .out(pv[i+1][j]));
                    c1 u_carry (
                        .A0(1'b1), .A1(cv[i][j]), .SA(xypi),
                        .B0(1'b0), .B1(1'b0), .SB(1'b0),
                        .S0(1'b0), .S1(1'b0), .f(cv[i][j+1])
                    );
                end else if (i == 10) begin : fixed_a_msb_row
                    // a[10] is the implicit leading one, so xy = yi.
                    assign xv[i][j+1] = xv[i][j];
                    assign yv[i+1][j] = yv[i][j];
                    wire xypi;
                    a_xor_b u_xor_pi (.a(yv[i][j]), .b(pv[i][j+1]), .out(xypi));
                    a_xor_b u_sum (.a(xypi), .b(cv[i][j]), .out(pv[i+1][j]));
                    c1 u_carry (
                        .A0(yv[i][j]), .A1(cv[i][j]), .SA(xypi),
                        .B0(1'b0), .B1(1'b0), .SB(1'b0),
                        .S0(1'b0), .S1(1'b0), .f(cv[i][j+1])
                    );
                end else if (j == 10) begin : fixed_b_msb_column
                    // b[10] is the implicit leading one, so xy = xi.
                    assign xv[i][j+1] = xv[i][j];
                    assign yv[i+1][j] = yv[i][j];
                    wire xypi;
                    a_xor_b u_xor_pi (.a(xv[i][j]), .b(pv[i][j+1]), .out(xypi));
                    a_xor_b u_sum (.a(xypi), .b(cv[i][j]), .out(pv[i+1][j]));
                    c1 u_carry (
                        .A0(xv[i][j]), .A1(cv[i][j]), .SA(xypi),
                        .B0(1'b0), .B1(1'b0), .SB(1'b0),
                        .S0(1'b0), .S1(1'b0), .f(cv[i][j+1])
                    );
                end else begin : inner_cell
                    bit_multiplier inst(
                        .xi(xv[i][j]), .yi(yv[i][j]), .pi(pv[i][j+1]), .ci(cv[i][j]),
                        .xo(xv[i][j+1]), .yo(yv[i+1][j]), .po(pv[i+1][j]), .co(cv[i][j+1])
                    );
                end
            end
        end
    endgenerate

    generate
        for (i = 0; i < 11; i = i + 1) begin : init_and_output
            assign xv[i][0] = a[i];
            assign yv[0][i] = b[i];
            assign cv[i][0] = 1'b0;
            assign pv[0][i + 1] = 1'b0;
            assign pv[i + 1][11] = cv[i][11];
            assign mul[i] = pv[i + 1][0];
            assign mul[i + 11] = pv[11][i + 1];
        end
    endgenerate
endmodule

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

// ============================================================================
// File: base_blocks.v
// Description: Basic logical gates, MUXes, and 1-bit Adders using C1/C2
// ============================================================================

module Not (
    input  wire a,
    output wire out
);
    c1 u_not (
        .A0(1'b1), .A1(1'b0), .SA(a),
        .B0(1'b0), .B1(1'b0), .SB(1'b0),
        .S0(1'b0), .S1(1'b0),
        .f(out)
    );
endmodule

module MUX_2_to_1_1bit (
    input  wire i0,
    input  wire i1,
    input  wire Sel,
    output wire out
);
    c1 u_mux (
        .A0(i0),   .A1(i1),   .SA(Sel),
        .B0(1'b0), .B1(1'b0), .SB(1'b0),
        .S0(1'b0), .S1(1'b0),
        .f(out)
    );
endmodule

module MUX_2_to_1_16bit (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire        Sel,
    output wire [15:0] out
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_mux16
            MUX_2_to_1_1bit u_m (.i0(a[i]), .i1(b[i]), .Sel(Sel), .out(out[i]));
        end
    endgenerate
endmodule

module MUX_2_to_1_10bit (
    input  wire [9:0] a,
    input  wire [9:0] b,
    input  wire       Sel,
    output wire [9:0] out
);
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : gen_mux10
            MUX_2_to_1_1bit u_m (.i0(a[i]), .i1(b[i]), .Sel(Sel), .out(out[i]));
        end
    endgenerate
endmodule

module MUX_2_to_1_5bit (
    input  wire [4:0] a,
    input  wire [4:0] b,
    input  wire       Sel,
    output wire [4:0] out
);
    genvar i;
    generate
        for (i = 0; i < 5; i = i + 1) begin : gen_mux5
            MUX_2_to_1_1bit u_m (.i0(a[i]), .i1(b[i]), .Sel(Sel), .out(out[i]));
        end
    endgenerate
endmodule

module full_adder (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire Sum,
    output wire Co
);
    wire not_b;
    Not u_not (.a(b), .out(not_b));

    c2 u_sum (
        .D00(b),    .D01(not_b), .D10(not_b), .D11(b),
        .A1(a),     .B1(a),      .A0(c),      .B0(c),
        .out(Sum)
    );

    c2 u_co (
        .D00(1'b0), .D01(c), .D10(c), .D11(1'b1),
        .A1(b),     .B1(b),  .A0(a),  .B0(a),
        .out(Co)
    );
endmodule

module full_adder_b_invert (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire Sum,
    output wire Co
);
    wire not_b;
    Not u_not (.a(b), .out(not_b));

    c2 u_sum (
        .D00(not_b), .D01(b), .D10(b), .D11(not_b),
        .A1(a),      .B1(a),  .A0(c),  .B0(c),
        .out(Sum)
    );

    c2 u_co (
        .D00(1'b0),  .D01(c),     .D10(c), .D11(1'b1),
        .A1(not_b),  .B1(not_b),  .A0(a),  .B0(a),
        .out(Co)
    );
endmodule

module a_xor_b (
    input  wire a,
    input  wire b,
    output wire out
);
    c2 u_xor (
        .D00(1'b0), .D01(1'b1), .D10(1'b1), .D11(1'b0),
        .A1(a),     .B1(a),     .A0(b),     .B0(b),
        .out(out)
    );
endmodule

module Xor_11_bit (
    input  wire [10:0] a,
    input  wire        b,
    output wire [10:0] out
);
    genvar i;
    generate
        for (i = 0; i < 11; i = i + 1) begin : gen_xor11
            a_xor_b u_x (.a(a[i]), .b(b), .out(out[i]));
        end
    endgenerate
endmodule

// ============================================================================
// File: components.v
// Description: Multi-bit Adders, Shifters, Comparators, and Encoders
// ============================================================================

module Zero_detector (
    input  wire [15:0] in,
    output wire        valid
);
    wire or_f9_to_f6, or_f5_to_f2, or_f9_to_f0, or_e4_to_e1;

    c2 u_c2_1 (
        .D00(in[6]), .D01(1'b1), .D10(1'b1), .D11(1'b1),
        .A1(in[9]),  .B1(in[8]), .A0(in[7]), .B0(in[7]),
        .out(or_f9_to_f6)
    );

    c2 u_c2_2 (
        .D00(in[2]), .D01(1'b1), .D10(1'b1), .D11(1'b1),
        .A1(in[5]),  .B1(in[4]), .A0(in[3]), .B0(in[3]),
        .out(or_f5_to_f2)
    );

    c2 u_c2_3 (
        .D00(in[0]),       .D01(1'b1),        .D10(1'b1), .D11(1'b1),
        .A1(or_f9_to_f6),  .B1(or_f5_to_f2),  .A0(in[1]), .B0(in[1]),
        .out(or_f9_to_f0)
    );

    c2 u_c2_4 (
        .D00(in[11]), .D01(1'b1),  .D10(1'b1),  .D11(1'b1),
        .A1(in[14]),  .B1(in[13]), .A0(in[12]), .B0(in[12]),
        .out(or_e4_to_e1)
    );

    c2 u_c2_5 (
        .D00(1'b0), .D01(or_f9_to_f0), .D10(or_f9_to_f0), .D11(or_f9_to_f0),
        .A1(1'b0),  .B1(or_e4_to_e1),  .A0(in[10]),       .B0(in[10]),
        .out(valid)
    );
endmodule

// module Zero_detector (
//     input  wire [15:0] in,
//     output wire        valid
// );
//     wire or_e4_to_e1;

//     c2 u_c2_4 (
//         .D00(in[11]), .D01(1'b1),  .D10(1'b1),  .D11(1'b1),
//         .A1(in[14]),  .B1(in[13]), .A0(in[12]), .B0(in[12]),
//         .out(or_e4_to_e1)
//     );
//     c1 u_c1_valid (
//         .A0(in[10]), .A1(1'b1), .SA(or_e4_to_e1),
//         .B0(1'b0),   .B1(1'b0), .SB(1'b0),
//         .S0(1'b0),   .S1(1'b0),
//         .f(valid)
//     );
// endmodule

module Comparator_15_bit (
    input  wire [14:0] a,
    input  wire [14:0] b,
    output wire        out
);
    wire [14:0] c;
    c1 u_comp_0 (
        .A0(b[0]), .A1(1'b0), .SA(a[0]),
        .B0(1'b0), .B1(1'b0), .SB(1'b0),
        .S0(1'b0), .S1(1'b0), .f(c[0])
    );
    genvar i;
    generate
        for (i = 1; i < 15; i = i + 1) begin : gen_comp
            // If a[i] != b[i], this bit decides a < b; otherwise keep c[i-1].
            c1 u_comp_i (
                .A0(c[i-1]), .A1(1'b1), .SA(b[i]),
                .B0(1'b0),   .B1(c[i-1]), .SB(b[i]),
                .S0(a[i]),   .S1(1'b0), .f(c[i])
            );
        end
    endgenerate
    assign out = c[14];
endmodule

module Sub_5_bit (
    input  wire [4:0] a,
    input  wire [4:0] b,
    output wire [4:0] d,
    output wire       Co
);
    wire [4:0] c;
    full_adder_b_invert u_sub0 (.a(a[0]), .b(b[0]), .c(1'b1), .Sum(d[0]), .Co(c[0]));
    full_adder_b_invert u_sub1 (.a(a[1]), .b(b[1]), .c(c[0]), .Sum(d[1]), .Co(c[1]));
    full_adder_b_invert u_sub2 (.a(a[2]), .b(b[2]), .c(c[1]), .Sum(d[2]), .Co(c[2]));
    full_adder_b_invert u_sub3 (.a(a[3]), .b(b[3]), .c(c[2]), .Sum(d[3]), .Co(c[3]));
    full_adder_b_invert u_sub4 (.a(a[4]), .b(b[4]), .c(c[3]), .Sum(d[4]), .Co(c[4]));
    assign Co = c[4];
endmodule

module Sub_exp_pe_5_bit (
    input  wire [4:0] a,
    input  wire [3:0] b,
    output wire [4:0] d,
    output wire       Co
);
    wire [3:0] c;
    full_adder_b_invert u_sub0 (.a(a[0]), .b(b[0]), .c(1'b1), .Sum(d[0]), .Co(c[0]));
    full_adder_b_invert u_sub1 (.a(a[1]), .b(b[1]), .c(c[0]), .Sum(d[1]), .Co(c[1]));
    full_adder_b_invert u_sub2 (.a(a[2]), .b(b[2]), .c(c[1]), .Sum(d[2]), .Co(c[2]));
    full_adder_b_invert u_sub3 (.a(a[3]), .b(b[3]), .c(c[2]), .Sum(d[3]), .Co(c[3]));

    // b[4] is known to be zero, so the top subtraction stage simplifies.
    c2 u_diff4 (
        .D00(1'b1), .D01(1'b0), .D10(1'b0), .D11(1'b1),
        .A1(a[4]), .B1(a[4]), .A0(c[3]), .B0(c[3]), .out(d[4])
    );
    c1 u_carry4 (
        .A0(a[4]), .A1(1'b1), .SA(c[3]),
        .B0(1'b0), .B1(1'b0), .SB(1'b0),
        .S0(1'b0), .S1(1'b0), .f(Co)
    );
endmodule

module Adder_11_bit (
    input  wire [10:0] a,
    input  wire [10:0] b,
    input  wire        Cin,
    output wire [10:0] out,
    output wire        Co
);
    wire [10:0] c;
    full_adder u_fa0 (.a(a[0]), .b(b[0]), .c(Cin), .Sum(out[0]), .Co(c[0]));
    genvar i;
    generate
        for (i = 1; i < 11; i = i + 1) begin : gen_fa11
            full_adder u_fa (.a(a[i]), .b(b[i]), .c(c[i-1]), .Sum(out[i]), .Co(c[i]));
        end
    endgenerate
    assign Co = c[10];
endmodule

module Adder_5_bit (
    input  wire [4:0] a,
    input  wire [4:0] b,
    input  wire       Cin,
    output wire [4:0] out,
    output wire       Co
);
    wire [4:0] c;
    full_adder u_fa0 (.a(a[0]), .b(b[0]), .c(Cin),  .Sum(out[0]), .Co(c[0]));
    full_adder u_fa1 (.a(a[1]), .b(b[1]), .c(c[0]), .Sum(out[1]), .Co(c[1]));
    full_adder u_fa2 (.a(a[2]), .b(b[2]), .c(c[1]), .Sum(out[2]), .Co(c[2]));
    full_adder u_fa3 (.a(a[3]), .b(b[3]), .c(c[2]), .Sum(out[3]), .Co(c[3]));
    full_adder u_fa4 (.a(a[4]), .b(b[4]), .c(c[3]), .Sum(out[4]), .Co(c[4]));
    assign Co = c[4];
endmodule

module Shift_right_11_bit (
    input  wire [10:0] in,
    input  wire [4:0]  d,
    output wire [10:0] out
);
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

module Shift_left_10_bit (
    input  wire [9:0] in,
    input  wire [3:0] d,
    output wire [9:0] out
);
    wire [9:0] s0, s1, s2;
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : sl0
            if (i == 0) begin : sl0_zero
                MUX_2_to_1_1bit u_m (.i0(in[i]), .i1(1'b0), .Sel(d[0]), .out(s0[i]));
            end else begin : sl0_shift
                MUX_2_to_1_1bit u_m (.i0(in[i]), .i1(in[i-1]), .Sel(d[0]), .out(s0[i]));
            end
        end
        for (i = 0; i < 10; i = i + 1) begin : sl1
            if (i < 2) begin : sl1_zero
                MUX_2_to_1_1bit u_m (.i0(s0[i]), .i1(1'b0), .Sel(d[1]), .out(s1[i]));
            end else begin : sl1_shift
                MUX_2_to_1_1bit u_m (.i0(s0[i]), .i1(s0[i-2]), .Sel(d[1]), .out(s1[i]));
            end
        end
        for (i = 0; i < 10; i = i + 1) begin : sl2
            if (i < 4) begin : sl2_zero
                MUX_2_to_1_1bit u_m (.i0(s1[i]), .i1(1'b0), .Sel(d[2]), .out(s2[i]));
            end else begin : sl2_shift
                MUX_2_to_1_1bit u_m (.i0(s1[i]), .i1(s1[i-4]), .Sel(d[2]), .out(s2[i]));
            end
        end
        for (i = 0; i < 10; i = i + 1) begin : sl3
            if (i < 8) begin : sl3_zero
                MUX_2_to_1_1bit u_m (.i0(s2[i]), .i1(1'b0), .Sel(d[3]), .out(out[i]));
            end else begin : sl3_shift
                MUX_2_to_1_1bit u_m (.i0(s2[i]), .i1(s2[i-8]), .Sel(d[3]), .out(out[i]));
            end
        end
    endgenerate
endmodule

module Increment_5_bit (
    input  wire [4:0] a,
    input  wire       Cin,
    output wire [4:0] out
);
    wire [3:0] carry;
    a_xor_b u_xor0 (.a(a[0]), .b(Cin), .out(out[0]));
    c2 u_and0 (
        .D00(1'b0), .D01(1'b0), .D10(1'b0), .D11(1'b1),
        .A1(a[0]), .B1(a[0]), .A0(Cin), .B0(Cin), .out(carry[0])
    );
    genvar j;
    generate
        for (j = 1; j < 5; j = j + 1) begin : gen_increment
            a_xor_b u_xor (.a(a[j]), .b(carry[j-1]), .out(out[j]));
            if (j < 4) begin : gen_carry
                c2 u_and (
                    .D00(1'b0), .D01(1'b0), .D10(1'b0), .D11(1'b1),
                    .A1(a[j]), .B1(a[j]), .A0(carry[j-1]), .B0(carry[j-1]), .out(carry[j])
                );
            end
        end
    endgenerate
endmodule

module Priority_encoder (
    input  wire [10:0] in,
    output wire [3:0]  out,
    output wire        valid_any
);
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
    MUX_2_to_1_1bit u_mux_out2 (.i0(1'b0),    .i1(p_o0[2]), .Sel(v_o0), .out(out[2]));
    MUX_2_to_1_1bit u_mux_out1 (.i0(p_q2[1]), .i1(p_o0[1]), .Sel(v_o0), .out(out[1]));
    MUX_2_to_1_1bit u_mux_out0 (.i0(p_q2[0]), .i1(p_o0[0]), .Sel(v_o0), .out(out[0]));
endmodule

// ============================================================================
// File: datapath.v
// Description: Top-Level FP16 Adder Datapath
// ============================================================================

module Data_path (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [15:0] out
);
    wire        A_valid_raw, B_valid_raw;

    Zero_detector u_zd_a (.in(a), .valid(A_valid_raw));
    Zero_detector u_zd_b (.in(b), .valid(B_valid_raw));

    wire        comp_raw;
    wire        comp_out;
    wire [15:0] A_num, B_num;

    // Compare the raw magnitudes, then account for operands treated as zero.
    Comparator_15_bit u_comp (
        .a(a[14:0]),
        .b(b[14:0]),
        .out(comp_raw)
    );

    // comp_out = B_valid && (!A_valid || comp_raw)
    c1 u_comp_valid (
        .A0(1'b0), .A1(1'b0), .SA(1'b0),
        .B0(1'b1), .B1(comp_raw), .SB(A_valid_raw),
        .S0(B_valid_raw), .S1(1'b0),
        .f(comp_out)
    );

    // Combine input-zeroing and operand swapping in a single C1 per output bit.
    genvar mux_i;
    generate
        for (mux_i = 0; mux_i < 16; mux_i = mux_i + 1) begin : gen_valid_swap
            c1 u_mux_A_num (
                .A0(1'b0), .A1(a[mux_i]), .SA(A_valid_raw),
                .B0(1'b0), .B1(b[mux_i]), .SB(B_valid_raw),
                .S0(comp_out), .S1(1'b0), .f(A_num[mux_i])
            );
            c1 u_mux_B_num (
                .A0(1'b0), .A1(b[mux_i]), .SA(B_valid_raw),
                .B0(1'b0), .B1(a[mux_i]), .SB(A_valid_raw),
                .S0(comp_out), .S1(1'b0), .f(B_num[mux_i])
            );
        end
    endgenerate

    wire Avalid, Bvalid;
    MUX_2_to_1_1bit u_mux_avalid (.i0(A_valid_raw), .i1(B_valid_raw), .Sel(comp_out), .out(Avalid));
    MUX_2_to_1_1bit u_mux_bvalid (.i0(B_valid_raw), .i1(A_valid_raw), .Sel(comp_out), .out(Bvalid));

    wire        Asign = A_num[15];
    wire [4:0]  Aexp  = A_num[14:10];
    wire [9:0]  Afrac = A_num[9:0];

    wire        Bsign = B_num[15];
    wire [4:0]  Bexp  = B_num[14:10];
    wire [9:0]  Bfrac = B_num[9:0];

    wire [4:0] exp_diff;
    wire       sub_exp_co_unused;

    Sub_5_bit u_sub_exp (
        .a(Aexp),
        .b(Bexp),
        .d(exp_diff),
        .Co(sub_exp_co_unused)
    );

    wire [10:0] B_mant_in = {Bvalid, Bfrac};
    wire [10:0] B_mant_shifted;

    Shift_right_11_bit u_shift_right (
        .in(B_mant_in),
        .d(exp_diff),
        .out(B_mant_shifted)
    );

    wire        sign_xor;
    wire [10:0] B_mant_xored;

    a_xor_b u_sign_xor (
        .a(Asign),
        .b(Bsign),
        .out(sign_xor)
    );

    Xor_11_bit u_xor_11 (
        .a(B_mant_shifted),
        .b(sign_xor),
        .out(B_mant_xored)
    );

    wire [10:0] A_mant_in = {Avalid, Afrac};
    wire [10:0] adder_out;
    wire        adder_Co;

    Adder_11_bit u_adder_11 (
        .a(A_mant_in),
        .b(B_mant_xored),
        .Cin(sign_xor),
        .out(adder_out),
        .Co(adder_Co)
    );

    wire real_overflow_co;
    c1 u_real_co (
        .A0(adder_Co), .A1(1'b0), .SA(sign_xor),
        .B0(1'b0),     .B1(1'b0), .SB(1'b0),
        .S0(1'b0),     .S1(1'b0),
        .f(real_overflow_co)
    );

    wire [3:0]  pe_out;
    wire        mant_nonzero;
    wire [9:0] shift_left_out;

    Priority_encoder u_pe (
        .in(adder_out),
        .out(pe_out),
        .valid_any(mant_nonzero)
    );

    Shift_left_10_bit u_shift_left (
        .in(adder_out[9:0]),
        .d(pe_out),
        .out(shift_left_out)
    );

    wire [4:0] exp_add_out;

    Increment_5_bit u_exp_increment (
        .a(Aexp),
        .Cin(real_overflow_co),
        .out(exp_add_out)
    );

    wire [4:0] exp_sub_out;
    wire       exp_sub_Co;

    Sub_exp_pe_5_bit u_exp_sub (
        .a(Aexp),
        .b(pe_out),
        .d(exp_sub_out),
        .Co(exp_sub_Co)
    );

    wire sub_path_valid;
    c1 u_sub_valid (
        .A0(1'b0), .A1(mant_nonzero), .SA(exp_sub_Co),
        .B0(1'b0), .B1(1'b0),         .SB(1'b0),
        .S0(1'b0), .S1(1'b0),
        .f(sub_path_valid)
    );

    wire valid_out_sel;
    MUX_2_to_1_1bit u_mux_valid_out (
        .i0(sub_path_valid),
        .i1(Avalid),
        .Sel(real_overflow_co),
        .out(valid_out_sel)
    );

    // Merge branch selection and output-valid gating into one C1 per bit.
    genvar out_i;
    generate
        for (out_i = 0; out_i < 10; out_i = out_i + 1) begin : gen_final_frac
            c1 u_final_frac (
                .A0(1'b0), .A1(shift_left_out[out_i]), .SA(valid_out_sel),
                .B0(1'b0), .B1(adder_out[out_i+1]), .SB(valid_out_sel),
                .S0(real_overflow_co), .S1(1'b0), .f(out[out_i])
            );
        end
        for (out_i = 0; out_i < 5; out_i = out_i + 1) begin : gen_final_exp
            c1 u_final_exp (
                .A0(1'b0), .A1(exp_sub_out[out_i]), .SA(valid_out_sel),
                .B0(1'b0), .B1(exp_add_out[out_i]), .SB(valid_out_sel),
                .S0(real_overflow_co), .S1(1'b0), .f(out[out_i+10])
            );
        end
    endgenerate

    MUX_2_to_1_1bit u_final_sign (
        .i0(1'b0), .i1(Asign), .Sel(valid_out_sel), .out(out[15])
    );

endmodule

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

`timescale 1ns/1ps
`default_nettype none
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

// Packed 4:1 C1 muxes implement two barrel levels per cell.
module ac_rshift_jam13(input [12:0] a,input [4:0] sh,output [12:0] y);
    wire [12:0] first,second;
    wire [3:0] lowjam;
    wire [3:0] midjam;
    assign lowjam[0]=a[0];
    assign lowjam[1]=1'b0;
    assign lowjam[2]=a[2];
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
            if(i+j<13) begin:l assign lo[j]=a[i+j];end
            else begin:lz assign lo[j]=1'b0;end
            if(i+4*j<13) begin:h assign hi[j]=first[i+4*j];end
            else begin:hz assign hi[j]=1'b0;end
        end
        ac_mux4 l(lo[0],lo[1],lo[2],lo[3],sh[0],sh[1],first[i]);
        ac_mux4 h(hi[0],hi[1],hi[2],hi[3],sh[2],sh[3],second[i]);
        ac_lut2 #(.T(4'b0100)) clamp(second[i],sh[4],y[i]);
    end endgenerate
    // a has an implicit leading one, hence any shift >=16 jams to exactly 1.
    ac_or last(second[0],sh[4],y[0]);
endmodule

module ac_normalize13(input [12:0] a,output [12:0] y,output [3:0] shift,output nonzero);
    wire [12:0] mid;
    wire nz8,nz4hi,nz4lo,nz4,nz2,nz1;
    ac_reduce_or #(.W(8)) r8(a[12:5],nz8);
    ac_not n8(nz8,shift[3]);
    ac_reduce_or #(.W(4)) r4h(a[12:9],nz4hi);
    ac_reduce_or #(.W(4)) r4l(a[4:1],nz4lo);
    ac_mux m4(nz4hi,nz4lo,shift[3],nz4);
    ac_not n4(nz4,shift[2]);
    genvar i,j;
    generate for(i=0;i<13;i=i+1) begin:first_bits
        wire [3:0] choice;
        for(j=0;j<4;j=j+1) begin:c
            if(i>=4*j) begin:v assign choice[j]=a[i-4*j];end
            else begin:z assign choice[j]=1'b0;end
        end
        ac_mux4 u(choice[0],choice[1],choice[2],choice[3],shift[2],shift[3],mid[i]);
    end endgenerate
    ac_reduce_or #(.W(4)) nzero(mid[12:9],nonzero);
    ac_or r2(mid[12],mid[11],nz2);
    ac_not n2(nz2,shift[1]);
    ac_mux m1(mid[12],mid[10],shift[1],nz1);
    ac_not n1(nz1,shift[0]);
    // Only bits [11:2] are needed after normalization; the other bits are wiring.
    assign y[12]=1'b1;
    assign y[1:0]=2'b00;
    generate for(i=2;i<12;i=i+1) begin:last_bits
        wire [3:0] choice;
        for(j=0;j<4;j=j+1) begin:c
            if(i>=j) begin:v assign choice[j]=mid[i-j];end
            else begin:z assign choice[j]=1'b0;end
        end
        ac_mux4 u(choice[0],choice[1],choice[2],choice[3],shift[0],shift[1],y[i]);
    end endgenerate
endmodule
`default_nettype wire

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

`timescale 1ns/1ps
`default_nettype none
// Generated by scripts/generate_multiplier.py; do not edit by hand.
module ac_sig11_product(input [9:0] a,b,output [21:0] p);
    wire pp_0_0;
    ac_and pp0_0(a[0],b[0],pp_0_0);
    wire pp_0_1;
    ac_and pp0_1(a[0],b[1],pp_0_1);
    wire pp_0_2;
    ac_and pp0_2(a[0],b[2],pp_0_2);
    wire pp_0_3;
    ac_and pp0_3(a[0],b[3],pp_0_3);
    wire pp_0_4;
    ac_and pp0_4(a[0],b[4],pp_0_4);
    wire pp_0_5;
    ac_and pp0_5(a[0],b[5],pp_0_5);
    wire pp_0_6;
    ac_and pp0_6(a[0],b[6],pp_0_6);
    wire pp_0_7;
    ac_and pp0_7(a[0],b[7],pp_0_7);
    wire pp_0_8;
    ac_and pp0_8(a[0],b[8],pp_0_8);
    wire pp_0_9;
    ac_and pp0_9(a[0],b[9],pp_0_9);
    wire pp_1_0;
    ac_and pp1_0(a[1],b[0],pp_1_0);
    wire pp_1_1;
    ac_and pp1_1(a[1],b[1],pp_1_1);
    wire pp_1_2;
    ac_and pp1_2(a[1],b[2],pp_1_2);
    wire pp_1_3;
    ac_and pp1_3(a[1],b[3],pp_1_3);
    wire pp_1_4;
    ac_and pp1_4(a[1],b[4],pp_1_4);
    wire pp_1_5;
    ac_and pp1_5(a[1],b[5],pp_1_5);
    wire pp_1_6;
    ac_and pp1_6(a[1],b[6],pp_1_6);
    wire pp_1_7;
    ac_and pp1_7(a[1],b[7],pp_1_7);
    wire pp_1_8;
    ac_and pp1_8(a[1],b[8],pp_1_8);
    wire pp_1_9;
    ac_and pp1_9(a[1],b[9],pp_1_9);
    wire pp_2_0;
    ac_and pp2_0(a[2],b[0],pp_2_0);
    wire pp_2_1;
    ac_and pp2_1(a[2],b[1],pp_2_1);
    wire pp_2_2;
    ac_and pp2_2(a[2],b[2],pp_2_2);
    wire pp_2_3;
    ac_and pp2_3(a[2],b[3],pp_2_3);
    wire pp_2_4;
    ac_and pp2_4(a[2],b[4],pp_2_4);
    wire pp_2_5;
    ac_and pp2_5(a[2],b[5],pp_2_5);
    wire pp_2_6;
    ac_and pp2_6(a[2],b[6],pp_2_6);
    wire pp_2_7;
    ac_and pp2_7(a[2],b[7],pp_2_7);
    wire pp_2_8;
    ac_and pp2_8(a[2],b[8],pp_2_8);
    wire pp_2_9;
    ac_and pp2_9(a[2],b[9],pp_2_9);
    wire pp_3_0;
    ac_and pp3_0(a[3],b[0],pp_3_0);
    wire pp_3_1;
    ac_and pp3_1(a[3],b[1],pp_3_1);
    wire pp_3_2;
    ac_and pp3_2(a[3],b[2],pp_3_2);
    wire pp_3_3;
    ac_and pp3_3(a[3],b[3],pp_3_3);
    wire pp_3_4;
    ac_and pp3_4(a[3],b[4],pp_3_4);
    wire pp_3_5;
    ac_and pp3_5(a[3],b[5],pp_3_5);
    wire pp_3_6;
    ac_and pp3_6(a[3],b[6],pp_3_6);
    wire pp_3_7;
    ac_and pp3_7(a[3],b[7],pp_3_7);
    wire pp_3_8;
    ac_and pp3_8(a[3],b[8],pp_3_8);
    wire pp_3_9;
    ac_and pp3_9(a[3],b[9],pp_3_9);
    wire pp_4_0;
    ac_and pp4_0(a[4],b[0],pp_4_0);
    wire pp_4_1;
    ac_and pp4_1(a[4],b[1],pp_4_1);
    wire pp_4_2;
    ac_and pp4_2(a[4],b[2],pp_4_2);
    wire pp_4_3;
    ac_and pp4_3(a[4],b[3],pp_4_3);
    wire pp_4_4;
    ac_and pp4_4(a[4],b[4],pp_4_4);
    wire pp_4_5;
    ac_and pp4_5(a[4],b[5],pp_4_5);
    wire pp_4_6;
    ac_and pp4_6(a[4],b[6],pp_4_6);
    wire pp_4_7;
    ac_and pp4_7(a[4],b[7],pp_4_7);
    wire pp_4_8;
    ac_and pp4_8(a[4],b[8],pp_4_8);
    wire pp_4_9;
    ac_and pp4_9(a[4],b[9],pp_4_9);
    wire pp_5_0;
    ac_and pp5_0(a[5],b[0],pp_5_0);
    wire pp_5_1;
    ac_and pp5_1(a[5],b[1],pp_5_1);
    wire pp_5_2;
    ac_and pp5_2(a[5],b[2],pp_5_2);
    wire pp_5_3;
    ac_and pp5_3(a[5],b[3],pp_5_3);
    wire pp_5_4;
    ac_and pp5_4(a[5],b[4],pp_5_4);
    wire pp_5_5;
    ac_and pp5_5(a[5],b[5],pp_5_5);
    wire pp_5_6;
    ac_and pp5_6(a[5],b[6],pp_5_6);
    wire pp_5_7;
    ac_and pp5_7(a[5],b[7],pp_5_7);
    wire pp_5_8;
    ac_and pp5_8(a[5],b[8],pp_5_8);
    wire pp_5_9;
    ac_and pp5_9(a[5],b[9],pp_5_9);
    wire pp_6_0;
    ac_and pp6_0(a[6],b[0],pp_6_0);
    wire pp_6_1;
    ac_and pp6_1(a[6],b[1],pp_6_1);
    wire pp_6_2;
    ac_and pp6_2(a[6],b[2],pp_6_2);
    wire pp_6_3;
    ac_and pp6_3(a[6],b[3],pp_6_3);
    wire pp_6_4;
    ac_and pp6_4(a[6],b[4],pp_6_4);
    wire pp_6_5;
    ac_and pp6_5(a[6],b[5],pp_6_5);
    wire pp_6_6;
    ac_and pp6_6(a[6],b[6],pp_6_6);
    wire pp_6_7;
    ac_and pp6_7(a[6],b[7],pp_6_7);
    wire pp_6_8;
    ac_and pp6_8(a[6],b[8],pp_6_8);
    wire pp_6_9;
    ac_and pp6_9(a[6],b[9],pp_6_9);
    wire pp_7_0;
    ac_and pp7_0(a[7],b[0],pp_7_0);
    wire pp_7_1;
    ac_and pp7_1(a[7],b[1],pp_7_1);
    wire pp_7_2;
    ac_and pp7_2(a[7],b[2],pp_7_2);
    wire pp_7_3;
    ac_and pp7_3(a[7],b[3],pp_7_3);
    wire pp_7_4;
    ac_and pp7_4(a[7],b[4],pp_7_4);
    wire pp_7_5;
    ac_and pp7_5(a[7],b[5],pp_7_5);
    wire pp_7_6;
    ac_and pp7_6(a[7],b[6],pp_7_6);
    wire pp_7_7;
    ac_and pp7_7(a[7],b[7],pp_7_7);
    wire pp_7_8;
    ac_and pp7_8(a[7],b[8],pp_7_8);
    wire pp_7_9;
    ac_and pp7_9(a[7],b[9],pp_7_9);
    wire pp_8_0;
    ac_and pp8_0(a[8],b[0],pp_8_0);
    wire pp_8_1;
    ac_and pp8_1(a[8],b[1],pp_8_1);
    wire pp_8_2;
    ac_and pp8_2(a[8],b[2],pp_8_2);
    wire pp_8_3;
    ac_and pp8_3(a[8],b[3],pp_8_3);
    wire pp_8_4;
    ac_and pp8_4(a[8],b[4],pp_8_4);
    wire pp_8_5;
    ac_and pp8_5(a[8],b[5],pp_8_5);
    wire pp_8_6;
    ac_and pp8_6(a[8],b[6],pp_8_6);
    wire pp_8_7;
    ac_and pp8_7(a[8],b[7],pp_8_7);
    wire pp_8_8;
    ac_and pp8_8(a[8],b[8],pp_8_8);
    wire pp_8_9;
    ac_and pp8_9(a[8],b[9],pp_8_9);
    wire pp_9_0;
    ac_and pp9_0(a[9],b[0],pp_9_0);
    wire pp_9_1;
    ac_and pp9_1(a[9],b[1],pp_9_1);
    wire pp_9_2;
    ac_and pp9_2(a[9],b[2],pp_9_2);
    wire pp_9_3;
    ac_and pp9_3(a[9],b[3],pp_9_3);
    wire pp_9_4;
    ac_and pp9_4(a[9],b[4],pp_9_4);
    wire pp_9_5;
    ac_and pp9_5(a[9],b[5],pp_9_5);
    wire pp_9_6;
    ac_and pp9_6(a[9],b[6],pp_9_6);
    wire pp_9_7;
    ac_and pp9_7(a[9],b[7],pp_9_7);
    wire pp_9_8;
    ac_and pp9_8(a[9],b[8],pp_9_8);
    wire pp_9_9;
    ac_and pp9_9(a[9],b[9],pp_9_9);
    wire s0,c0;
    ac_fa fa0(pp_0_2,pp_1_1,pp_2_0,s0,c0);
    wire s1,c1;
    ac_fa fa1(pp_0_3,pp_1_2,pp_2_1,s1,c1);
    wire s2,c2;
    ac_fa fa2(pp_3_0,c0,s1,s2,c2);
    wire s3,c3;
    ac_fa fa3(pp_0_4,pp_1_3,pp_2_2,s3,c3);
    wire s4,c4;
    ac_fa fa4(pp_3_1,pp_4_0,c1,s4,c4);
    wire s5,c5;
    ac_fa fa5(c2,s3,s4,s5,c5);
    wire s6,c6;
    ac_fa fa6(pp_0_5,pp_1_4,pp_2_3,s6,c6);
    wire s7,c7;
    ac_fa fa7(pp_3_2,pp_4_1,pp_5_0,s7,c7);
    wire s8,c8;
    ac_fa fa8(c3,c4,c5,s8,c8);
    wire s9,c9;
    ac_fa fa9(s6,s7,s8,s9,c9);
    wire s10,c10;
    ac_fa fa10(pp_0_6,pp_1_5,pp_2_4,s10,c10);
    wire s11,c11;
    ac_fa fa11(pp_3_3,pp_4_2,pp_5_1,s11,c11);
    wire s12,c12;
    ac_fa fa12(pp_6_0,c6,c7,s12,c12);
    wire s13,c13;
    ac_fa fa13(c8,c9,s10,s13,c13);
    wire s14,c14;
    ac_fa fa14(s11,s12,s13,s14,c14);
    wire s15,c15;
    ac_fa fa15(pp_0_7,pp_1_6,pp_2_5,s15,c15);
    wire s16,c16;
    ac_fa fa16(pp_3_4,pp_4_3,pp_5_2,s16,c16);
    wire s17,c17;
    ac_fa fa17(pp_6_1,pp_7_0,c10,s17,c17);
    wire s18,c18;
    ac_fa fa18(c11,c12,c13,s18,c18);
    wire s19,c19;
    ac_fa fa19(c14,s15,s16,s19,c19);
    wire s20,c20;
    ac_fa fa20(s17,s18,s19,s20,c20);
    wire s21,c21;
    ac_fa fa21(pp_0_8,pp_1_7,pp_2_6,s21,c21);
    wire s22,c22;
    ac_fa fa22(pp_3_5,pp_4_4,pp_5_3,s22,c22);
    wire s23,c23;
    ac_fa fa23(pp_6_2,pp_7_1,pp_8_0,s23,c23);
    wire s24,c24;
    ac_fa fa24(c15,c16,c17,s24,c24);
    wire s25,c25;
    ac_fa fa25(c18,c19,c20,s25,c25);
    wire s26,c26;
    ac_fa fa26(s21,s22,s23,s26,c26);
    wire s27,c27;
    ac_fa fa27(s24,s25,s26,s27,c27);
    wire s28,c28;
    ac_fa fa28(pp_0_9,pp_1_8,pp_2_7,s28,c28);
    wire s29,c29;
    ac_fa fa29(pp_3_6,pp_4_5,pp_5_4,s29,c29);
    wire s30,c30;
    ac_fa fa30(pp_6_3,pp_7_2,pp_8_1,s30,c30);
    wire s31,c31;
    ac_fa fa31(pp_9_0,c21,c22,s31,c31);
    wire s32,c32;
    ac_fa fa32(c23,c24,c25,s32,c32);
    wire s33,c33;
    ac_fa fa33(c26,c27,s28,s33,c33);
    wire s34,c34;
    ac_fa fa34(s29,s30,s31,s34,c34);
    wire s35,c35;
    ac_fa fa35(s32,s33,s34,s35,c35);
    wire s36,c36;
    ac_fa fa36(a[0],pp_1_9,pp_2_8,s36,c36);
    wire s37,c37;
    ac_fa fa37(pp_3_7,pp_4_6,pp_5_5,s37,c37);
    wire s38,c38;
    ac_fa fa38(pp_6_4,pp_7_3,pp_8_2,s38,c38);
    wire s39,c39;
    ac_fa fa39(pp_9_1,b[0],c28,s39,c39);
    wire s40,c40;
    ac_fa fa40(c29,c30,c31,s40,c40);
    wire s41,c41;
    ac_fa fa41(c32,c33,c34,s41,c41);
    wire s42,c42;
    ac_fa fa42(c35,s36,s37,s42,c42);
    wire s43,c43;
    ac_fa fa43(s38,s39,s40,s43,c43);
    wire s44,c44;
    ac_fa fa44(s41,s42,s43,s44,c44);
    wire s45,c45;
    ac_fa fa45(a[1],pp_2_9,pp_3_8,s45,c45);
    wire s46,c46;
    ac_fa fa46(pp_4_7,pp_5_6,pp_6_5,s46,c46);
    wire s47,c47;
    ac_fa fa47(pp_7_4,pp_8_3,pp_9_2,s47,c47);
    wire s48,c48;
    ac_fa fa48(b[1],c36,c37,s48,c48);
    wire s49,c49;
    ac_fa fa49(c38,c39,c40,s49,c49);
    wire s50,c50;
    ac_fa fa50(c41,c42,c43,s50,c50);
    wire s51,c51;
    ac_fa fa51(c44,s45,s46,s51,c51);
    wire s52,c52;
    ac_fa fa52(s47,s48,s49,s52,c52);
    wire s53,c53;
    ac_fa fa53(s50,s51,s52,s53,c53);
    wire s54,c54;
    ac_fa fa54(a[2],pp_3_9,pp_4_8,s54,c54);
    wire s55,c55;
    ac_fa fa55(pp_5_7,pp_6_6,pp_7_5,s55,c55);
    wire s56,c56;
    ac_fa fa56(pp_8_4,pp_9_3,b[2],s56,c56);
    wire s57,c57;
    ac_fa fa57(c45,c46,c47,s57,c57);
    wire s58,c58;
    ac_fa fa58(c48,c49,c50,s58,c58);
    wire s59,c59;
    ac_fa fa59(c51,c52,c53,s59,c59);
    wire s60,c60;
    ac_fa fa60(s54,s55,s56,s60,c60);
    wire s61,c61;
    ac_fa fa61(s57,s58,s59,s61,c61);
    wire s62,c62;
    ac_fa fa62(a[3],pp_4_9,pp_5_8,s62,c62);
    wire s63,c63;
    ac_fa fa63(pp_6_7,pp_7_6,pp_8_5,s63,c63);
    wire s64,c64;
    ac_fa fa64(pp_9_4,b[3],c54,s64,c64);
    wire s65,c65;
    ac_fa fa65(c55,c56,c57,s65,c65);
    wire s66,c66;
    ac_fa fa66(c58,c59,c60,s66,c66);
    wire s67,c67;
    ac_fa fa67(c61,s62,s63,s67,c67);
    wire s68,c68;
    ac_fa fa68(s64,s65,s66,s68,c68);
    wire s69,c69;
    ac_fa fa69(a[4],pp_5_9,pp_6_8,s69,c69);
    wire s70,c70;
    ac_fa fa70(pp_7_7,pp_8_6,pp_9_5,s70,c70);
    wire s71,c71;
    ac_fa fa71(b[4],c62,c63,s71,c71);
    wire s72,c72;
    ac_fa fa72(c64,c65,c66,s72,c72);
    wire s73,c73;
    ac_fa fa73(c67,c68,s69,s73,c73);
    wire s74,c74;
    ac_fa fa74(s70,s71,s72,s74,c74);
    wire s75,c75;
    ac_fa fa75(a[5],pp_6_9,pp_7_8,s75,c75);
    wire s76,c76;
    ac_fa fa76(pp_8_7,pp_9_6,b[5],s76,c76);
    wire s77,c77;
    ac_fa fa77(c69,c70,c71,s77,c77);
    wire s78,c78;
    ac_fa fa78(c72,c73,c74,s78,c78);
    wire s79,c79;
    ac_fa fa79(s75,s76,s77,s79,c79);
    wire s80,c80;
    ac_fa fa80(a[6],pp_7_9,pp_8_8,s80,c80);
    wire s81,c81;
    ac_fa fa81(pp_9_7,b[6],c75,s81,c81);
    wire s82,c82;
    ac_fa fa82(c76,c77,c78,s82,c82);
    wire s83,c83;
    ac_fa fa83(c79,s80,s81,s83,c83);
    wire s84,c84;
    ac_fa fa84(a[7],pp_8_9,pp_9_8,s84,c84);
    wire s85,c85;
    ac_fa fa85(b[7],c80,c81,s85,c85);
    wire s86,c86;
    ac_fa fa86(c82,c83,s84,s86,c86);
    wire s87,c87;
    ac_fa fa87(a[8],pp_9_9,b[8],s87,c87);
    wire s88,c88;
    ac_fa fa88(c84,c85,c86,s88,c88);
    wire s89,c89;
    ac_fa fa89(a[9],b[9],c87,s89,c89);
    assign p[0]=pp_0_0;
    wire r1;
    ac_ha ha1(pp_0_1,pp_1_0,p[1],r1);
    wire r2;
    ac_ha ha2(s0,r1,p[2],r2);
    wire r3;
    ac_ha ha3(s2,r2,p[3],r3);
    wire r4;
    ac_ha ha4(s5,r3,p[4],r4);
    wire r5;
    ac_ha ha5(s9,r4,p[5],r5);
    wire r6;
    ac_ha ha6(s14,r5,p[6],r6);
    wire r7;
    ac_ha ha7(s20,r6,p[7],r7);
    wire r8;
    ac_ha ha8(s27,r7,p[8],r8);
    wire r9;
    ac_ha ha9(s35,r8,p[9],r9);
    wire r10;
    ac_ha ha10(s44,r9,p[10],r10);
    wire r11;
    ac_ha ha11(s53,r10,p[11],r11);
    wire r12;
    ac_fa ripple12(s60,s61,r11,p[12],r12);
    wire r13;
    ac_fa ripple13(s67,s68,r12,p[13],r13);
    wire r14;
    ac_fa ripple14(s73,s74,r13,p[14],r14);
    wire r15;
    ac_fa ripple15(s78,s79,r14,p[15],r15);
    wire r16;
    ac_fa ripple16(s82,s83,r15,p[16],r16);
    wire r17;
    ac_fa ripple17(s85,s86,r16,p[17],r17);
    wire r18;
    ac_fa ripple18(s87,s88,r17,p[18],r18);
    wire r19;
    ac_fa ripple19(c88,s89,r18,p[19],r19);
    wire r20;
    ac_fa ripple20(1'b1,c89,r19,p[20],r20);
    assign p[21]=r20;
endmodule
`default_nettype wire

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
