`timescale 1ns/1ps
module tb_actel_cells;
    reg [7:0] v;
    wire f1,f2;
    reg clk=0,clr=0;
    wire q1,q2;
    reg [7:0] sv;
    integer i,checks=0;
    reg expected1,expected2,expected_q1,expected_q2;
    c1 c1_dut(v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7],f1);
    c2 c2_dut(v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7],f2);
    s1 s1_dut(sv[0],sv[1],sv[2],sv[3],sv[4],sv[5],sv[6],clr,clk,q1);
    s2 s2_dut(sv[0],sv[1],sv[2],sv[3],sv[4],sv[5],sv[6],sv[7],clr,clk,q2);
    initial begin
        for(i=0;i<256;i=i+1) begin
            v=i;#1;
            expected1=(v[6]|v[7])?(v[5]?v[4]:v[3]):(v[2]?v[1]:v[0]);
            expected2=v[{(v[4]|v[5]),(v[6]&v[7])}];
            if(f1!==expected1 || f2!==expected2) $fatal(1,"Actel combinational truth table v=%h",v);
            checks=checks+2;
        end
        clr=1;#1;
        if(q1!==0 || q2!==0) $fatal(1,"Asynchronous primitive reset");
        clr=0;
        for(i=0;i<256;i=i+1) begin
            sv=i;#1;
            expected_q1=sv[{(sv[4]|sv[5]),1'b0}];
            expected_q2=sv[{(sv[4]|sv[5]),(sv[6]&sv[7])}];
            clk=1;#1;
            if(q1!==expected_q1 || q2!==expected_q2) $fatal(1,"Actel sequential truth table sv=%h",sv);
            clk=0;#1;
            checks=checks+2;
        end
        clr=1;#1;clk=1;#1;
        if(q1!==0 || q2!==0) $fatal(1,"Primitive reset priority");
        $display("[PASS] ACTEL_CELLS checks=%0d",checks+4);
        $finish;
    end
endmodule
