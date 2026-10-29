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