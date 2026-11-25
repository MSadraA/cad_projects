# Batch 3: Jumps and Branches (Isolated)
addi $t0, $zero, 10
addi $t1, $zero, 20
nop
nop
nop

# 1. JUMP Test
j jump_targ
nop
nop
nop
addi $t2, $zero, 99   # Should skip this

jump_targ:
addi $t2, $zero, 1    # $t2 = 1
nop
nop
nop

# 2. BEQ Test (Not Taken)
beq $t0, $t1, fail_beq
nop
nop
nop
addi $t3, $zero, 2    # $t3 = 2
j end_beq
nop
nop
nop

fail_beq:
addi $t3, $zero, 99   # Should skip this

end_beq:
nop
nop
nop

# 3. BNE Test (Taken)
bne $t0, $t1, pass_bne
nop
nop
nop
addi $t4, $zero, 99   # Should skip this
j end_bne
nop
nop
nop

pass_bne:
addi $t4, $zero, 3    # $t4 = 3

end_bne:
nop
nop
nop

# 4. JAL and JR Test
jal my_func
nop
nop
nop
addi $t5, $zero, 4    # $t5 = 4
j finish
nop
nop
nop

my_func:
addi $s0, $ra, 0      # Save $ra to $s0 (16)
nop
nop
nop
jr $ra
nop
nop
nop

finish:
halt