# Batch 2: Immediate Extension and Shifts (Isolated)
# Setup initial values
addi $t0, $zero, -1     # $t0 = 0xFFFFFFFF
lui  $t1, 1             # $t1 = 0x00010000
nop
nop
nop

# Test 1: Immediate ALU Extensions
addi $s0, $zero, 0xFFFF # Expected $s0: 0xFFFFFFFF (Sign extended)
andi $s1, $t0, 0xFFFF   # Expected $s1: 0x0000FFFF (Zero extended)
ori  $s2, $zero, 0x8000 # Expected $s2: 0x00008000 (Zero extended)
xori $s3, $t0, 0x00FF   # Expected $s3: 0xFFFFFF00 (Zero extended)
nop
nop
nop

# Test 2: SLTIU Sign-Extension Quirk
# 0x00010000 < unsigned(SignExt(0xFFFF) = 0xFFFFFFFF) -> true (1)
sltiu $s4, $t1, 0xFFFF  # Expected $s4: 0x00000001
nop
nop
nop

# Test 3: Shifts (SLL, SRL, SRA)
addi $t2, $zero, -4     # $t2 = 0xFFFFFFFC
nop
nop
nop
sll  $s5, $t2, 2        # Expected $s5: 0xFFFFFFF0
srl  $s6, $t2, 2        # Expected $s6: 0x3FFFFFFF
sra  $s7, $t2, 2        # Expected $s7: 0xFFFFFFFF
nop
nop
nop
halt