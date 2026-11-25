addi $t0, $zero, jr_target
sw   $t0, 0($zero)
addi $t1, $zero, jr_bad
nop
nop
lw   $t1, 0($zero)
jr   $t1
addi $s0, $zero, 99
addi $s1, $zero, 99
jr_bad:
addi $s2, $zero, 1
j    jr_end
nop
jr_target:
addi $s2, $zero, 2
jr_end:
nop
halt
