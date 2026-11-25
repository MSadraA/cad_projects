# Test 24A: double-write forwarding priority into BEQ (ID-stage comparator).
# Old $t0 = 0, newest $t0 = 1.
# Correct newest value: BEQ $t0,$zero is NOT taken => $s0 = 1.
# If the older value wins: branch is taken => $s0 = 99.

addi $t0, $zero, 0
addi $t0, $zero, 1
beq  $t0, $zero, beq_wrong
nop                       # Harmless sequential instruction for the not-taken case
addi $s0, $zero, 1        # Correct not-taken marker
j    test_end
nop

beq_wrong:
addi $s0, $zero, 99
j    test_end
nop

test_end:
halt
