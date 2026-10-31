# FP16 Multiplier Optimization Notes

## Constraints from Description(3).pdf
- Multiplier gate limit: 5340.
- The multiplier must treat an input as zero when its exponent or mantissa is zero; subnormal inputs are treated as zero.
- Normalize the mantissa product, return zero on exponent underflow, and return exponent 31 with fraction 0 on overflow.
- Truncate rather than round.
- Structural implementation must use only the provided `c1`, `c2`, `s1`, and `s2` cells; logical operators are not allowed in the designed datapath modules.

## Changes made
1. `array_mul_11bit.v`
   - Replaced the previous five-cell bit-multiplier implementation with a partial-product AND, two XOR stages, and a carry mux. The generic cell cost estimate falls from 52 to 43 gates.
   - Specialized the first row and first column where one full-adder input is constant zero.
   - Further optimized the 20 non-corner boundary cells: each sum now uses one `c2` cell whose control inputs directly encode `(x AND y) XOR carry_in`; each carry uses one `c1` cell configured as a three-input AND. This removes one 10-gate cell per boundary position (200 gates total).
   - Specialized the final row and column because the mantissas are formed as `{1'b1, fraction}`; their leading bits are known ones, so the partial-product AND is unnecessary.
   - Partial-product AND functions are implemented with `c1` mux cells instead of `c2` LUT cells.
2. `base_blocks.v`
   - Reimplemented `And_2bit` using one `c1` cell (10 gates) instead of one `c2` cell (11 gates).
3. `fp16_multiplier_core.v`
   - Removed a redundant full adder for the high bit of the exponent sum; the high bit is the previous carry.
   - Replaced the six-half-adder normalization increment with explicit XOR/AND stages.
   - Simplified the two high exponent bits when adding the constant one, and removed a carry merge that is known to be zero.
   - Combined normalization selection, overflow-zeroing, and forced-zero behavior for each fraction output bit into one `c2` cell plus a shared `c1` OR.
   - Combined overflow selection and zeroing for exponent bits into one `c1` per bit; the sign output is also gated with one `c1`.
4. Kept the C++ gate-count programs and their `./c1`, `./c2`, and `./s2-s1` execution paths unchanged.

## Important verification status
- This environment does not have ModelSim (`vsim`) or Icarus Verilog (`iverilog`) installed, so the Verilog testbench has not been executed here.
- The structural changes are reasoned from the supplied source, but functional equivalence is not yet simulation-verified.
- Based on the user's previously measured 5505-gate version, this change removes exactly 200 gates by replacing 3 cells (31 gates) with 2 cells (21 gates) at each of 20 boundary positions. The expected count is therefore 5305, which is 35 below the 5340 limit, provided the previous 5505 count corresponds to this exact source revision and the counter counts each instantiated c1/c2 cell as specified.
- The revised design has not been simulation-verified in this environment because ModelSim (`vsim`) and Icarus Verilog (`iverilog`) are unavailable. Run the testbench and recheck `gated.txt` before submission.

## Suggested verification
From the `multiplier` directory:

```bash
g++ c1.cpp -o c1
g++ c2.cpp -o c2
g++ s2-s1.cpp -o s2-s1
echo 0 > gated.txt
vlib work
vlog base_blocks.v components.v array_mul_11bit.v fp16_multiplier_core.v modules.v tb_fp16_multiplier_core.v
vsim work.tb_fp16_multiplier_core
run -all
```

Check every test result and the final value in `gated.txt`. If the simulator uses a different compile command, adapt the command but keep the working directory beside the C++ executables.
