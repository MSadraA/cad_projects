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
