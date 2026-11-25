# Reverse-value double hazard on BNE rs input.
# Old t0=1, newest t0=0. Correct BNE is NOT taken; stale old value makes it taken.
addi $t0, $zero, 1
addi $t0, $zero, 0
bne  $t0, $zero, bne_fail
nop
addi $s0, $zero, 1
j test_end
nop
bne_fail:
addi $s0, $zero, 99
j test_end
nop
test_end:
halt
