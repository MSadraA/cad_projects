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

// 4. Routing & Logic
`timescale 1ns/1ps
`default_nettype none

`timescale 1ns/1ps
`default_nettype none

module ac_demux_1to2 (
    input  wire in,
    input  wire sel,
    output wire out0,
    output wire out1
);
    c1 u_out0 (
        .A0(in),   
        .A1(1'b0), 
        .SA(sel),
        .B0(1'b0), .B1(1'b0), .SB(1'b0),
        .S0(1'b0), .S1(1'b0),
        .f(out0)
    );

    c1 u_out1 (
        .A0(1'b0), 
        .A1(in),   
        .SA(sel),
        .B0(1'b0), .B1(1'b0), .SB(1'b0),
        .S0(1'b0), .S1(1'b0),
        .f(out1)
    );
endmodule
`default_nettype wire


`timescale 1ns/1ps
`default_nettype none

module ac_decoder_n #(
    parameter integer ADDR_W = 4
) (
    input  wire en,
    input  wire [ADDR_W-1:0] addr,
    output wire [(1<<ADDR_W)-1:0] out
);
    wire [(1<<(ADDR_W+1))-1:1] tree;
    
    assign tree[1] = en;

    genvar stage, node;
    generate
        for (stage = 0; stage < ADDR_W; stage = stage + 1) begin : gen_stage
            for (node = 0; node < (1 << stage); node = node + 1) begin : gen_node
                localparam parent_idx = (1 << stage) + node;
                localparam left_idx   = (1 << (stage + 1)) + (node * 2);
                localparam right_idx  = (1 << (stage + 1)) + (node * 2) + 1;

                ac_demux_1to2 u_demux (
                    .in(tree[parent_idx]),
                    .sel(addr[stage]),
                    .out0(tree[left_idx]),
                    .out1(tree[right_idx])
                );
            end
        end
    endgenerate

    genvar out_idx;
    generate
        for (out_idx = 0; out_idx < (1 << ADDR_W); out_idx = out_idx + 1) begin : gen_out
            assign out[out_idx] = tree[(1 << ADDR_W) + out_idx];
        end
    endgenerate

endmodule
`default_nettype wire

`timescale 1ns/1ps
`default_nettype none

module ac_mux_array_1bit #(
    parameter integer SEL_W = 3
)(
    input  wire [(1<<SEL_W)-1:0] in_data,
    input  wire [SEL_W-1:0] sel,
    output wire out_data
);
    wire [(1<<SEL_W)-1:0] nodes [0:SEL_W];
    
    assign nodes[0] = in_data;

    genvar s, i;
    generate
        for (s = 0; s < SEL_W; s = s + 2) begin : gen_stage
            localparam NUM_IN = (1 << (SEL_W - s));
            
            if (s + 1 < SEL_W) begin : use_mux4
                localparam NUM_OUT = NUM_IN / 4;
                for (i = 0; i < NUM_OUT; i = i + 1) begin : gen_mux4
                    ac_mux4 u_mux4 (
                        .a(nodes[s][4*i + 0]),
                        .b(nodes[s][4*i + 1]),
                        .c(nodes[s][4*i + 2]),
                        .d(nodes[s][4*i + 3]),
                        .s0(sel[s]),
                        .s1(sel[s+1]),
                        .y(nodes[s+2][i])
                    );
                end
            end else begin : use_mux2
                localparam NUM_OUT = NUM_IN / 2;
                for (i = 0; i < NUM_OUT; i = i + 1) begin : gen_mux2
                    ac_mux u_mux2 (
                        .a(nodes[s][2*i + 0]),
                        .b(nodes[s][2*i + 1]),
                        .s(sel[s]),
                        .y(nodes[s+1][i])
                    );
                end
            end
        end
    endgenerate

    assign out_data = nodes[SEL_W][0];

endmodule
`default_nettype wire


`timescale 1ns/1ps
`default_nettype none

module ac_mux_array_n #(
    parameter integer DATA_W = 16,
    parameter integer CHANNELS = 7,
    parameter integer SEL_W = 3
) (
    input  wire [DATA_W*CHANNELS-1:0] in_data,
    input  wire [SEL_W-1:0] sel,
    output wire [DATA_W-1:0] out_data
);
    localparam TOTAL_CHANNELS = 1 << SEL_W;
    wire [DATA_W*TOTAL_CHANNELS-1:0] padded_in;

    genvar c;
    generate
        for (c = 0; c < TOTAL_CHANNELS; c = c + 1) begin : gen_pad
            if (c < CHANNELS) begin : has_data
                assign padded_in[c*DATA_W +: DATA_W] = in_data[c*DATA_W +: DATA_W];
            end else begin : no_data
                assign padded_in[c*DATA_W +: DATA_W] = {DATA_W{1'b0}};
            end
        end
    endgenerate

    genvar w;
    generate
        for (w = 0; w < DATA_W; w = w + 1) begin : gen_bit_slice
            wire [TOTAL_CHANNELS-1:0] bit_in;
            genvar k;
            for (k = 0; k < TOTAL_CHANNELS; k = k + 1) begin : gen_gather
                assign bit_in[k] = padded_in[k*DATA_W + w];
            end

            ac_mux_array_1bit #(
                .SEL_W(SEL_W)
            ) u_mux_tree (
                .in_data(bit_in),
                .sel(sel),
                .out_data(out_data[w])
            );
        end
    endgenerate

endmodule
`default_nettype wire

// 3.Storage Elements
`timescale 1ns/1ps
`default_nettype none

module ac_dffe_n #(
    parameter integer W = 1
) (
    input  wire clk,
    input  wire rst,
    input  wire en,
    input  wire [W-1:0] d,
    output wire [W-1:0] q
);
    genvar i;
    generate
        for (i = 0; i < W; i = i + 1) begin : gen_dff
            ac_dffe u_dff (
            .clk(clk),
            .rst(rst),
            .en(en),
            .d(d[i]),
            .q(q[i])
            );
        end
    endgenerate

endmodule
`default_nettype wire

timescale 1ns/1ps default_nettype none

module ac_regfile #(
    parameter integer DATA_W = 16,
    parameter integer DEPTH = 10,
    parameter integer ADDR_W = 4
) (
    input  wire clk,
    input  wire rst,
    input  wire wr_en,
    input  wire [ADDR_W-1:0] wr_addr,
    input  wire [DATA_W-1:0] wr_data,
    input  wire [ADDR_W-1:0] rd_addr,
    output wire [DATA_W-1:0] rd_data,
    output wire [DATA_W*DEPTH-1:0] parallel_out
);
    wire [(1<<ADDR_W)-1:0] reg_en;

    ac_decoder_n #(
        .ADDR_W(ADDR_W)
    ) u_decoder (
        .en(wr_en),
        .addr(wr_addr),
        .out(reg_en)
    );

    genvar i;
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : gen_regs
            ac_dffe_n #(
                .W(DATA_W)
            ) u_reg (
                .clk(clk),
                .rst(rst),
                .en(reg_en[i]),
                .d(wr_data),
                .q(parallel_out[i*DATA_W +: DATA_W])
            );
        end
    endgenerate

    ac_mux_array_n #(
        .DATA_W(DATA_W),
        .CHANNELS(DEPTH),
        .SEL_W(ADDR_W)
    ) u_read_mux (
        .in_data(parallel_out),
        .sel(rd_addr),
        .out_data(rd_data)
    );

endmodule
`default_nettype wire