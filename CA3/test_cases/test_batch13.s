# ==========================================
# Test 1: ADD Overflow (T_ADD_OVF_SAFE)
# ==========================================
# Build 0x7FFFFFFF safely using SLLV/SRLV (Proven bug-free in Batch 7)
addi $t0, $zero, -1     # $t0 = 0xFFFFFFFF
addi $t1, $zero, 1      # $t1 = 1
nop                     
nop                     
nop                     
srlv $t2, $t0, $t1      # $t2 = 0x7FFFFFFF (Logical shift right by 1)
nop                     
nop                     
nop                     
add  $s0, $t2, $t1      # 0x7FFFFFFF + 1 -> Signed Overflow. Expected $s0 = 0x80000000
addu $s1, $t2, $t1      # Unsigned Add. Expected $s1 = 0x80000000
nop                     
nop                     
nop                     

# ==========================================
# Test 2: JAL Jump and Link (T_JAL_ISOLATED)
# ==========================================
jal  jal_targ           # JAL instruction
nop                     
addi $s2, $zero, 99     # FAIL marker (Should be skipped/flushed). Expected $s2 = 0
nop                     
nop                     
jal_targ:
addi $s3, $zero, 2      # PASS marker (Jump successful). Expected $s3 = 2
nop                     
halt