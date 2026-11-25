# Test 24B: double-write forwarding priority into BNE (ID-stage comparator).
# Old $t0 = 0, newest $t0 = 1.
# Correct newest value: BNE $t0,$zero is TAKEN => $s0 = 2.
# If the older value wins: branch is not taken => $s0 = 99.

addi $t0, $zero, 0
addi $t0, $zero, 1
bne  $t0, $zero, bne_pass
addi $s7, $zero, 99       # Must be flushed if branch is taken
addi $s0, $zero, 99       # Wrong not-taken marker
j    test_end
nop

bne_pass:
addi $s0, $zero, 2
j    test_end
nop

test_end:
halt
