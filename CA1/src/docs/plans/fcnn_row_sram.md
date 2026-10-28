# برنامه جاری fcnn_row_sram

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_row_sram.v`؛ نمونه‌ها در hierarchy: 2.

بلوک‌های عملکردی: 1 ترتیبی، 0 ترکیبی، 2 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: `N_INPUTS`, `N_HIDDEN`, `N_OUTPUTS`, `LANES`, `SRAM_LATENCY`, `SOURCE_KIND`, `INIT_FILE`, `FC2_WEIGHTS_FILE`. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

برای سازگاری Verilog-2005 با ModelSim 2020، فهرست پورت‌ها non-ANSI است؛ ثابت‌های مشتق قبل از اعلان نوع و عرض پورت‌ها قرار دارند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. layout and widths derive only from network parameters.
2. raw files stay 16-bit/neuron-major; rows are assembled inside SRAM.
3. a request sampled at E is sampled downstream at E+SRAM_LATENCY.
