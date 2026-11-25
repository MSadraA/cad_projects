# Test Batch 1: Basic ALU and Memory Operations (Isolated)
# Setup registers
addi $t0, $zero, 15     # $t0 = 15
addi $t1, $zero, 10     # $t1 = 10
addi $t2, $zero, -5     # $t2 = -5
nop
nop
nop

# Test 1: ADD
add $s0, $t0, $t1       # $s0 = 25
nop
nop
nop

# Test 2: SUB
sub $s1, $t0, $t1       # $s1 = 5
nop
nop
nop

# Test 3: AND / OR
and $s2, $t0, $t1       # $s2 = 10
or  $s3, $t0, $t1       # $s3 = 15
nop
nop
nop

# Test 4: SLT
slt $s4, $t2, $t0       # $s4 = 1 (-5 < 15)
slt $s5, $t0, $t2       # $s5 = 0 (15 < -5)
nop
nop
nop

# Test 5: LUI
lui $s6, 0x1234         # $s6 = 0x12340000
nop
nop
nop

# Test 6: SW and LW
sw $s0, 12($zero)       # M[12] = 25
nop
nop
nop
lw $s7, 12($zero)       # $s7 = 25
nop
nop
nop

halt