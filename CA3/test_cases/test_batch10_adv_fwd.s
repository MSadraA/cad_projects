# Setup Memory M[0]=4
addi $t0, $zero, 4
sw   $t0, 0($zero)
nop
nop

# T_FWD_MEM_LW_RS (LW to ALU rs, distance 2)
lw   $t1, 0($zero)
nop
add  $t2, $t1, $zero

# T_FWD_MEM_LW_RT (LW to ALU rt, distance 2)
lw   $t3, 0($zero)
nop
add  $t4, $zero, $t3
nop
nop

# T_FWD_SW_DATA (ALU to SW data 'rt')
addi $t5, $zero, 8
sw   $t5, 4($zero)
nop
nop

# T_FWD_SW_ADDR (ALU to SW base 'rs')
addi $t6, $zero, 8
sw   $zero, 0($t6)
nop
nop

# T_FWD_MIXED (Mixed operands from different pipeline stages)
addi $t7, $zero, 1
nop
addi $t8, $zero, 2
add  $t9, $t7, $t8
nop
nop
halt