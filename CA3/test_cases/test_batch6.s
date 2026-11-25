# Batch 6: Advanced Control Flow, Flush, and Corner Cases
addi $t0, $zero, 4      # $t0 = 4
addi $t1, $zero, 4      # $t1 = 4
nop
nop

# Test 1: Branch Flushing (Delay Slot handling)
beq $t0, $t1, flush_targ  # Taken branch
addi $s0, $zero, 99     # Should be FLUSHED (Not executed). Expected $s0 = 0
addi $s1, $zero, 99     # Should be FLUSHED (Not executed). Expected $s1 = 0
nop

flush_targ:
addi $s2, $zero, 1      # $s2 = 1
nop
nop
nop

# Test 2: Data Hazard into JR
addi $t2, $zero, jr_targ # Load label address into $t2
jr   $t2                # Needs forwarding to Instruction Decode for JR!
addi $s3, $zero, 99     # Should be FLUSHED.
nop

jr_targ:
addi $s4, $zero, 1      # $s4 = 1
nop
nop
nop

# Test 3: Data Hazard into JALR
addi $t3, $zero, jalr_targ
jalr $t3                # Needs forwarding to ID, saves PC+4 to $ra ($31)
addi $s5, $zero, 99     # Should be FLUSHED
nop

jalr_targ:
addi $s6, $zero, 1      # $s6 = 1
nop
nop
nop

# Test 4: Hardware write-protect of $zero
addi $zero, $zero, 50   # Should NOT affect $zero
add  $s7, $zero, $zero  # Expected $s7 = 0
nop
nop
nop

halt