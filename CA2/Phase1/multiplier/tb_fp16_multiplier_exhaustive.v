`timescale 1ns / 1ps

// ============================================================================
// File: tb_fp16_multiplier_exhaustive.v
// ============================================================================

module tb_fp16_multiplier_exhaustive;

    reg  [15:0] a;
    reg  [15:0] b;
    wire [15:0] out;

    // متغیرهای مدل برای اعتبارسنجی
    real real_a, real_b, real_expected;
    reg [15:0] expected_out;
    
    // استفاده از رجیسترهای ۶۴ بیتی برای جلوگیری از سرریز شمارنده‌ها (برای ۴.۳ میلیارد حالت)
    reg [63:0] test_count;
    reg [63:0] pass_count;
    reg [63:0] fail_count;
    reg [63:0] total_cases;
    
    // متغیرهای حلقه (integer در وریلاگ ۳۲ بیتی است و برای شرط تا ۶۵۵۳۵ بی‌خطر است)
    integer i, j;

    // تنظیم گام (Step):
    // عدد ۱ = تست کامل هر ۴.۲۹ میلیارد حالت (بسیار زمان‌بر در مدل‌سیم)
    // عدد ۲۵۷ = تست پراکنده و سریع برای اطمینان از عملکرد
    parameter STEP = 257; 

    // فراخوانی ماژول اصلی
    fp16_multiplier_core uut (
        .a(a),
        .b(b),
        .out(out)
    );

    // تبدیل FP16 به اعداد حقیقی (Real) با رعایت قوانین پروژه
    task fp16_to_real;
        input  [15:0] fp;
        output real   r;
        reg           sign;
        reg [4:0]     exp;
        reg [9:0]     frac;
        real          mant_real;
        begin
            sign = fp[15];
            exp  = fp[14:10];
            frac = fp[9:0];

            if (exp == 0) begin
                r = 0.0; // ورودی‌های Subnormal برابر صفر در نظر گرفته می‌شوند
            end else if (exp == 31) begin
                r = 1.0e10; // عدد بزرگ برای شبیه‌سازی بی‌نهایت
            end else begin
                mant_real = 1.0 + (frac / 1024.0);
                r = mant_real * (2.0 ** (exp - 15));
            end
            
            if (sign) r = -r;
        end
    endtask

    // تبدیل ضرب حقیقی به قالب FP16 مورد انتظار برای بررسی
    task real_to_expected_fp16;
        input  real   r;
        input  reg    expected_sign;
        output [15:0] fp;
        
        real abs_r;
        integer exp;
        real mant;
        integer frac_int;
        begin
            abs_r = (r < 0) ? -r : r;
            
            if (abs_r == 0.0) begin
                fp = 16'h0000; // صفر مطلق
            end else begin
                exp = 0;
                mant = abs_r;
                
                while (mant >= 2.0) begin
                    mant = mant / 2.0;
                    exp = exp + 1;
                end
                while (mant < 1.0 && exp > -15) begin 
                    mant = mant * 2.0;
                    exp = exp - 1;
                end
                
                exp = exp + 15; // اعمال Bias
                
                if (exp <= 0) begin
                    fp = 16'h0000; // حالت Underflow
                end else if (exp >= 31) begin
                    fp = {expected_sign, 5'b11111, 10'b0000000000}; // حالت Overflow
                end else begin
                    frac_int = (mant - 1.0) * 1024.0;
                    fp = {expected_sign, exp[4:0], frac_int[9:0]};
                end
            end
        end
    endtask

    initial begin
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        total_cases = (65536 / STEP) * (65536 / STEP);
        
        $display("==============================================");
        $display(" Starting FP16 Multiplier Verification");
        $display(" Total cases to evaluate: %0d", total_cases);
        $display(" Step size: %0d", STEP);
        $display("==============================================");
        
        for (i = 0; i <= 65535; i = i + STEP) begin
            
            // پرینت وضعیت برای اطمینان از پیشرفت شبیه‌ساز
            if (i % (STEP * 16) == 0) begin
                $display("Progress: Testing A = %h...", i);
            end
            
            for (j = 0; j <= 65535; j = j + STEP) begin
                a = i[15:0];
                b = j[15:0];
                
                fp16_to_real(a, real_a);
                fp16_to_real(b, real_b);
                
                real_expected = real_a * real_b;
                
                real_to_expected_fp16(real_expected, a[15] ^ b[15], expected_out);
                
                #1; // زمان تاخیر برای محاسبه مدار ترکیبی
                
                test_count = test_count + 1;
                
                if (out === expected_out) begin
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                    // توقف پرینت پس از ۲۰ خطا برای جلوگیری از هنگ کردن کنسول
                    if (fail_count <= 20) begin
                        $display("[FAIL] A=%h, B=%h | EXPECTED=%h, GOT=%h", a, b, expected_out, out);
                    end
                end
            end
        end
        
        $display("==============================================");
        $display("             FINAL REPORT");
        $display("==============================================");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        
        if (fail_count == 0)
            $display("RESULT: ALL TESTED CASES PASSED");
        else
            $display("RESULT: FAILURES DETECTED");
        $display("==============================================");
        
        $finish;
    end

endmodule