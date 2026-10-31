`timescale 1ns/1ps
`default_nettype none

module ac_inc_n #(
    parameter integer W = 1
) (
    input  wire [W-1:0] a,
    output wire [W-1:0] y
);
    wire [W:0] c;

    ac_not u_not_bit0 (
        .a(a[0]),
        .y(y[0])
    );

    genvar i;
    generate
        if (W > 1) begin : gen_chain
            for (i = 1; i < W; i = i + 1) begin : gen_bits
                if (i == 1) begin : gen_first_ha
                    ac_ha u_ha (
                        .a(a[i]),
                        .b(a[0]),
                        .s(y[i]),
                        .co(c[i+1])
                    );
                end else begin : gen_rest_ha
                    ac_ha u_ha (
                        .a(a[i]),
                        .b(c[i]),
                        .s(y[i]),
                        .co(c[i+1])
                    );
                end
            end
        end
    endgenerate

endmodule
`default_nettype wire

module ac_dec_n #(
    parameter integer W = 1
) (
    input  wire [W-1:0] a,
    output wire [W-1:0] y
);
    wire unused_co;

    ac_add #(
        .W(W)
    ) u_add (
        .a(a),
        .b({W{1'b1}}),
        .ci(1'b0),
        .s(y),
        .co(unused_co)
    );

endmodule
`default_nettype wire


module ac_mult_const_7 #(
    parameter integer W = 32
) (
    input  wire [W-1:0] a,
    output wire [W+2:0] y
);
    wire [W-1:0] not_a;

    genvar i;
    generate
        for (i = 0; i < W; i = i + 1) begin : gen_not_a
            ac_not u_inv (
                .a(a[i]),
                .y(not_a[i])
            );
        end
    endgenerate

    wire unused_co;

    ac_add #(
        .W(W + 3)
    ) u_add (
        .a({a, 3'b000}),
        .b({3'b111, not_a}), 
        .ci(1'b1),
        .s(y),
        .co(unused_co)
    );

endmodule
`default_nettype wire

module ac_mult_const_112 #(
    parameter integer W = 32
) (
    input  wire [W-1:0] a,
    output wire [W+6:0] y
);
    wire [W-1:0] not_a;

    genvar i;
    generate
        for (i = 0; i < W; i = i + 1) begin : gen_not_a
            ac_not u_inv (
                .a(a[i]),
                .y(not_a[i])
            );
        end
    endgenerate

    wire unused_co;

    ac_add #(
        .W(W + 7)
    ) u_add (
        .a({a, 7'b0000000}),
        .b({3'b111, not_a, 4'b1111}), 
        .ci(1'b1),
        .s(y),
        .co(unused_co)
    );

endmodule
`default_nettype wire