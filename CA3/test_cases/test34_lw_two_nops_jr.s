# Test 34: control for LW -> NOP -> NOP -> JR.
# M[0] is initialized by SW to jr_pass. Old t1 points to jr_fail.
# With two NOPs after LW, expected JR target is jr_pass and s0=2.
addi $t0, $zero, jr_pass
sw   $t0, 0($zero)
addi $t1, $zero, jr_fail
nop
nop
lw   $t1, 0($zero)
nop
nop
jr   $t1
addi $s7, $zero, 99
jr_fail:
addi $s0, $zero, 1
j test_end
nop
jr_pass:
addi $s0, $zero, 2
j test_end
nop
test_end:
halt
