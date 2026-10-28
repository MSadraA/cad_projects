# برنامه جاری fcnn_accumulator_bank

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_accumulator_bank.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 1 ترتیبی، 0 ترکیبی، 0 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: `N_HIDDEN`, `N_OUTPUTS`. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

برای سازگاری Verilog-2005 با ModelSim 2020، فهرست پورت‌ها non-ANSI است؛ ثابت‌های مشتق قبل از اعلان نوع و عرض پورت‌ها قرار دارند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. one FC1 accumulator and N_OUTPUTS FC2 accumulators, initially zero.
2. the SAME adder handles products and, one edge later, final bias.
3. look ahead at the final bias commit, including its live result.
4. finalize each neuron only after its separate final bias operation.
