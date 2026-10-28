`timescale 1ns/1ps
`default_nettype none
module tb_sram #(
    parameter integer N_INPUTS=784,N_HIDDEN=8,N_OUTPUTS=10,LANES=7,SRAM_LATENCY=7
);
    localparam integer R1=(N_INPUTS+LANES-1)/LANES;
    localparam integer R2=(N_HIDDEN*N_OUTPUTS+LANES-1)/LANES;
    localparam integer DEPTH=N_HIDDEN*R1+R2;
    localparam integer AW=(DEPTH>1)?$clog2(DEPTH):1;
    localparam integer IW=(R1>1)?$clog2(R1):1;
    localparam integer HW=(N_HIDDEN>1)?$clog2(N_HIDDEN):1;
    localparam integer RW=$clog2(((R1>R2)?R1:R2)+1);
    localparam integer MW=1+HW+RW;
    reg clk=0,rst=1,wreq=0,ireq=0;
    always #5 clk=~clk;
    reg [AW-1:0] wa=0;
    reg [IW-1:0] ia=0;
    reg [MW-1:0] wm=0,im=0;
    wire wvalid,ivalid;
    wire [16*LANES-1:0] wd,id;
    wire [MW-1:0] wtag,itag;
    reg [15:0] w1[0:N_INPUTS*N_HIDDEN-1],w2[0:N_HIDDEN*N_OUTPUTS-1],pixels[0:N_INPUTS-1];
    integer cycle=0,sentw=0,senti=0,gotw=0,goti=0,lane,row,neuron,feature,flat,destination;
    integer issuedw[0:DEPTH-1], issuedi[0:R1-1];
    integer seed=209,flush_check=0;
    reg [15:0] expected;
    fcnn_row_sram #(.N_INPUTS(N_INPUTS),.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS),.LANES(LANES),
        .SRAM_LATENCY(SRAM_LATENCY),.SOURCE_KIND(1)) weights (
        .clk(clk),.rst(rst),.req_valid(wreq),.req_addr(wa),.req_meta(wm),.row_valid(wvalid),.row_data(wd),.row_meta(wtag));
    fcnn_row_sram #(.N_INPUTS(N_INPUTS),.N_HIDDEN(N_HIDDEN),.N_OUTPUTS(N_OUTPUTS),.LANES(LANES),
        .SRAM_LATENCY(SRAM_LATENCY),.SOURCE_KIND(0),.INIT_FILE("test_image.mem")) image (
        .clk(clk),.rst(rst),.req_valid(ireq),.req_addr(ia),.req_meta(im),.row_valid(ivalid),.row_data(id),.row_meta(itag));
    // Responses are sampled BEFORE NBA. Accepted at E, observed at E+latency.
    always @(posedge clk) begin
        cycle=cycle+1;
        if (!rst && !flush_check) begin
            if (wreq) begin issuedw[wm]=cycle;sentw=sentw+1;end
            if (ireq) begin issuedi[im]=cycle;senti=senti+1;end
            if (wvalid) begin
                if (cycle-issuedw[wtag]!=SRAM_LATENCY || wtag!=gotw)
                    begin $display("[FAIL] SRAM weight latency/order");$finish;end
                row=wtag;
                for (lane=0;lane<LANES;lane=lane+1) begin
                    expected=0;
                    if (row<N_HIDDEN*R1) begin
                        neuron=row/R1;feature=(row%R1)*LANES+lane;
                        if (feature<N_INPUTS) expected=w1[neuron*N_INPUTS+feature];
                    end else begin
                        flat=(row-N_HIDDEN*R1)*LANES+lane;
                        if (flat<N_HIDDEN*N_OUTPUTS) begin
                            if (flat<N_OUTPUTS*(N_HIDDEN-1)) begin
                                destination=flat/((N_HIDDEN>1)?N_HIDDEN-1:1);
                                feature=flat%((N_HIDDEN>1)?N_HIDDEN-1:1);
                            end else begin destination=flat-N_OUTPUTS*(N_HIDDEN-1);feature=N_HIDDEN-1;end
                            expected=w2[destination*N_HIDDEN+feature];
                        end
                    end
                    if (wd[16*lane+:16]!==expected)
                        begin $display("[FAIL] SRAM weight row=%0d lane=%0d",row,lane);$finish;end
                end
                gotw=gotw+1;
            end
            if (ivalid) begin
                if (cycle-issuedi[itag]!=SRAM_LATENCY || itag!=goti)
                    begin $display("[FAIL] SRAM input latency/order");$finish;end
                for (lane=0;lane<LANES;lane=lane+1) begin
                    feature=itag*LANES+lane;
                    expected=(feature<N_INPUTS)?pixels[feature]:16'd0;
                    if (id[16*lane+:16]!==expected)
                        begin $display("[FAIL] SRAM input row=%0d lane=%0d",itag,lane);$finish;end
                end
                goti=goti+1;
            end
        end
    end
    initial begin
        $readmemh("fc1_weights.mem",w1);$readmemh("fc2_weights.mem",w2);$readmemh("test_image.mem",pixels);
        repeat(3) @(negedge clk);rst=0;
        while (sentw<DEPTH || senti<R1) begin
            @(negedge clk);
            seed=(seed*1664525+1013904223) & 32'h7fffffff;
            wreq=sentw<DEPTH && seed%4!=0;wa=sentw;wm=sentw;
            ireq=senti<R1 && seed%3!=0;ia=senti;im=senti;
        end
        @(negedge clk);wreq=0;ireq=0;
        repeat(SRAM_LATENCY+2) @(negedge clk);
        if (gotw!=DEPTH || goti!=R1) begin $display("[FAIL] SRAM response counts");$finish;end
        // Reset must invalidate a request that is still in the latency pipeline.
        flush_check=1;wreq=1;ireq=1;wa=0;ia=0;
        @(negedge clk);wreq=0;ireq=0;rst=1;
        @(negedge clk);rst=0;
        repeat(SRAM_LATENCY+2) begin
            @(negedge clk);
            if (wvalid || ivalid) begin $display("[FAIL] SRAM reset flush");$finish;end
        end
        $display("[PASS] SRAM weight_rows=%0d image_rows=%0d lanes=%0d latency=%0d",gotw,goti,LANES,SRAM_LATENCY);
        $finish;
    end
endmodule
`default_nettype wire
