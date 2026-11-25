# BATCH 21: JR operand timing isolation
# Case 1: LW -> JR (immediate dependency)
addi $t0, $zero, jr1_new
sw   $t0, 0($zero)
addi $t1, $zero, jr1_old
nop
nop
lw   $t1, 0($zero)
jr   $t1
addi $s7, $zero, 99
jr1_old:
addi $s0, $zero, 1
j case2_setup
nop
jr1_new:
addi $s0, $zero, 2
j case2_setup
nop

# Case 2: LW -> NOP -> JR (one-cycle separation)
case2_setup:
addi $t0, $zero, jr2_new
sw   $t0, 4($zero)
addi $t2, $zero, jr2_old
nop
nop
lw   $t2, 4($zero)
nop
jr   $t2
addi $s7, $zero, 99
jr2_old:
addi $s1, $zero, 1
j case3_setup
nop
jr2_new:
addi $s1, $zero, 2
j case3_setup
nop

# Case 3: ADDI -> one independent instruction -> JR
case3_setup:
addi $t3, $zero, jr3_old
nop
addi $t3, $zero, jr3_new
nop
jr   $t3
addi $s7, $zero, 99
jr3_old:
addi $s2, $zero, 1
j finish
nop
jr3_new:
addi $s2, $zero, 2
j finish
nop

finish:
halt
