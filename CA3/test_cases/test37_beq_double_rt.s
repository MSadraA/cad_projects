# Double hazard on BEQ rt input (second comparator operand).
# Old t0=0, newest t0=1. Correct BEQ is NOT taken; stale old value makes it taken.
addi $t0, $zero, 0
addi $t0, $zero, 1
beq  $zero, $t0, beq_fail
nop
addi $s0, $zero, 1
j test_end
nop
beq_fail:
addi $s0, $zero, 99
j test_end
nop
test_end:
halt
