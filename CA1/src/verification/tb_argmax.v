`timescale 1ns/1ps
`default_nettype none
module tb_argmax #(parameter integer N_OUTPUTS=10);
    localparam integer INDEX_W=(N_OUTPUTS>1)?$clog2(N_OUTPUTS):1;
    reg [16*N_OUTPUTS-1:0] logits;
    reg valid=0;
    wire [INDEX_W-1:0] digit;
    wire argmax_valid;
    integer fd,status,expected,count=0;
    reg [1023:0] vector_file;
    fcnn_argmax #(.N_OUTPUTS(N_OUTPUTS)) dut(.logits(logits),.logits_valid(valid),.predicted_digit(digit),.argmax_valid(argmax_valid));
    initial begin
        if (!$value$plusargs("vectors=%s",vector_file)) vector_file="argmax_vectors.txt";
        fd=$fopen(vector_file,"r");
        if (!fd) begin $display("[FAIL] argmax file unavailable");$finish;end
        logits=0;#1;
        if (argmax_valid!==0 || digit!==0) begin $display("[FAIL] argmax invalid gating");$finish;end
        valid=1;
        while (!$feof(fd)) begin
            status=$fscanf(fd,"%h %d\n",logits,expected);
            if (status==2) begin
                #1;
                if (argmax_valid!==1 || digit!==expected)
                    begin $display("[FAIL] argmax count=%0d got=%0d expected=%0d",count,digit,expected);$finish;end
                count=count+1;
            end else if (status!=-1) begin $display("[FAIL] malformed argmax vector");$finish;end
        end
        $fclose(fd);
        if (count>0) $display("[PASS] ARGMAX outputs=%0d vectors=%0d",N_OUTPUTS,count);
        else $display("[FAIL] ARGMAX empty vectors");
        $finish;
    end
endmodule
`default_nettype wire
