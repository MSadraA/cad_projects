# BATCH 22: Uncovered ISA corner cases
# 1. R-type XOR (not XORI)
addi $t0, $zero, 0x1357
addi $t1, $zero, 0x0F0F
nop
nop
xor  $s0, $t0, $t1       # Expected 0x00001C58
nop
nop

# 2. Variable shift amount must use rs[4:0]; 34 means shift by 2
addi $t2, $zero, 34
addi $t3, $zero, -4
nop
nop
sllv $s1, $t3, $t2       # Expected 0xFFFFFFF0
srlv $s2, $t3, $t2       # Expected 0x3FFFFFFF
srav $s3, $t3, $t2       # Expected 0xFFFFFFFF
nop
nop

# 3. ADDIU with nonzero base and negative immediate
lui   $t4, 0x1234
nop
nop
addiu $s4, $t4, -1       # Expected 0x1233FFFF

# 4. SUBU with ordinary non-overflowing operands
addi  $t5, $zero, 20
addi  $t6, $zero, 7
nop
nop
subu  $s5, $t5, $t6      # Expected 13

halt
