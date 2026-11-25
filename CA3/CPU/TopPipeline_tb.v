`timescale 1ns/1ps
module TopPipeline_tb;
  reg clk = 0;
  reg rst = 1;

  reg [31:0] shadow_imem [0:1023];
  reg [31:0] shadow_dmem [0:1023];
  reg [31:0] shadow_registerFile [0:31];

  TopPipeline dut (
    .clk(clk),
    .rst(rst)
  );

  always #5 clk = ~clk;
  initial begin
    #12 rst = 0;
    #99999 $finish;
  end
endmodule
