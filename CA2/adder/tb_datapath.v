
`timescale 1ns / 1ps

module tb_datapath;

    reg  [15:0] a;
    reg  [15:0] b;
    wire [15:0] out;

    integer pass_count;
    integer fail_count;
    integer test_count;

    Data_path uut (
        .a(a),
        .b(b),
        .out(out)
    );

    task run_test;
        input [15:0] val_a;
        input [15:0] val_b;
        input [15:0] expected;
        input [8*80:1] test_name;

        begin
            a = val_a;
            b = val_b;

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
        $display("       FP16 ADDER TEST - MODELSIM 2020");
        $display("==============================================");

        // Zero and identity
        run_test(16'h0000, 16'h0000, 16'h0000,
                 "Zero + Zero");

        run_test(16'h4600, 16'h0000, 16'h4600,
                 "Normal + Zero");

        // Equal positive operands
        run_test(16'h3E00, 16'h3E00, 16'h4200,
                 "Positive + Positive");

        // Equal negative operands
        run_test(16'hBE00, 16'hBE00, 16'hC200,
                 "Negative + Negative");

        // Exact cancellation
        run_test(16'h3E00, 16'hBE00, 16'h0000,
                 "Positive + Negative");

        run_test(16'hBE00, 16'h3E00, 16'h0000,
                 "Negative + Positive");

        // Different exponents
        run_test(16'h4000, 16'h3E00, 16'h4100,
                 "Different Exponents");

        // Carry and normalization
        run_test(16'h3E00, 16'h3E00, 16'h4200,
                 "Carry Normalization");

        // Input order / swapping
        run_test(16'h4000, 16'h3E00, 16'h4100,
                 "A Larger");

        run_test(16'h3E00, 16'h4000, 16'h4100,
                 "B Larger");

        // Subnormal flush-to-zero, according to project rules
        run_test(16'h0401, 16'h0000, 16'h0000,
                 "Subnormal Input + Zero");

        // Print summary
        $display("");
        $display("==============================================");
        $display("                 FINAL REPORT");
        $display("==============================================");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);

        if (fail_count == 0)
            $display("RESULT: ALL DIRECTED TESTS PASSED");
        else
            $display("RESULT: FAILURES DETECTED");

        $display("==============================================");

        $finish;
    end

endmodule
