# Test 30: single ALU producer, one NOP, then BEQ.
# Expected s0=1 (not taken).
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
