# Test 23C: control test for ordinary immediate LW -> ALU dependency.
# M[0] = 44; old $t1 = 7. The immediate ADDIU must consume 44.
# Expected: $t1 = 44 and $s0 = 45.

addi $t0, $zero, 44
sw   $t0, 0($zero)
addi $t1, $zero, 7
nop
nop
lw   $t1, 0($zero)
addiu $s0, $t1, 1
halt
