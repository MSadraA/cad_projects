`default_nettype none
// fcnn_fp16_adder : هسته ترکیبی یک جمع FP16؛ بازخورد از انباشت‌گر انتخاب‌شده.
module fcnn_fp16_adder (
    input wire [15:0] a,
    input wire [15:0] b,
    output wire [15:0] result
);

    // =========================================================================
    // Step 1: Unpacking, Classification & Magnitude Compare (باز کردن بسته‌بندی، طبقه‌بندی و مقایسه اندازه)
    // =========================================================================
    wire sign_a;
    wire sign_b;
    wire [4:0] exp_a;
    wire [4:0] exp_b;
    wire [9:0] frac_a;
    wire [9:0] frac_b;

    wire a_is_zero;
    wire b_is_zero;
    wire a_is_sub;
    wire b_is_sub;
    wire a_is_inf;
    wire b_is_inf;
    wire a_is_nan;
    wire b_is_nan;

    wire [10:0] sig_a;
    wire [10:0] sig_b;
    wire [4:0] eff_exp_a;
    wire [4:0] eff_exp_b;
    wire eff_sub;
    wire a_lt_b;

    assign sign_a = a[15];
    assign sign_b = b[15];
    assign exp_a  = a[14:10];
    assign exp_b  = b[14:10];
    assign frac_a = a[9:0];
    assign frac_b = b[9:0];

    assign a_is_zero = (exp_a == 5'd0)  && (frac_a == 10'd0);
    assign b_is_zero = (exp_b == 5'd0)  && (frac_b == 10'd0);
    assign a_is_sub  = (exp_a == 5'd0)  && (frac_a != 10'd0);
    assign b_is_sub  = (exp_b == 5'd0)  && (frac_b != 10'd0);
    assign a_is_inf  = (exp_a == 5'h1F) && (frac_a == 10'd0);
    assign b_is_inf  = (exp_b == 5'h1F) && (frac_b == 10'd0);
    assign a_is_nan  = (exp_a == 5'h1F) && (frac_a != 10'd0);
    assign b_is_nan  = (exp_b == 5'h1F) && (frac_b != 10'd0);

    assign sig_a     = a_is_zero ? 11'd0 : {(~a_is_sub), frac_a};
    assign sig_b     = b_is_zero ? 11'd0 : {(~b_is_sub), frac_b};
    assign eff_exp_a = (a_is_sub || a_is_zero) ? 5'd1 : exp_a;
    assign eff_exp_b = (b_is_sub || b_is_zero) ? 5'd1 : exp_b;

    assign eff_sub = sign_a ^ sign_b;
    assign a_lt_b  = {exp_a, frac_a} < {exp_b, frac_b};

    // متغیرهای داخلی بلوک ترکیبی
    reg        sign_lg;
    reg [4:0]  exp_lg;
    reg [4:0]  exp_sm;
    reg [10:0] sig_lg;
    reg [10:0] sig_sm;

    reg [4:0]  exp_diff;
    reg [13:0] aligned_lg;
    reg [13:0] raw_sm;
    reg [13:0] shifted_sm;
    reg [13:0] sticky_mask;
    reg        sticky_sm;
    reg [13:0] aligned_sm;

    reg [14:0] sum_mant;
    reg [3:0]  lzc_sum;
    reg [4:0]  max_lshift;
    reg [3:0]  actual_lshift;
    reg [14:0] norm_mant;
    reg [5:0]  norm_exp;

    reg [10:0] main_sig;
    reg        guard_bit;
    reg        round_bit;
    reg        sticky_bit;
    reg        round_up;
    reg [11:0] rounded_sig;
    reg [5:0]  final_exp;
    reg [9:0]  final_frac;
    reg [15:0] result_reg;

    always @(*) begin
        // مقداردهی پیش‌فرض برای جلوگیری قطعی از ایجاد Latch
        sign_lg       = 1'b0;
        exp_lg        = 5'd0;
        exp_sm        = 5'd0;
        sig_lg        = 11'd0;
        sig_sm        = 11'd0;
        exp_diff      = 5'd0;
        aligned_lg    = 14'd0;
        raw_sm        = 14'd0;
        shifted_sm    = 14'd0;
        sticky_mask   = 14'd0;
        sticky_sm     = 1'b0;
        aligned_sm    = 14'd0;
        sum_mant      = 15'd0;
        lzc_sum       = 4'd0;
        max_lshift    = 5'd0;
        actual_lshift = 4'd0;
        norm_mant     = 15'd0;
        norm_exp      = 6'd0;
        main_sig      = 11'd0;
        guard_bit     = 1'b0;
        round_bit     = 1'b0;
        sticky_bit    = 1'b0;
        round_up      = 1'b0;
        rounded_sig   = 12'd0;
        final_exp     = 6'd0;
        final_frac    = 10'd0;
        result_reg    = 16'd0;

        // =====================================================================
        // Step 2: Operand Swapping & Mantissa Alignment (مرتب‌سازی عملوندها و تراز کردن مانتیس‌ها)
        // =====================================================================
        if (a_lt_b) begin
            sign_lg = sign_b;
            exp_lg  = eff_exp_b;
            exp_sm  = eff_exp_a;
            sig_lg  = sig_b;
            sig_sm  = sig_a;
        end else begin
            sign_lg = sign_a;
            exp_lg  = eff_exp_a;
            exp_sm  = eff_exp_b;
            sig_lg  = sig_a;
            sig_sm  = sig_b;
        end

        exp_diff   = exp_lg - exp_sm;
        aligned_lg = {sig_lg, 3'b000};
        raw_sm     = {sig_sm, 3'b000};

        if (exp_diff == 5'd0) begin
            shifted_sm  = raw_sm;
            sticky_mask = 14'd0;
            sticky_sm   = 1'b0;
            aligned_sm  = raw_sm;
        end else if (exp_diff >= 5'd14) begin
            shifted_sm  = 14'd0;
            sticky_mask = 14'h3FFF;
            sticky_sm   = |raw_sm;
            aligned_sm  = {13'd0, sticky_sm};
        end else begin
            shifted_sm  = raw_sm >> exp_diff;
            sticky_mask = 14'h3FFF >> (5'd14 - exp_diff);
            sticky_sm   = |(raw_sm & sticky_mask);
            aligned_sm  = {shifted_sm[13:1], shifted_sm[0] | sticky_sm};
        end

        // =====================================================================
        // Step 3: Mantissa Addition / Subtraction (جمع یا تفریق مانتیس‌های تراز شده)
        // =====================================================================
        if (eff_sub) begin
            sum_mant = {1'b0, aligned_lg} - {1'b0, aligned_sm};
        end else begin
            sum_mant = {1'b0, aligned_lg} + {1'b0, aligned_sm};
        end

        // =====================================================================
        // Step 4: Normalization & LZC (نرمال‌سازی، شمارش صفرهای پیشرو و مدیریت Gradual Underflow)
        // =====================================================================
        if (sum_mant[14]) begin
            norm_mant = {1'b0, sum_mant[14:2], sum_mant[1] | sum_mant[0]};
            norm_exp  = {1'b0, exp_lg} + 6'd1;
        end else begin
            casez (sum_mant[13:0])
                14'b1?????????????: lzc_sum = 4'd0;
                14'b01????????????: lzc_sum = 4'd1;
                14'b001???????????: lzc_sum = 4'd2;
                14'b0001??????????: lzc_sum = 4'd3;
                14'b00001?????????: lzc_sum = 4'd4;
                14'b000001????????: lzc_sum = 4'd5;
                14'b0000001???????: lzc_sum = 4'd6;
                14'b00000001??????: lzc_sum = 4'd7;
                14'b000000001?????: lzc_sum = 4'd8;
                14'b0000000001????: lzc_sum = 4'd9;
                14'b00000000001???: lzc_sum = 4'd10;
                14'b000000000001??: lzc_sum = 4'd11;
                14'b0000000000001?: lzc_sum = 4'd12;
                14'b00000000000001: lzc_sum = 4'd13;
                default:            lzc_sum = 4'd0;
            endcase

            max_lshift = exp_lg - 5'd1;

            if ({1'b0, lzc_sum} <= max_lshift) begin
                actual_lshift = lzc_sum;
                norm_mant     = sum_mant << actual_lshift;
                if (norm_mant[13]) begin
                    norm_exp = {1'b0, exp_lg - {1'b0, actual_lshift}};
                end else begin
                    norm_exp = 6'd0;
                end
            end else begin
                actual_lshift = max_lshift[3:0];
                norm_mant     = sum_mant << actual_lshift;
                norm_exp      = 6'd0;
            end
        end

        // =====================================================================
        // Step 5: RNE Rounding & Post-Normalization (گرد کردن به نزدیک‌ترین زوج)
        // =====================================================================
        main_sig    = norm_mant[13:3];
        guard_bit   = norm_mant[2];
        round_bit   = norm_mant[1];
        sticky_bit  = norm_mant[0];

        round_up    = guard_bit & (round_bit | sticky_bit | main_sig[0]);
        rounded_sig = {1'b0, main_sig} + {11'd0, round_up};

        if (rounded_sig[11]) begin
            final_exp  = norm_exp + 6'd1;
            final_frac = rounded_sig[10:1];
        end else begin
            if ((norm_exp == 6'd0) && rounded_sig[10]) begin
                final_exp  = 6'd1;
                final_frac = rounded_sig[9:0];
            end else begin
                final_exp  = norm_exp;
                final_frac = rounded_sig[9:0];
            end
        end

        // =====================================================================
        // Step 6: Exception Handling & Output Muxing (مدیریت استثناها و انتخاب خروجی نهایی)
        // =====================================================================
        if (a_is_nan || b_is_nan || (a_is_inf && b_is_inf && eff_sub)) begin
            // اولویت ۱: ورودی NaN یا جمع دو بی‌نهایت با علامت مخالف -> Canonical qNaN
            result_reg = 16'h7E00;
        end else if (a_is_inf) begin
            // اولویت ۲: بی‌نهایت ورودی اول
            result_reg = {sign_a, 5'h1F, 10'd0};
        end else if (b_is_inf) begin
            // اولویت ۲: بی‌نهایت ورودی دوم
            result_reg = {sign_b, 5'h1F, 10'd0};
        end else if (a_is_zero && b_is_zero) begin
            // اولویت ۳: هر دو ورودی صفر (-0 + -0 = -0، سایر حالات +0)
            result_reg = {sign_a & sign_b, 15'd0};
        end else if (a_is_zero) begin
            // اولویت ۴: فقط ورودی اول صفر است
            result_reg = b;
        end else if (b_is_zero) begin
            // اولویت ۴: فقط ورودی دوم صفر است
            result_reg = a;
        end else if (sum_mant == 15'd0) begin
            // اولویت ۵: حذف کامل در تفریق دو عدد هم‌اندازه -> +0 در مد RNE
            result_reg = 16'h0000;
        end else if (final_exp >= 6'd31) begin
            // اولویت ۶: سرریز نما به بی‌نهایت علامت‌دار
            result_reg = {sign_lg, 5'h1F, 10'd0};
        end else if ((final_exp == 6'd0) && (final_frac == 10'd0)) begin
            // اولویت ۷: صفر ناشی از Underflow
            result_reg = {sign_lg, 15'd0};
        end else begin
            // اولویت ۸: خروجی نرمال یا Subnormal معتبر
            result_reg = {sign_lg, final_exp[4:0], final_frac};
        end
    end

    assign result = result_reg;

endmodule
`default_nettype wire
