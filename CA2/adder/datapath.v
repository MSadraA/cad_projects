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
    wire [15:0] a_clean, b_clean;

    Zero_detector u_zd_a (.in(a), .valid(A_valid_raw));
    Zero_detector u_zd_b (.in(b), .valid(B_valid_raw));

    MUX_2_to_1_16bit u_mux_in_a (.a(16'b0000_0000_0000_0000), .b(a), .Sel(A_valid_raw), .out(a_clean));
    MUX_2_to_1_16bit u_mux_in_b (.a(16'b0000_0000_0000_0000), .b(b), .Sel(B_valid_raw), .out(b_clean));

    wire        comp_out;
    wire [15:0] A_num, B_num;

    Comparator_15_bit u_comp (
        .a(a_clean[14:0]),
        .b(b_clean[14:0]),
        .out(comp_out)
    );

    MUX_2_to_1_16bit u_mux_swap_top (
        .a(a_clean),
        .b(b_clean),
        .Sel(comp_out),
        .out(A_num)
    );

    MUX_2_to_1_16bit u_mux_swap_bot (
        .a(b_clean),
        .b(a_clean),
        .Sel(comp_out),
        .out(B_num)
    );

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
    wire [10:0] shift_left_out;

    Priority_encoder u_pe (
        .in(adder_out),
        .out(pe_out),
        .valid_any(mant_nonzero)
    );

    Shift_left_11_bit u_shift_left (
        .in(adder_out),
        .d(pe_out),
        .out(shift_left_out)
    );

    wire [9:0] final_frac;
    MUX_2_to_1_10bit u_mux_frac (
        .a(shift_left_out[9:0]),
        .b(adder_out[10:1]),
        .Sel(real_overflow_co),
        .out(final_frac)
    );

    wire [4:0] exp_add_out;
    wire       exp_add_co_unused;

    Adder_5_bit u_exp_adder (
        .a(Aexp),
        .b(5'b00000),
        .Cin(real_overflow_co),
        .out(exp_add_out),
        .Co(exp_add_co_unused)
    );

    wire [4:0] exp_sub_out;
    wire       exp_sub_Co;

    Sub_5_bit u_exp_sub (
        .a(Aexp),
        .b({1'b0, pe_out}),
        .d(exp_sub_out),
        .Co(exp_sub_Co)
    );

    wire [4:0] final_exp;
    MUX_2_to_1_5bit u_mux_exp (
        .a(exp_sub_out),
        .b(exp_add_out),
        .Sel(real_overflow_co),
        .out(final_exp)
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

    wire [15:0] pre_out = {Asign, final_exp, final_frac};

    MUX_2_to_1_16bit u_mux_out (
        .a(16'b0000_0000_0000_0000),
        .b(pre_out),
        .Sel(valid_out_sel),
        .out(out)
    );

endmodule