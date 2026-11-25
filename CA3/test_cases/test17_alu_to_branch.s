addi $t1, $zero, 7
addi $t2, $zero, 9
addi $t3, $zero, 9
nop

addi $t0, $zero, 7
beq  $t0, $t1, beq_rs_pass
addi $s0, $zero, 1
j    beq_rs_end
nop
beq_rs_pass:
addi $s0, $zero, 2
beq_rs_end:
nop

addi $t3, $zero, 7
bne  $t2, $t3, bne_rt_pass
addi $s1, $zero, 1
j    bne_rt_end
nop
bne_rt_pass:
addi $s1, $zero, 2
bne_rt_end:
nop

addi $t4, $zero, 9
addi $t5, $zero, 9
addi $t4, $zero, 7
nop
beq  $t4, $t5, beq_memwb_fail
addi $s2, $zero, 2
j    beq_memwb_end
nop
beq_memwb_fail:
addi $s2, $zero, 1
beq_memwb_end:
nop
halt
