# BATCH 17: Strict Audit of Bug 5, Bug 6, JR Double-Hazard, and Untested XOR

# ---------------------------------------------------------
# 1. Audit Bug 5: Immediate LW -> JR ($s0)
# Expected: $s0 = 2 (PASS). If Bug 5 exists (uses old $t1): $s0 = 99 (0x63)
# ---------------------------------------------------------
addi $t0, $zero, j1_pass
sw   $t0, 0($zero)
addi $t1, $zero, j1_old
nop
nop
lw   $t1, 0($zero)
jr   $t1
addi $s0, $zero, 1
j1_old:
addi $s0, $zero, 99
j    j1_done
j1_pass:
addi $s0, $zero, 2
j1_done:
nop
nop

# ---------------------------------------------------------
# 2. Control for Bug 5: LW -> NOP -> JR ($s1)
# Expected: $s1 = 2 (PASS)
# ---------------------------------------------------------
addi $t0, $zero, j2_pass
sw   $t0, 4($zero)
addi $t2, $zero, j2_old
nop
nop
lw   $t2, 4($zero)
nop
jr   $t2
addi $s1, $zero, 1
j2_old:
addi $s1, $zero, 99
j    j2_done
j2_pass:
addi $s1, $zero, 2
j2_done:
nop
nop

# ---------------------------------------------------------
# 3. Audit Bug 6 (rs): Double Data Hazard into BEQ ($s2)
# Expected: $s2 = 2 (PASS). If Bug 6 exists (uses old $t4=5): $s2 = 99 (0x63)
# ---------------------------------------------------------
addi $t3, $zero, 5
nop
nop
addi $t4, $zero, 5
addi $t4, $zero, 6
beq  $t4, $t3, b1_fail
addi $s2, $zero, 2
j    b1_done
b1_fail:
addi $s2, $zero, 99
b1_done:
nop
nop

# ---------------------------------------------------------
# 4. Audit Bug 6 (rt): Double Data Hazard into BNE ($s3)
# Expected: $s3 = 2 (PASS). If Bug 6 exists (uses old $t5=5): $s3 = 99 (0x63)
# ---------------------------------------------------------
addi $t3, $zero, 5
nop
nop
addi $t5, $zero, 5
addi $t5, $zero, 6
bne  $t3, $t5, b2_pass
addi $s3, $zero, 99
j    b2_done
b2_pass:
addi $s3, $zero, 2
b2_done:
nop
nop

# ---------------------------------------------------------
# 5. Architectural Probe: Double Data Hazard into JR ($s4)
# Distinguishes if JR shares the same double-hazard priority bug as BEQ/BNE
# Expected: $s4 = 2. If JR uses old $t6: $s4 = 99 (0x63)
# ---------------------------------------------------------
addi $t6, $zero, j3_old
addi $t6, $zero, j3_new
jr   $t6
addi $s4, $zero, 1
j3_old:
addi $s4, $zero, 99
j    j3_done
j3_new:
addi $s4, $zero, 2
j3_done:
nop
nop

# ---------------------------------------------------------
# 6. Coverage Closure: R-type XOR ($s5) & LW->LW Base Addr ($s6)
# Expected: $s5 = 0x00000FF0, $s6 = 0x00000077
# ---------------------------------------------------------
addi $t7, $zero, 0x00FF
addi $t8, $zero, 0x0F0F
nop
nop
xor  $s5, $t7, $t8

addi $t7, $zero, 16
sw   $t7, 8($zero)
addi $t8, $zero, 0x77
sw   $t8, 16($zero)
nop
nop
lw   $t9, 8($zero)
lw   $s6, 0($t9)
nop
halt