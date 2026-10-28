# برنامه جاری fcnn_product_register

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_product_register.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 1 ترتیبی، 0 ترکیبی، 0 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: `DEST_W`. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. one elastic payload register, including every sideband bit.
2. replace on ready, clear valid on a pop without a replacement.
