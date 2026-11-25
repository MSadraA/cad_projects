# Setup Memory: M[0] = 50, M[4] = 60
addi $t0, $zero, 50
sw   $t0, 0($zero)
addi $t0, $zero, 60
sw   $t0, 4($zero)
addi $t2, $zero, 50     # Target for BEQ
addi $t4, $zero, 60     # Target for BNE
nop
nop

# ========================================================
# Scenario A: Load-Use Branch TAKEN (Requires Stall + Flush)
# ========================================================
addi $t1, $zero, 99     # Old value = 99
lw   $t1, 0($zero)      # New value = 50
beq  $t1, $t2, beq_taken# 50 == 50 -> Taken
addi $s0, $zero, 1      # FAIL marker (Sequential path - should be FLUSHED)
j    beq_end
nop
beq_taken:
addi $s0, $zero, 2      # PASS marker (Target path)
beq_end:
nop
nop

# ========================================================
# Scenario B: Load-Use Branch NOT TAKEN (Requires Stall + Sequential)
# ========================================================
addi $t3, $zero, 99     # Old value = 99
lw   $t3, 4($zero)      # New value = 60
bne  $t3, $t4, bne_taken# 60 != 60 -> Not Taken
addi $s1, $zero, 2      # PASS marker (Sequential path - should execute)
j    bne_end
nop
bne_taken:
addi $s1, $zero, 1      # FAIL marker (Target path - should NOT execute)
bne_end:
nop
halt