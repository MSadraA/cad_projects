# Test 31: single ALU producer, one NOP, then BNE.
# Expected s0=2 (taken).
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
