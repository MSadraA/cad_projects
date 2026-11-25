# BATCH 9: Load-Use Branch Stalls Isolation
# Memory Setup: M[0] = 10
addi $t0, $zero, 10
sw   $t0, 0($zero)
addi $t9, $zero, 10     # Target comparison value for Branches
nop
nop
nop

# 1. T_LD_USE_BEQ
addi $t2, $zero, 99     # Old value = 99
nop
nop
nop
lw   $t2, 0($zero)      # New value = 10
beq  $t2, $t9, beq_pass # Compares $t2 with 10
nop
nop
nop
# Fallthrough path (Stall Failed -> read old value 99. 99 != 10 -> Not Taken)
addi $s0, $zero, 1      # FAIL marker
j beq_done
nop
beq_pass:
# Taken path (Stall Succeeded -> read new value 10. 10 == 10 -> Taken)
addi $s0, $zero, 2      # PASS marker
beq_done:
nop

# 2. T_LD_USE_BNE
addi $t3, $zero, 99     # Old value = 99
nop
nop
nop
lw   $t3, 0($zero)      # New value = 10
bne  $t3, $t9, bne_fail # Compares $t3 with 10
nop
nop
nop
# Fallthrough path (Stall Succeeded -> read new value 10. 10 != 10 is False -> Not Taken)
addi $s1, $zero, 2      # PASS marker
j bne_done
nop
bne_fail:
# Taken path (Stall Failed -> read old value 99. 99 != 10 is True -> Taken)
addi $s1, $zero, 1      # FAIL marker
bne_done:
nop
halt