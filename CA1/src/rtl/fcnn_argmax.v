`default_nettype none
module fcnn_argmax #(parameter integer N_OUTPUTS=10) (
    logits,
    logits_valid,
    predicted_digit,
    argmax_valid
);
    localparam integer INDEX_W=(N_OUTPUTS>1)?$clog2(N_OUTPUTS):1;
    localparam integer LEAVES=2**$clog2(N_OUTPUTS);
    // Step 1: balanced tree size; local node wires avoid array feedback warnings.
    // Step 2: numerical FP16 order; first index wins ties and all-NaN inputs.

    // Port widths are declared after derived constants for ModelSim 2020.
    input wire [16*N_OUTPUTS-1:0] logits;
    input wire logits_valid;
    output wire [INDEX_W-1:0] predicted_digit;
    output wire argmax_valid;

    function keep_first;
        input [15:0] a,b;
        reg an,bn;
        begin
            an=(a[14:10]==5'h1f && a[9:0]!=0);
            bn=(b[14:10]==5'h1f && b[9:0]!=0);
            if (an || bn) keep_first=!an || bn;
            else if (a[14:0]==0 && b[14:0]==0) keep_first=1;
            else if (a[15]!=b[15]) keep_first=!a[15];
            else keep_first=a[15] ? a[14:0]<=b[14:0] : a[14:0]>=b[14:0];
        end
    endfunction
    genvar k;
    generate
        for (k=1;k<2*LEAVES;k=k+1) begin: tree
            wire [15:0] value;
            wire [INDEX_W-1:0] index;
            wire valid;
            if (k>=LEAVES) begin: leaf
                if (k-LEAVES<N_OUTPUTS) begin: present
                    assign value=logits[16*(k-LEAVES)+:16];
                    localparam [31:0] LEAF_INDEX=k-LEAVES;
                    assign index=LEAF_INDEX[INDEX_W-1:0];
                    assign valid=1;
                end else begin: padding
                    assign value=0;assign index=0;assign valid=0;
                end
            end else begin: branch
                wire left_wins=tree[2*k].valid && (!tree[2*k+1].valid ||
                    keep_first(tree[2*k].value,tree[2*k+1].value));
                assign value=left_wins ? tree[2*k].value : tree[2*k+1].value;
                assign index=left_wins ? tree[2*k].index : tree[2*k+1].index;
                assign valid=tree[2*k].valid || tree[2*k+1].valid;
            end
        end
    endgenerate
    // Step 3: validity gates prediction until the RF contains final logits.
    assign predicted_digit=logits_valid ? tree[1].index : {INDEX_W{1'b0}};
    assign argmax_valid=logits_valid;
endmodule
`default_nettype wire
