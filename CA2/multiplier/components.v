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