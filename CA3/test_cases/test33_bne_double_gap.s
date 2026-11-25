# Test 33: two writes to same register, one NOP, then BNE.
# Old value=0, newest value=1. Correct BNE result is TAKEN; s0=2.
# If old value is selected, branch is not taken and s0=99.
addi $t0, $zero, 0
addi $t0, $zero, 1
nop
bne  $t0, $zero, bne_pass
nop
addi $s0, $zero, 99
j test_end
nop
bne_pass:
addi $s0, $zero, 2
j test_end
nop
test_end:
halt
