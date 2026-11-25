# Batch 5: Load-Use Hazards and Stalls
# Setup
addi $t0, $zero, 50     # $t0 = 50
sw   $t0, 0($zero)      # M[0] = 50
nop
nop
nop

# Test 1: Load-Use Hazard (ALU Inst)
lw   $t1, 0($zero)      # $t1 = 50
add  $t2, $t1, $zero    # Needs stall! Expected $t2 = 50
nop
nop
nop

# Test 2: Load-Use Hazard (Branch Inst)
lw   $t3, 0($zero)      # $t3 = 50
beq  $t3, $t0, success_br # Needs stall! Should jump to success_br
nop
nop
nop
addi $t4, $zero, 99     # Should be skipped if branch is taken
j end_test2
nop
nop
nop
success_br:
addi $t4, $zero, 1      # $t4 = 1

end_test2:
nop
nop
nop

# Test 3: Load-Use Hazard (Store Inst)
# Storing a just-loaded value into memory
lw   $t5, 0($zero)
sw   $t5, 4($zero)      # Should not need a stall, forwarding to MEM is enough, but some designs stall.
lw   $t6, 4($zero)      # $t6 = 50
nop
nop
nop

halt