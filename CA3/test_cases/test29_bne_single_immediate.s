# Test 29: single ALU producer immediately followed by BNE.
# t0 becomes 1. BNE t0,zero must be taken. Expected s0=2.
addi $t0, $zero, 1
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
