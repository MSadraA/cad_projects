# Nonzero comparator test for double data hazard on BEQ.
# t1 = 1; old t0 = 1; newest t0 = 0.
# Correct BEQ is NOT taken; stale old t0=1 would make it TAKEN.
addi $t1, $zero, 1
nop
nop
nop
addi $t0, $zero, 1
addi $t0, $zero, 0
beq  $t0, $t1, beq_fail
nop
addi $s0, $zero, 2
j test_end
nop
beq_fail:
addi $s0, $zero, 99
j test_end
nop
test_end:
halt
