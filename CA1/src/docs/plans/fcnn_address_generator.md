# برنامه جاری fcnn_address_generator

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_address_generator.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 1 ترتیبی، 0 ترکیبی، 0 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: `N_INPUTS`, `N_HIDDEN`, `N_OUTPUTS`, `LANES`. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

برای سازگاری Verilog-2005 با ModelSim 2020، فهرست پورت‌ها non-ANSI است؛ ثابت‌های مشتق قبل از اعلان نوع و عرض پورت‌ها قرار دارند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. one owner for request progress; Scheduler reads these counters.
2. advance exactly once per accepted request.
3. physical row addresses. Metadata = {layer, hidden_neuron, row}.
