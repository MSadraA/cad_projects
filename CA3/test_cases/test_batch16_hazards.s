# Setup Memory: M[0]=1, M[4]=2, M[8]=1
addi $t0, $zero, 1
sw   $t0, 0($zero)
addi $t1, $zero, 2
sw   $t1, 4($zero)
sw   $t0, 8($zero)
nop

# T_STALL_FLUSH_RACE
addi $t2, $zero, 1
lw   $t3, 4($zero)      # New = 2
nop
nop
nop
# Now $t3 = 2, firmly in RF. No stall needed yet.
# Let's create a Load-Use into a Branch that IS taken.
lw   $t4, 8($zero)      # New = 1 (will cause load-use stall in next instruction)
beq  $t4, $t2, b_race_pass # 1 == 1. Needs 2 cycles of STALL to read $t4, then FLUSHes the next instruction.
addi $s0, $zero, 99     # Should be FLUSHED. Expected $s0 = 0.
addi $s1, $zero, 99     # Should be FLUSHED. Expected $s1 = 0.
j end_race
nop
b_race_pass:
addi $s2, $zero, 1      # PASS target
end_race:
nop
nop

# T_CONSECUTIVE_SW
addi $t5, $zero, 10
addi $t6, $zero, 20
sw   $t5, 12($zero)
sw   $t6, 16($zero)     # Consecutive SWs sometimes fail due to MEM stage structural hazards
lw   $s3, 12($zero)     # Expected $s3 = 10
lw   $s4, 16($zero)     # Expected $s4 = 20
nop
halt