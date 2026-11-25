# BATCH 8: Forwarding Datapath Isolation
# 1. T_FWD_EX_RS (EX/MEM to ALU Input 1)
addi $t0, $zero, 5
add  $t1, $t0, $zero    # rs = $t0 (Distance 1)

# 2. T_FWD_EX_RT (EX/MEM to ALU Input 2)
addi $t2, $zero, 6
add  $t3, $zero, $t2    # rt = $t2 (Distance 1)

# 3. T_FWD_MEM_RS (MEM/WB to ALU Input 1)
addi $t4, $zero, 7
nop
add  $t5, $t4, $zero    # rs = $t4 (Distance 2)

# 4. T_FWD_MEM_RT (MEM/WB to ALU Input 2)
addi $t6, $zero, 8
nop
add  $t7, $zero, $t6    # rt = $t6 (Distance 2)

# 5. T_FWD_RF_RS (Register File Read - Distance 3)
addi $s0, $zero, 9
nop
nop
add  $s1, $s0, $zero    # rs = $s0 (Reads directly from RF)

# 6. T_FWD_DOUBLE (Double Data Hazard - Re-verification of Bug 3)
addi $s2, $zero, 1
addi $s2, $zero, 2
add  $s3, $s2, $zero    # Should prioritize distance 1 over distance 2

halt