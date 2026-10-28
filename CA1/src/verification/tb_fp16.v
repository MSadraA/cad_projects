`timescale 1ns/1ps
`default_nettype none
module tb_fp16;
    reg [15:0] a,b;
    wire [15:0] sum,product,activation;
    reg [15:0] expected_sum,expected_product,expected_relu;
    integer fd,status,count=0,failures=0;
    reg [1023:0] vector_file;
    fcnn_fp16_adder add_dut(.a(a),.b(b),.result(sum));
    fcnn_fp16_multiplier mul_dut(.a(a),.b(b),.result(product));
    fcnn_relu_fp16 relu_dut(.x(a),.y(activation));
    initial begin
        if (!$value$plusargs("vectors=%s",vector_file)) vector_file="fp16_vectors.txt";
        fd=$fopen(vector_file,"r");
        if (!fd) begin $display("[FAIL] FP16 vector file unavailable");$finish;end
        while (!$feof(fd)) begin
            status=$fscanf(fd,"%h %h %h %h %h\n",a,b,expected_sum,expected_product,expected_relu);
            if (status==5) begin
                #1;
                if (sum!==expected_sum || product!==expected_product || activation!==expected_relu) begin
                    $display("[FAIL] FP16 a=%h b=%h add=%h/%h mul=%h/%h relu=%h/%h",a,b,sum,expected_sum,product,expected_product,activation,expected_relu);
                    failures=failures+1;
                    if (failures==10) $finish;
                end
                count=count+1;
            end else if (status!=-1) begin $display("[FAIL] malformed FP16 vector");$finish;end
        end
        $fclose(fd);
        if (failures==0 && count>0) $display("[PASS] FP16 vectors=%0d comparisons=%0d",count,3*count);
        else $display("[FAIL] FP16 failures=%0d count=%0d",failures,count);
        $finish;
    end
endmodule
`default_nettype wire
