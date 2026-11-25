# T_LUI_MASK
addi $t0, $zero, -1     # $t0 = 0xFFFFFFFF
lui  $t0, 0xAAAA        # Expected: 0xAAAA0000
nop
nop

# T_ADDIU_EXT
# Standard MIPS requires ADDIU to sign-extend the immediate, just like ADDI.
addi  $t1, $zero, 0xFFFF # Expected: 0xFFFFFFFF
addiu $t2, $zero, 0xFFFF # Expected: 0xFFFFFFFF
nop
nop

# T_ADD_OVF & T_ADDU_OVF
# M[0] = 0x7FFFFFFF (Max Positive 32-bit signed)
lui  $t3, 0x7FFF
ori  $t3, $t3, 0xFFFF
addi $t4, $zero, 1
add  $t5, $t3, $t4      # Expected: 0x80000000 (No trap)
addu $t6, $t3, $t4      # Expected: 0x80000000
nop
nop

# T_SUB_OVF & T_SUBU_OVF
# M[1] = 0x80000000 (Max Negative 32-bit signed)
lui  $t7, 0x8000
sub  $s0, $t7, $t4      # Expected: 0x7FFFFFFF (No trap)
subu $s1, $t7, $t4      # Expected: 0x7FFFFFFF
nop
nop
halt