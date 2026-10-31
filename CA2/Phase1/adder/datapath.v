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