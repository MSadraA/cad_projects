# Test 32: two writes to same register, one NOP, then BEQ.
# Old value=0, newest value=1. Correct BEQ result is NOT taken; s0=1.
# If old value is selected, branch is taken and s0=99.
addi $t0, $zero, 0
addi $t0, $zero, 1
nop
beq  $t0, $zero, beq_fail
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
