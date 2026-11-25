# Setup Memory: M[0]=10, M[4]=20
addi $t0, $zero, 10
sw   $t0, 0($zero)
addi $t1, $zero, 20
sw   $t1, 4($zero)
nop
nop

# T_LD_USE_BEQ_RT
addi $t2, $zero, 99
lw   $t2, 0($zero)      # New = 10
beq  $t0, $t2, pass1    # 10 == 10 -> Should Stall and Branch
nop
addi $s0, $zero, 1      # FAIL (Reads 99 -> Not Taken)
j end1
nop
pass1:
addi $s0, $zero, 2      # PASS
end1:
nop

# T_LD_USE_BNE_RT
addi $t3, $zero, 10
lw   $t3, 4($zero)      # New = 20
bne  $t0, $t3, pass2    # 10 != 20 -> Should Stall and Branch
nop
addi $s1, $zero, 1      # FAIL (Reads 10 -> Not Taken)
j end2
nop
pass2:
addi $s1, $zero, 2      # PASS
end2:
nop
halt