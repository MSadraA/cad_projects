# Test 23A: immediate LW -> JR dependency
# M[0] receives the address of jr_pass.
# The old value in $t1 points to jr_fail.
# Correct behavior: JR must use the newly loaded address and set $s0 = 2.

addi $t0, $zero, jr_pass
sw   $t0, 0($zero)
addi $t1, $zero, jr_fail
nop
nop
lw   $t1, 0($zero)
jr   $t1
addi $s7, $zero, 99       # Must be flushed

jr_fail:
addi $s0, $zero, 1
j    test_end
nop

jr_pass:
addi $s0, $zero, 2
j    test_end
nop

test_end:
halt
