`timescale 1ns/1ps
module tb_building_blocks;
    reg [4:0] a5,b5;
    wire ge;
    reg [12:0] n_in;
    reg [4:0] shift;
    wire [12:0] shifted,norm;
    wire [3:0] nshift;
    wire nz;
    reg fa,fb,fc;
    wire fs,fco;
    integer i,j,k,lead,expected,checks=0;
    reg [12:0] reference_shift;
    ac_ge #(.W(5)) cmp(a5,b5,ge);
    ac_fa full_adder(fa,fb,fc,fs,fco);
    ac_rshift_jam13 align(n_in,shift,shifted);
    ac_normalize13 normalizer(n_in,norm,nshift,nz);
    initial begin
        for(i=0;i<8;i=i+1) begin
            {fa,fb,fc}=i;#1;
            if({fco,fs}!==({1'b0,fa}+{1'b0,fb}+{1'b0,fc})) $fatal(1,"Full adder");
            checks=checks+1;
        end
        for(i=0;i<32;i=i+1) for(j=0;j<32;j=j+1) begin
            a5=i;b5=j;#1;
            if(ge!==(i>=j)) $fatal(1,"Comparator a=%0d b=%0d",i,j);
            checks=checks+1;
        end
        for(i=0;i<8192;i=i+1) begin
            n_in=i;#1;
            lead=0;
            if(i!=0) begin
                expected=i;
                while(expected<4096) begin expected=expected*2;lead=lead+1;end
                if(nshift!==lead[3:0] || norm[11:2]!==((expected>>2)&1023) || nz!==1'b1)
                    $fatal(1,"Normalizer a=%h shift=%d expected_shift=%d got=%h expected=%h",n_in,nshift,lead,norm,expected);
            end else if(nz!==1'b0) $fatal(1,"Normalizer zero");
            checks=checks+1;
        end
        for(i=0;i<1024;i=i+1) for(j=0;j<32;j=j+1) begin
            n_in=(1024+i)*4;shift=j;#1;
            reference_shift=n_in>>j;
            for(k=0;k<j;k=k+1) if(k<13 && n_in[k]) reference_shift[0]=1'b1;
            if(shifted!==reference_shift) $fatal(1,"Alignment a=%h shift=%0d got=%h expected=%h",n_in,j,shifted,reference_shift);
            checks=checks+1;
        end
        $display("[PASS] BUILDING_BLOCKS checks=%0d",checks);
        $finish;
    end
endmodule
