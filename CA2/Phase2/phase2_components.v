`timescale 1ns/1ps
`default_nettype none

// 1.Arithmetic Components
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


module ac_div_mod_7 #(
    parameter integer W = 32
) (
    input  wire [W-1:0] a,
    output wire [W-1:0] q,  
    output wire [2:0]   r   
);
    wire [2:0] rem_chain [W:0];

    assign rem_chain[W] = 3'b000;

    genvar i;
    generate
        for (i = W - 1; i >= 0; i = i - 1) begin : stage
            
            wire [3:0] v;
            assign v = {rem_chain[i+1], a[i]};

            wire and_3;
            ac_and3 u_and3 (
                .a(v[0]),
                .b(v[1]),
                .c(v[2]),
                .y(and_3)
            );
            
            ac_or u_or (
                .a(v[3]),
                .b(and_3),
                .y(q[i]) 
            );

            wire [3:0] sub_val;
            wire unused_co;
            ac_add #(
                .W(4)
            ) u_sub (
                .a(v),
                .b(4'b1001), 
                .ci(1'b0),
                .s(sub_val),
                .co(unused_co)
            );

            ac_muxv #(
                .W(3)
            ) u_mux (
                .a(v[2:0]),       
                .b(sub_val[2:0]), 
                .s(q[i]),        
                .y(rem_chain[i])
            );
        end
    endgenerate

    assign r = rem_chain[0];

endmodule
`default_nettype wire


// 2.Comparison Components
`timescale 1ns/1ps
`default_nettype none

module ac_cmp_eq_n #(
    parameter integer W = 1
) (
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    output wire eq
);
    wire [W-1:0] diff;
    wire [W-1:0] match;
    
    genvar i;
    generate
        for (i = 0; i < W; i = i + 1) begin : gen_cmp
            ac_xor u_xor (
                .a(a[i]),
                .b(b[i]),
                .y(diff[i])
            );
            
            ac_not u_not (
                .a(diff[i]),
                .y(match[i])
            );
        end
    endgenerate
    
    ac_reduce_and #(
        .W(W)
    ) u_red_and (
        .a(match),
        .y(eq)
    );

endmodule
`default_nettype wire


`timescale 1ns/1ps
`default_nettype none

module ac_cmp_lt_n #(
    parameter integer W = 1
) (
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    output wire lt
);
    wire ge;
    
    ac_ge #(
        .W(W)
    ) u_ge (
        .a(a),
        .b(b),
        .ge(ge)
    );
    
    ac_not u_not (
        .a(ge),
        .y(lt)
    );

endmodule
`default_nettype wire