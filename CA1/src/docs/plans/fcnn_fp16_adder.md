# برنامه جاری fcnn_fp16_adder

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_fp16_adder.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 0 ترتیبی، 1 ترکیبی، 0 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: ندارد. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. Unpacking, Classification & Magnitude Compare (باز کردن بسته‌بندی، طبقه‌بندی و مقایسه اندازه)
2. Operand Swapping & Mantissa Alignment (مرتب‌سازی عملوندها و تراز کردن مانتیس‌ها)
3. Mantissa Addition / Subtraction (جمع یا تفریق مانتیس‌های تراز شده)
4. Normalization & LZC (نرمال‌سازی، شمارش صفرهای پیشرو و مدیریت Gradual Underflow)
5. RNE Rounding & Post-Normalization (گرد کردن به نزدیک‌ترین زوج)
6. Exception Handling & Output Muxing (مدیریت استثناها و انتخاب خروجی نهایی)
