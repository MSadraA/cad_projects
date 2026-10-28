# برنامه جاری fcnn_datapath

این برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.

RTL: `rtl/fcnn_datapath.v`؛ نمونه‌ها در hierarchy: 1.

بلوک‌های عملکردی: 0 ترتیبی، 0 ترکیبی، 0 initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.

پارامترها: `N_INPUTS`, `N_HIDDEN`, `N_OUTPUTS`, `LANES`, `SRAM_LATENCY`, `FC1_WEIGHTS_FILE`, `FC2_WEIGHTS_FILE`, `INPUT_FILE`, `FC1_BIAS_FILE`, `FC2_BIAS_FILE`. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.

برای سازگاری Verilog-2005 با ModelSim 2020، فهرست پورت‌ها non-ANSI است؛ ثابت‌های مشتق قبل از اعلان نوع و عرض پورت‌ها قرار دارند.

تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.

1. derived sizes and named interconnect. No user configuration here.
2. request address ownership and the two synchronous SRAM row paths.
3. Scheduler controls handshakes; Router owns arithmetic operand tags.
4. the only FP16 multiplier; registered products enter two-bank PP.
5. the only FP16 adder; the backend mux schedules the separate bias.
6. ReLU -> reused RF -> balanced parallel argmax.
7. local contracts cover phase/tag errors and premature RF reuse.
