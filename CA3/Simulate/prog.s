# Example program: sum 1..5 with a loop and store the result.
# Assemble with:  python3 asm.py program.s program.mem
        addi $t0,$zero,5        # counter
        addi $s0,$zero,0        # sum
loop:   add  $s0,$s0,$t0
        addi $t0,$t0,-1
        bne  $t0,$zero,loop
        sw   $s0,0($zero)       # M[0] = 15
        lw   $s1,4($zero)       # $s1 = M[1] (initial value from data50.mem)
        halt
# Expected: $s0 = 15, M[0] = 15, $s1 = 7, $t0 = 0
