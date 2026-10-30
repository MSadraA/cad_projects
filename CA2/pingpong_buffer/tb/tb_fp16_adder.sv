`timescale 1ns/1ps
module tb_fp16_adder;
    reg [15:0] a,b;
    wire [15:0] result,result_hidden;
    reg [15:0] expected,unused_m,expected_hidden,unused_mh;
    integer fd,rc,checked=0;
    fcnn_fp16_adder dut(a,b,result);
    fcnn_fp16_adder #(.ZERO_FRAC_IS_ZERO(0)) hidden_one(a,b,result_hidden);
    initial begin
        if($test$plusargs("wave")) begin $dumpfile("build/adder.vcd");$dumpvars(0,tb_fp16_adder);end
        fd=$fopen("tb/vectors/fp_vectors.txt","r");
        if(!fd) $fatal(1,"Cannot open vectors; run scripts/generate_vectors.py");
        while(!$feof(fd)) begin
            rc=$fscanf(fd,"%h %h %h %h %h %h\n",a,b,expected,unused_m,expected_hidden,unused_mh);
            if(rc!=6) $fatal(1,"Malformed arithmetic vector at %0d",checked);
            #1;
            if(result!==expected || result_hidden!==expected_hidden)
                $fatal(1,"ADD a=%h b=%h got=%h expected=%h hidden=%h expected_hidden=%h row=%0d",a,b,result,expected,result_hidden,expected_hidden,checked);
            checked=checked+1;
        end
        $fclose(fd);
        if(checked<1000) $fatal(1,"Insufficient arithmetic vectors");
        $display("[PASS] ADD vectors=%0d policies=2 checks=%0d",checked,2*checked);
        $finish;
    end
endmodule
