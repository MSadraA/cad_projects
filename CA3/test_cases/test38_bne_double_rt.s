# Double hazard on BNE rt input (second comparator operand).
# Old t0=0, newest t0=1. Correct BNE is TAKEN; stale old value makes it not taken.
addi $t0, $zero, 0
addi $t0, $zero, 1
bne  $zero, $t0, bne_pass
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
