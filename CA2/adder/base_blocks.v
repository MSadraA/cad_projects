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