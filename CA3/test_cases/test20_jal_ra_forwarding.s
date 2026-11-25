jal  jal_target
addi $s1, $zero, 99
addi $s2, $zero, 99
jal_target:
add  $s0, $ra, $zero
halt
