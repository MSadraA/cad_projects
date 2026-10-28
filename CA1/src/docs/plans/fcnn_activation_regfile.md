# برنامه جاری fcnn_activation_regfile

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_activation_regfile.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 1 ترتیبی، 0 ترکیبی، 0 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: `N_HIDDEN`, `N_OUTPUTS`. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

برای سازگاری Verilog-2005 با ModelSim 2020، فهرست پورت‌ها non-ANSI است؛ ثابت‌های مشتق قبل از اعلان نوع و عرض پورت‌ها قرار دارند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. reuse one RF; no duplicate hidden/output storage array.
2. validity clears for each run; reset also clears RF payload.
3. asynchronous read and parallel packed logits, index zero in LSBs.
