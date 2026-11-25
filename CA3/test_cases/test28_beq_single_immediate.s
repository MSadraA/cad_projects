# Test 28: single ALU producer immediately followed by BEQ.
# t0 becomes 1. BEQ t0,zero must NOT be taken. Expected s0=1.
addi $t0, $zero, 1
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
