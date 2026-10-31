`timescale 1ns / 1ps

// ============================================================================
// File: tb_fp16_multiplier_core.v
// Description: Testbench for the structural FP16 combinational multiplier
// ============================================================================

module tb_fp16_multiplier_core;

    reg  [15:0] a;
    reg  [15:0] b;
    wire [15:0] out;

    integer pass_count;
    integer fail_count;
    integer test_count;

    // Instantiate the multiplier core
    fp16_multiplier_core uut (
        .a(a),
        .b(b),
        .out(out)
    );

    // Task for applying stimulus and checking the result
    task run_test;
        input [15:0] val_a;
        input [15:0] val_b;
        input [15:0] expected;
        input [8*80:1] test_name;

        begin
            a = val_a;
            b = val_b;

            // Wait for combinational logic propagation
            #20;
            test_count = test_count + 1;

            if (out === expected) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s | A=%h B=%h OUT=%h",
                         test_name, a, b, out);
            end
            else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s", test_name);
                $display("       A        = %h", a);
                $display("       B        = %h", b);
                $display("       EXPECTED = %h", expected);
                $display("       GOT      = %h", out);
            end

            #10;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        test_count = 0;

        a = 16'h0000;
        b = 16'h0000;

        $display("==============================================");
        $display("       FP16 MULTIPLIER CORE TESTBENCH");
        $display("==============================================");

        // 1. Zero Inputs
        run_test(16'h0000, 16'h0000, 16'h0000,
                 "Zero * Zero");

        run_test(16'h3C00, 16'h0000, 16'h0000,
                 "Positive * Zero");

        run_test(16'h0000, 16'hBC00, 16'h0000,
                 "Zero * Negative");

        // 2. Subnormal Inputs (Should be treated as Zero)
        // A = Subnormal (Exp=0, Frac!=0), B = 1.0 (3C00)
        run_test(16'h0055, 16'h3C00, 16'h0000,
                 "Subnormal Input * Normal");

        run_test(16'hBC00, 16'h0001, 16'h0000,
                 "Normal * Subnormal Input");

        // 3. Normal Multiplication (No normalization shift required)
        // 1.25 (3D00) * 1.25 (3D00) = 1.5625 (3E40)
        run_test(16'h3D00, 16'h3D00, 16'h3E40,
                 "Normal * Normal (No Shift)");

        // 4. Normal Multiplication (Normalization shift required)
        // 1.5 (3E00) * 1.5 (3E00) = 2.25 (4080) -> mantissa product >= 2.0
        run_test(16'h3E00, 16'h3E00, 16'h4080,
                 "Normal * Normal (With Shift)");

        // 5. Sign Combinations
        // -1.5 (BE00) * 1.5 (3E00) = -2.25 (C080)
        run_test(16'hBE00, 16'h3E00, 16'hC080,
                 "Negative * Positive");

        // 1.5 (3E00) * -1.5 (BE00) = -2.25 (C080)
        run_test(16'h3E00, 16'hBE00, 16'hC080,
                 "Positive * Negative");

        // -1.5 (BE00) * -1.5 (BE00) = +2.25 (4080)
        run_test(16'hBE00, 16'hBE00, 16'h4080,
                 "Negative * Negative");

        // 6. Overflow Condition (Exponent exceeds 30)
        // Exp=30 with non-zero frac (7A00) * Exp=30 with non-zero frac (7A00) -> Infinity (7C00)
        run_test(16'h7A00, 16'h7A00, 16'h7C00,
                 "Overflow -> +Infinity");

        // Negative Overflow
        run_test(16'hFA00, 16'h7A00, 16'hFC00,
                 "Overflow -> -Infinity");

        // 7. Underflow Condition (Exponent drops below 1)
        // Exp=2 (0800) * Exp=2 (0800) -> Exp Sum = 2 + 2 - 15 = -11 -> Underflow -> Zero
        run_test(16'h0800, 16'h0800, 16'h0000,
                 "Underflow -> Zero Output");

        // Exact Underflow edge case: Exp=7 * Exp=8 -> 7 + 8 - 15 = 0 -> Underflow!
        run_test(16'h1C00, 16'h2000, 16'h0000,
                 "Exact Underflow Boundary -> Zero");

        // 8. Summary Report
        $display("");
        $display("==============================================");
        $display("                FINAL REPORT");
        $display("==============================================");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);

        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: FAILURES DETECTED");

        $display("==============================================");

        $finish;
    end

endmodule