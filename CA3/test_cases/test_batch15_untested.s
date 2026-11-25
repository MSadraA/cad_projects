# Setup Memory: M[4] = 0x11223344
addi $t0, $zero, 0x3344
lui  $t1, 0x1122
or   $t0, $t1, $t0      # $t0 = 0x11223344
sw   $t0, 4($zero)
nop
nop

# T_NOR_OP
addi $t2, $zero, 0xFFFF
lui  $t3, 0xFFFF        # $t3 = 0xFFFF0000
nor  $s0, $t2, $t3      # Expected: ~(0x0000FFFF | 0xFFFF0000) = ~0xFFFFFFFF = 0x00000000
nop
nop

# T_SLTU_OP
addi $t4, $zero, -1     # $t4 = 0xFFFFFFFF
addi $t5, $zero, 1      # $t5 = 0x00000001
sltu $s1, $t4, $t5      # Expected: 0xFFFFFFFF < 0x00000001 (Unsigned) -> False (0)
slt  $s2, $t4, $t5      # Expected: -1 < 1 (Signed) -> True (1)
nop
nop

# T_MEM_OFFSET
# Base register = 8, Offset = -4. Address = 8 + (-4) = 4
addi $t6, $zero, 8
nop
nop
lw   $s3, -4($t6)       # Expected: $s3 = M[4] = 0x11223344
nop
halt