# برنامه جاری fcnn_bias_rom

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_bias_rom.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 0 ترتیبی، 0 ترکیبی، 1 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: `N_HIDDEN`, `N_OUTPUTS`, `FC1_BIAS_FILE`, `FC2_BIAS_FILE`. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

برای سازگاری Verilog-2005 با ModelSim 2020، فهرست پورت‌ها non-ANSI است؛ ثابت‌های مشتق قبل از اعلان نوع و عرض پورت‌ها قرار دارند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. independent scalar bias ROMs.
2. FC1 is indexed by the backend destination, never request progress.
