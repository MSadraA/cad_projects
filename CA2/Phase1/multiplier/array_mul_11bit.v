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
