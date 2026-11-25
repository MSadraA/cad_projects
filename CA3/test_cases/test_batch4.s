# Batch 4: Data Hazards and Forwarding
addi $t0, $zero, 10     # $t0 = 10
nop
nop
nop

# Test 1: EX to EX Forwarding (Distance 1)
addi $t1, $t0, 5        # $t1 = 15 (creates EX/MEM forwarding to next inst)
add  $t2, $t1, $t0      # $t2 = 15 + 10 = 25 (Needs $t1 from EX/MEM)
nop
nop
nop

# Test 2: MEM to EX Forwarding (Distance 2)
addi $t3, $t0, 10       # $t3 = 20
nop                     # NOP pushes it to MEM/WB
add  $t4, $t3, $t0      # $t4 = 20 + 10 = 30 (Needs $t3 from MEM/WB)
nop
nop
nop

# Test 3: Double Data Hazard (Prioritizing closer hazard)
addi $t5, $zero, 1      # $t5 = 1
addi $t5, $zero, 2      # $t5 = 2
add  $s0, $t5, $zero    # $s0 = 2 (Must take the more recent $t5)
nop
nop
nop

# Test 4: Forwarding to Memory Store (SW)
addi $s1, $zero, 100    # $s1 = 100
sw   $s1, 20($zero)     # M[20] = 100 (Needs $s1 forwarded to Memory stage)
nop
nop
nop

halt