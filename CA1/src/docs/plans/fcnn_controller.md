# برنامه جاری fcnn_controller

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_controller.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 1 ترتیبی، 1 ترکیبی، 0 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: ندارد. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. the four phases are protocol states, not tunable parameters.
2. synchronous active-high reset.
3. start is accepted only in IDLE; busy starts are ignored.
4. DONE lasts one cycle. A held start is accepted on returning IDLE.
