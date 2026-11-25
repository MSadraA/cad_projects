# BATCH 7: Strict Hypothesis Testing

# ---------------------------------------------------------
# TEST ID: T_JALR_RD
# Purpose: Verify JALR writeback to an explicit rd != 31
# ---------------------------------------------------------
addi $t0, $zero, 24     # Target address = 24 (jalr_targ)
nop
jalr $s0, $t0           # JALR is at byte 8. PC+4 = 12 (0x0C)
nop
halt                    # Byte 16. Should be skipped
nop                     # Byte 20
jalr_targ:              # Byte 24

# ---------------------------------------------------------
# TEST ID: T_VAR_SHIFT
# Purpose: Verify variable shifts (SLLV, SRLV, SRAV)
# ---------------------------------------------------------
addi $t2, $zero, -4     # $t2 = 0xFFFFFFFC
addi $t3, $zero, 2      # shift amount = 2
nop
sllv $s1, $t2, $t3      
srlv $s2, $t2, $t3      
srav $s3, $t2, $t3      
nop
nop
nop

# ---------------------------------------------------------
# TEST ID: T_XORI_EXT
# Purpose: Verify if XORI incorrectly sign-extends
# ---------------------------------------------------------
addi $t4, $zero, -1     # $t4 = 0xFFFFFFFF
xori $s4, $t4, 0x8000   
nop
nop
nop

# ---------------------------------------------------------
# TEST ID: T_SLTI_BOUNDS
# Purpose: SLTI and SLTIU signed/unsigned edge cases
# ---------------------------------------------------------
addi $t5, $zero, -1     # $t5 = 0xFFFFFFFF
slti $s5, $zero, -1     
slti $s6, $t5, 0        
sltiu $s7, $zero, -1    
sltiu $t6, $t5, -1      
nop
nop
nop

# ---------------------------------------------------------
# TEST ID: T_FWD_OP
# Purpose: Verify EX/MEM forwarding to rs and rt independently
# ---------------------------------------------------------
addi $t7, $zero, 15
add  $t8, $t7, $zero    # FWD to rs
addi $t7, $zero, 25
add  $t9, $zero, $t7    # FWD to rt
nop
nop
nop

# ---------------------------------------------------------
# TEST ID: T_BR_STALL
# Purpose: Branch dependencies and forwarding priority
# ---------------------------------------------------------
addi $a0, $zero, 1
addi $a0, $zero, 2      # Double hazard generated prior to branch
beq  $a0, $zero, b_fail 
addi $a1, $zero, 1      # Should execute (not flushed)
j b_end
nop
b_fail:
addi $a1, $zero, 99     # Should be skipped
b_end:
nop
nop
nop
halt