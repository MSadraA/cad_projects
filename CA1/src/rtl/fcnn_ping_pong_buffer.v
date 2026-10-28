`default_nettype none
module fcnn_ping_pong_buffer #(
    parameter integer LANES=7, DEST_W=4
) (
    input wire clk, input wire rst,
    input wire wr_valid, output wire wr_ready,
    input wire [15:0] wr_data, input wire [DEST_W-1:0] wr_dest,
    input wire wr_last, input wire wr_group_last,
    output wire rd_valid, input wire rd_ready,
    output wire [15:0] rd_data, output wire [DEST_W-1:0] rd_dest,
    output wire rd_last,
    output wire [1:0] bank_full, output wire [1:0] bank_empty,
    output wire bank_select
);
    // Step 1: two physical banks. Pointer width includes the full sentinel.
    localparam integer PTR_W=$clog2(LANES+1);
    localparam integer SLOT_W=(LANES>1)?$clog2(LANES):1;
    reg [15:0] data0[0:LANES-1], data1[0:LANES-1];
    reg [DEST_W-1:0] dest0[0:LANES-1], dest1[0:LANES-1];
    reg last0[0:LANES-1], last1[0:LANES-1];
    reg end0[0:LANES-1], end1[0:LANES-1];
    reg [PTR_W-1:0] wp0,wp1,rp0,rp1,count0,count1;
    reg sealed0,sealed1,write_bank,read_bank;
    // Step 2: seal prevents reopening even a partially filled undrained bank.
    assign wr_ready=write_bank ? (!sealed1 && wp1<LANES) : (!sealed0 && wp0<LANES);
    assign rd_valid=read_bank ? (sealed1 && count1!=0) : (sealed0 && count0!=0);
    assign rd_data=read_bank ? data1[rp1[SLOT_W-1:0]] : data0[rp0[SLOT_W-1:0]];
    assign rd_dest=read_bank ? dest1[rp1[SLOT_W-1:0]] : dest0[rp0[SLOT_W-1:0]];
    assign rd_last=read_bank ? last1[rp1[SLOT_W-1:0]] : last0[rp0[SLOT_W-1:0]];
    assign bank_full={sealed1 || wp1==LANES,sealed0 || wp0==LANES};
    assign bank_empty={count1==0,count0==0};
    assign bank_select=write_bank;
    wire push0=wr_valid && wr_ready && !write_bank;
    wire push1=wr_valid && wr_ready && write_bank;
    wire pop0=rd_valid && rd_ready && !read_bank;
    wire pop1=rd_valid && rd_ready && read_bank;
    always @(posedge clk) begin
        if (rst) begin
            wp0<=0;wp1<=0;rp0<=0;rp1<=0;count0<=0;count1<=0;
            sealed0<=0;sealed1<=0;write_bank<=0;read_bank<=0;
        end else begin
            // Step 3: write and seal a group (including a short final group).
            if (push0) begin
                data0[wp0[SLOT_W-1:0]]<=wr_data; dest0[wp0[SLOT_W-1:0]]<=wr_dest;
                last0[wp0[SLOT_W-1:0]]<=wr_last; end0[wp0[SLOT_W-1:0]]<=wr_group_last;
                if (wr_group_last) begin sealed0<=1;wp0<=0;write_bank<=1;end
                else wp0<=wp0+1'b1;
            end
            if (push1) begin
                data1[wp1[SLOT_W-1:0]]<=wr_data; dest1[wp1[SLOT_W-1:0]]<=wr_dest;
                last1[wp1[SLOT_W-1:0]]<=wr_last; end1[wp1[SLOT_W-1:0]]<=wr_group_last;
                if (wr_group_last) begin sealed1<=1;wp1<=0;write_bank<=0;end
                else wp1<=wp1+1'b1;
            end
            // Step 4: read only a completed bank; release on its group terminator.
            if (pop0) begin
                if (end0[rp0[SLOT_W-1:0]]) begin sealed0<=0;rp0<=0;read_bank<=1;end
                else rp0<=rp0+1'b1;
            end
            if (pop1) begin
                if (end1[rp1[SLOT_W-1:0]]) begin sealed1<=0;rp1<=0;read_bank<=0;end
                else rp1<=rp1+1'b1;
            end
            // Step 5: simultaneous push/pop has a net occupancy change of zero.
            if (push0 && !pop0) count0<=count0+1'b1;
            else if (pop0 && !push0) count0<=count0-1'b1;
            if (push1 && !pop1) count1<=count1+1'b1;
            else if (pop1 && !push1) count1<=count1-1'b1;
            // synthesis translate_off
            if ((push0 && wp0==LANES-1 && !wr_group_last) ||
                (push1 && wp1==LANES-1 && !wr_group_last))
                begin $display("[FAIL] PING_PONG missing group terminator"); $finish; end
            // synthesis translate_on
        end
    end
endmodule
`default_nettype wire
