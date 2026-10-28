`default_nettype none
// fcnn_fp16_multiplier : هسته ترکیبی یک ضرب IEEE-754 binary16 بدون تکثیر.
module fcnn_fp16_multiplier (
    input wire [15:0] a,
    input wire [15:0] b,
    output wire [15:0] result
);

    // =========================================================================
    // Step 1: Unpacking & Classification (باز کردن بسته‌بندی ورودی‌ها و تشخیص حالات خاص)
    // =========================================================================
    wire sign_a;
    wire sign_b;
    wire sign_res;
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

    assign sign_a   = a[15];
    assign sign_b   = b[15];
    assign sign_res = sign_a ^ sign_b;

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
    assign eff_exp_a = a_is_sub  ? 5'd1  : exp_a;
    assign eff_exp_b = b_is_sub  ? 5'd1  : exp_b;

    // =========================================================================
    // Step 2: Input Pre-Normalization (نرمال‌سازی عملوندهای ورودی Subnormal)
    // =========================================================================
    reg [3:0]  lzc_a;
    reg [3:0]  lzc_b;
    reg [10:0] norm_sig_a;
    reg [10:0] norm_sig_b;

    always @(*) begin
        lzc_a      = 4'd0;
        lzc_b      = 4'd0;
        norm_sig_a = sig_a;
        norm_sig_b = sig_b;

        if (a_is_sub) begin
            casez (frac_a)
                10'b1?????????: lzc_a = 4'd1;
                10'b01????????: lzc_a = 4'd2;
                10'b001???????: lzc_a = 4'd3;
                10'b0001??????: lzc_a = 4'd4;
                10'b00001?????: lzc_a = 4'd5;
                10'b000001????: lzc_a = 4'd6;
                10'b0000001???: lzc_a = 4'd7;
                10'b00000001??: lzc_a = 4'd8;
                10'b000000001?: lzc_a = 4'd9;
                10'b0000000001: lzc_a = 4'd10;
                default:        lzc_a = 4'd0;
            endcase
            norm_sig_a = sig_a << lzc_a;
        end

        if (b_is_sub) begin
            casez (frac_b)
                10'b1?????????: lzc_b = 4'd1;
                10'b01????????: lzc_b = 4'd2;
                10'b001???????: lzc_b = 4'd3;
                10'b0001??????: lzc_b = 4'd4;
                10'b00001?????: lzc_b = 4'd5;
                10'b000001????: lzc_b = 4'd6;
                10'b0000001???: lzc_b = 4'd7;
                10'b00000001??: lzc_b = 4'd8;
                10'b000000001?: lzc_b = 4'd9;
                10'b0000000001: lzc_b = 4'd10;
                default:        lzc_b = 4'd0;
            endcase
            norm_sig_b = sig_b << lzc_b;
        end
    end

    // =========================================================================
    // Step 3: Core Multiplication & Exponent Calculation (ضرب مانتیس ۱۱×۱۱ و محاسبه نمای اولیه)
    // =========================================================================
    wire [21:0] prod_raw;
    assign prod_raw = norm_sig_a * norm_sig_b;

    reg signed [7:0] exp_sum;
    reg [21:0]       prod_norm;
    reg [5:0]        rshift_amt;
    reg [21:0]       shifted_sig;
    reg [21:0]       sticky_mask;
    reg              guard_bit;
    reg              round_bit;
    reg              sticky_bit;
    reg [10:0]       main_sig;
    reg              round_up;
    reg [11:0]       rounded_sig;
    reg signed [7:0] final_exp;
    reg [9:0]        final_frac;
    reg [15:0]       result_reg;

    always @(*) begin
        // مقداردهی اولیه پیش‌فرض برای جلوگیری از ایجاد Latch ناخواسته
        exp_sum     = 8'sd0;
        prod_norm   = 22'd0;
        rshift_amt  = 6'd0;
        shifted_sig = 22'd0;
        sticky_mask = 22'd0;
        guard_bit   = 1'b0;
        round_bit   = 1'b0;
        sticky_bit  = 1'b0;
        main_sig    = 11'd0;
        round_up    = 1'b0;
        rounded_sig = 12'd0;
        final_exp   = 8'sd0;
        final_frac  = 10'd0;
        result_reg  = 16'd0;

        // تراز کردن بیت پیشرو روی بیت ۲۱ و محاسبه نمای اولیه با احتساب بایاس ۱۵
        if (prod_raw[21]) begin
            prod_norm = prod_raw;
            exp_sum   = $signed({3'b000, eff_exp_a}) + $signed({3'b000, eff_exp_b})
                      - 8'sd15
                      - $signed({4'b0000, lzc_a}) - $signed({4'b0000, lzc_b})
                      + 8'sd1;
        end else begin
            prod_norm = prod_raw << 1;
            exp_sum   = $signed({3'b000, eff_exp_a}) + $signed({3'b000, eff_exp_b})
                      - 8'sd15
                      - $signed({4'b0000, lzc_a}) - $signed({4'b0000, lzc_b});
        end

        // =====================================================================
        // Step 4: Alignment & GRS Extraction (مدیریت Gradual Underflow و استخراج بیت‌های GRS)
        // =====================================================================
        if (exp_sum > 8'sd0) begin
            shifted_sig = prod_norm;
            main_sig    = prod_norm[21:11];
            guard_bit   = prod_norm[10];
            round_bit   = prod_norm[9];
            sticky_bit  = |prod_norm[8:0];
        end else begin
            if ((8'sd1 - exp_sum) > 8'sd22) begin
                rshift_amt = 6'd23;
            end else begin
                rshift_amt = 6'd1 - exp_sum[5:0];
            end

            if (rshift_amt > 6'd22) begin
                shifted_sig = 22'd0;
                main_sig    = 11'd0;
                guard_bit   = 1'b0;
                round_bit   = 1'b0;
                sticky_bit  = |prod_norm;
            end else begin
                shifted_sig = prod_norm >> rshift_amt;
                main_sig    = shifted_sig[21:11];
                guard_bit   = shifted_sig[10];
                round_bit   = shifted_sig[9];
                sticky_mask = ~(22'h3FFFFF << (rshift_amt + 6'd9));
                sticky_bit  = |(prod_norm & sticky_mask);
            end
        end

        // =====================================================================
        // Step 5: RNE Rounding & Post-Normalization (گرد کردن به نزدیک‌ترین زوج)
        // =====================================================================
        round_up    = guard_bit & (round_bit | sticky_bit | main_sig[0]);
        rounded_sig = {1'b0, main_sig} + {11'd0, round_up};

        if (exp_sum > 8'sd0) begin
            if (rounded_sig[11]) begin
                final_exp  = exp_sum + 8'sd1;
                final_frac = rounded_sig[10:1];
            end else begin
                final_exp  = exp_sum;
                final_frac = rounded_sig[9:0];
            end
        end else begin
            if (rounded_sig[10]) begin
                final_exp  = 8'sd1;
                final_frac = rounded_sig[9:0];
            end else begin
                final_exp  = 8'sd0;
                final_frac = rounded_sig[9:0];
            end
        end

        // =====================================================================
        // Step 6: Exception Handling & Output Muxing (مدیریت استثناها و انتخاب خروجی نهایی)
        // =====================================================================
        if (a_is_nan || b_is_nan || (a_is_zero && b_is_inf) || (a_is_inf && b_is_zero)) begin
            // اولویت ۱: Canonical qNaN
            result_reg = 16'h7E00;
        end else if (a_is_inf || b_is_inf) begin
            // اولویت ۲: بی‌نهایت ورودی
            result_reg = {sign_res, 5'h1F, 10'd0};
        end else if (a_is_zero || b_is_zero) begin
            // اولویت ۳: صفر ورودی با حفظ علامت
            result_reg = {sign_res, 15'd0};
        end else if (final_exp >= 8'sd31) begin
            // اولویت ۴: سرریز نما (Overflow به بی‌نهایت علامت‌دار در مد RNE)
            result_reg = {sign_res, 5'h1F, 10'd0};
        end else if ((final_exp == 8'sd0) && (final_frac == 10'd0)) begin
            // اولویت ۵: Underflow کامل به صفر علامت‌دار
            result_reg = {sign_res, 15'd0};
        end else begin
            // اولویت ۶: خروجی نرمال یا Subnormal معتبر
            result_reg = {sign_res, final_exp[4:0], final_frac};
        end
    end

    assign result = result_reg;

endmodule
`default_nettype wire
