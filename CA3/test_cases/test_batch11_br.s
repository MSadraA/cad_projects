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
beq  $t0, $t2, pass1    # 10 == 10 (Should Stall, read 10 -> Taken)
nop
addi $s0, $zero, 1      # FAIL (If no stall, reads 99 -> Not Taken)
j end1
nop
pass1:
addi $s0, $zero, 2      # PASS
end1:
nop
nop

# T_LD_USE_BNE_RT
addi $t3, $zero, 99
lw   $t3, 4($zero)      # New = 20
bne  $t0, $t3, pass2    # 10 != 20 (Should Stall, read 20 -> Taken)
nop
addi $s1, $zero, 1      # FAIL (If no stall, reads 99 -> Also Taken! Wait.)
# Correction: If no stall, 10 != 99 (Taken). If stall, 10 != 20 (Taken). Both branch!
# We need to make the branch logic FAIL if it uses the OLD value.