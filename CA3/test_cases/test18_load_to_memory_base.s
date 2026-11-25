addi $t0, $zero, 4
sw   $t0, 0($zero)
addi $t0, $zero, 16
sw   $t0, 4($zero)
addi $t0, $zero, 68
sw   $t0, 16($zero)
addi $t0, $zero, 136
sw   $t0, 32($zero)
addi $t0, $zero, 48
sw   $t0, 8($zero)
sw   $zero, 64($zero)

addi $t1, $zero, 16
lw   $t1, 0($zero)
lw   $s0, 0($t1)

addi $t2, $zero, 64
addi $t3, $zero, 4660
lw   $t2, 8($zero)
sw   $t3, 0($t2)
nop
nop
nop
lw   $s1, 48($zero)
lw   $s2, 64($zero)
halt
