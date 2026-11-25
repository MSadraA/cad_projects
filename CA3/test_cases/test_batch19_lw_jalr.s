# BATCH 19: Scope of Bug 5 on JALR (LW -> NOP -> JALR vs. Immediate LW -> JALR)

# ---------------------------------------------------------
# 1. Control Test: LW -> NOP -> JALR
# Target marker: $s1 (R17), Link register: $s2 (R18)
# Expected target behavior: jumps to jalr2_pass ($s1 = 2)
# ---------------------------------------------------------
addi $t0, $zero, jalr2_pass
sw   $t0, 4($zero)
addi $t2, $zero, jalr2_old
nop
nop
lw   $t2, 4($zero)
nop
jalr $s2, $t2
addi $s1, $zero, 1
jalr2_old:
addi $s1, $zero, 99
j    jalr2_done
jalr2_pass:
addi $s1, $zero, 2
jalr2_done:
nop
nop

# ---------------------------------------------------------
# 2. Immediate Dependency: LW -> JALR with Address Trap at 104 (0x68)
# Target marker: $s0 (R16), Link register: $s3 (R19)
# - If JALR uses loaded memory value (jalr1_pass = 0x60): $s0 = 2
# - If JALR uses old register value (jalr1_old = 0x58):   $s0 = 99 (0x63)
# - If JALR uses LW effective address (104 = 0x68):       $s0 = 88 (0x58)
# ---------------------------------------------------------
addi $t0, $zero, jalr1_pass
sw   $t0, 104($zero)
addi $t1, $zero, jalr1_old
nop
nop
lw   $t1, 104($zero)
jalr $s3, $t1
addi $s0, $zero, 1
jalr1_old:
addi $s0, $zero, 99
j    jalr1_done
jalr1_pass:
addi $s0, $zero, 2
j    jalr1_done
jalr1_alu_addr:
addi $s0, $zero, 88
jalr1_done:
nop
halt