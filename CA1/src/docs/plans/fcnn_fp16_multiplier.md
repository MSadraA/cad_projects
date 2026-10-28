# برنامه جاری fcnn_fp16_multiplier

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_fp16_multiplier.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 0 ترتیبی، 2 ترکیبی، 0 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: ندارد. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. Unpacking & Classification (باز کردن بسته‌بندی ورودی‌ها و تشخیص حالات خاص)
2. Input Pre-Normalization (نرمال‌سازی عملوندهای ورودی Subnormal)
3. Core Multiplication & Exponent Calculation (ضرب مانتیس ۱۱×۱۱ و محاسبه نمای اولیه)
4. Alignment & GRS Extraction (مدیریت Gradual Underflow و استخراج بیت‌های GRS)
5. RNE Rounding & Post-Normalization (گرد کردن به نزدیک‌ترین زوج)
6. Exception Handling & Output Muxing (مدیریت استثناها و انتخاب خروجی نهایی)
