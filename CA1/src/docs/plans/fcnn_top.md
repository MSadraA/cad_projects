# برنامه جاری fcnn_top

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_top.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 0 ترتیبی، 0 ترکیبی، 0 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: `N_INPUTS`, `N_HIDDEN`, `N_OUTPUTS`, `LANES`, `SRAM_LATENCY`, `FC1_WEIGHTS_FILE`, `FC2_WEIGHTS_FILE`, `INPUT_FILE`, `FC1_BIAS_FILE`, `FC2_BIAS_FILE`. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. the public configuration boundary. All user choices enter here.
2. control/status only; no arithmetic or storage in Top.
3. propagate every public setting by name.
4. configuration errors are explicit simulation failures.
