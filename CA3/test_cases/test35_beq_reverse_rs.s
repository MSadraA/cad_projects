# Reverse-value double hazard on BEQ rs input.
# Old t0=1, newest t0=0. Correct BEQ is TAKEN; stale old value makes it NOT taken.
addi $t0, $zero, 1
addi $t0, $zero, 0
beq  $t0, $zero, beq_pass
nop
addi $s0, $zero, 99
j test_end
nop
beq_pass:
addi $s0, $zero, 2
j test_end
nop
test_end:
halt
