# ==========================================
# Test: LUI Zero-clearing (Hunting Bug 5)
# ==========================================
# Setup a dirty register
addi $t0, $zero, -1     # $t0 = 0xFFFFFFFF
nop
nop
nop
lui  $t0, 0xAAAA        # Expected: 0xAAAA0000 (If it fails to clear lower bits, it might be 0xAAAAFFFF)
nop
nop
nop

# ==========================================
# Test: JUMP Address Calculation (Hunting Bug 6)
# ==========================================
# JUMP merges top 4 bits of PC+4 with 26-bit target << 2.
# We will place a JUMP instruction, and check if it successfully reaches a faraway label.
j far_target
nop                     
addi $s0, $zero, 99     # FAIL marker. Expected $s0 = 0
nop                     
nop                     

# We need to push the target far away to test the 26-bit shifting and PC merging.
# Filling space with NOPs to reach a higher address.
nop 30

far_target:
addi $s1, $zero, 1      # PASS marker. Expected $s1 = 1
nop                     
halt