# Nonzero comparator test for double data hazard on BNE.
# t1 = 1; old t0 = 1; newest t0 = 0.
# Correct BNE is TAKEN; stale old t0=1 would make it NOT taken.
addi $t1, $zero, 1
nop
nop
nop
addi $t0, $zero, 1
addi $t0, $zero, 0
bne  $t0, $t1, bne_pass
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
