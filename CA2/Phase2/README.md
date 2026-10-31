📋 Task Board: Phase 2 – Structural Components (Actel Synthesis)

این سند شامل مشخصات دقیق تمام کامپوننت‌های سطح پایین (Low-level Components) است که باید برای جایگزینی کدهای رفتاری (Behavioral) در ماژول‌های فاز اول شبکه عصبی، به‌جز ماژول‌های مستثنی‌شده، به‌صورت ساختاری (Structural) طراحی و پیاده‌سازی شوند.

با استفاده از این کامپوننت‌ها، منطق رفتاری موجود در ماژول‌ها به مدارهای سطح پایین‌تر تبدیل می‌شود تا امکان سنتز ساختاری با کتابخانه Actel فراهم شود.

1. 🧮 کامپوننت‌های حسابی (Arithmetic Components)

با توجه به پارامترهای ثابت پروژه:

LANES = 7

N_HIDDEN = 8

N_INPUTS = 784

FC1_ROWS = 112

نیازی به طراحی ضرب‌کننده و تقسیم‌کننده عمومی نیست. این کامپوننت‌ها عمدتاً برای محاسبات آدرس و زمان‌بندی استفاده می‌شوند.

1.1. افزاینده n-بیتی (N-bit Incrementer)

تعریف ماژول:

module ac_inc_n #(parameter W = 1) (
    input wire [W-1:0] a,
    output wire [W-1:0] y
);

کاربرد:

جایگزینی عملیات + 1 در شمارنده‌های fcnn_local_scheduler و fcnn_address_generator.

استراتژی پیاده‌سازی:

ساخت زنجیره‌ای از نیم‌جمع‌کننده‌ها (ac_ha) که ورودی Carry اولین نیم‌جمع‌کننده برابر 1 است.

1.2. کاهنده n-بیتی (N-bit Decrementer)

تعریف ماژول:

module ac_dec_n #(parameter W = 1) (
    input wire [W-1:0] a,
    output wire [W-1:0] y
);

کاربرد:

جایگزینی عملیات request_wait - 1 در fcnn_local_scheduler.

استراتژی پیاده‌سازی:

جمع مقدار a با تمام بیت‌های یک (کد مکمل دو برای عدد منفی یک)، با استفاده از ac_add.

1.3. ضرب‌کننده ثابت در 7 (Multiply by LANES)

تعریف ماژول:

module ac_mult_const_7 #(parameter W = 32) (
    input wire [W-1:0] a,
    output wire [W+2:0] y
);

کاربرد:

جایگزینی عملیات row_num * LANES در fcnn_operand_router.

استراتژی پیاده‌سازی:

پیاده‌سازی معادله زیر:

[
y = (a \ll 3) - a
]

استفاده از تفریق‌گر ساختاری (جمع با وارون a و Carry برابر 1).

1.4. ضرب‌کننده ثابت در 112 (Multiply by FC1_ROWS)

تعریف ماژول:

module ac_mult_const_112 #(parameter W = 32) (
    input wire [W-1:0] a,
    output wire [W+6:0] y
);

کاربرد:

جایگزینی عملیات neuron_reg * FC1_ROWS در fcnn_address_generator.

استراتژی پیاده‌سازی:

پیاده‌سازی معادله زیر:

[
y = (a \ll 7) - (a \ll 4)
]

1.5. مقسوم‌علیه و باقی‌مانده ثابت 7 (Div & Mod by 7)

تعریف ماژول:

module ac_div_mod_7 #(parameter W = 32) (
    input wire [W-1:0] a,
    output wire [W-1:0] q, // Quotient
    output wire [2:0] r    // Remainder
);

کاربرد:

جایگزینی عملیات scalar_idx / 7 و scalar_idx % 7 برای محاسبه dest_idx و hidden_idx در fcnn_operand_router.

استراتژی پیاده‌سازی:

به دلیل کوچک بودن دامنه اعداد (حداکثر 112)، می‌توان از بلوک‌های متوالی تفریق شرطی (Conditional Subtraction) استفاده کرد.

2. ⚖️ کامپوننت‌های مقایسه‌گر (Comparators)

2.1. مقایسه‌گر برابری (N-bit Equality)

تعریف ماژول:

module ac_cmp_eq_n #(parameter W = 1) (
    input wire [W-1:0] a,
    input wire [W-1:0] b,
    output wire eq
);

کاربرد:

جایگزینی شرط weight_meta == input_meta در fcnn_operand_router و سایر مقایسه‌های برابری متغیر.

استراتژی پیاده‌سازی:

استفاده از یک آرایه ac_xor (سلول C1) برای مقایسه بیت‌به‌بیت و سپس استفاده از ac_reduce_and (با معکوس کردن خروجی XORها) برای تولید خروجی نهایی.

2.2. مقایسه‌گر کوچک‌تر (N-bit Less-Than)

تعریف ماژول:

module ac_cmp_lt_n #(parameter W = 1) (
    input wire [W-1:0] a,
    input wire [W-1:0] b,
    output wire lt
);

کاربرد:

جایگزینی شرط‌هایی مانند scalar_idx < FC2_MAIN و شرط‌های مربوط به محدوده حلقه‌ها.

استراتژی پیاده‌سازی:

ایجاد تغییر جزئی در ماژول ac_ge موجود در کتابخانه (actel_logic.v).

محاسبه شرط a < b دقیقاً معادل خروجی Carry معکوس در عملیات a - b است.

3. 💾 کامپوننت‌های ترتیبی و رجیسترها (Storage Elements)

هدف این بخش، حذف کامل تمامی بلاک‌های always @(posedge clk) در ماژول‌های روتر، کنترلر و سایر ماژول‌های مرتبط است.

3.1. رجیستر N-بیتی با Enable (N-bit DFF with Enable)

تعریف ماژول:

module ac_dffe_n #(parameter W = 1) (
    input wire clk,
    input wire rst,
    input wire en,
    input wire [W-1:0] d,
    output wire [W-1:0] q
);

کاربرد:

ذخیره مقادیر متغیرهای reg در تمام ماژول‌ها؛ برای مثال:

stored_data در fcnn_row_stage

وضعیت (State) در fcnn_controller

استراتژی پیاده‌سازی:

ایجاد آرایه‌ای به طول W از ماژول‌های s2 یا ac_dffe.

3.2. رجیستر فایل کامل (N-Depth Register File)

تعریف ماژول:

module ac_regfile #(
    parameter DATA_W = 16,
    parameter DEPTH = 10,
    parameter ADDR_W = 4
) (
    input wire clk,
    input wire rst,
    input wire wr_en,
    input wire [ADDR_W-1:0] wr_addr,
    input wire [DATA_W-1:0] wr_data,
    input wire [ADDR_W-1:0] rd_addr,
    output wire [DATA_W-1:0] rd_data,

    // خروجی موازی برای لاجیک‌های نهایی
    output wire [DATA_W*DEPTH-1:0] parallel_out
);

کاربرد:

جایگزینی آرایه‌های زیر:

fc2_acc در انباشت‌گر

rf_mem در fcnn_activation_regfile

استراتژی پیاده‌سازی:

این کامپوننت شامل بخش‌های زیر است:

یک دیکدر ac_decoder_n برای تبدیل wr_addr به سیگنال‌های Enable مجزا برای هر رجیستر.

مجموعه‌ای از ماژول‌های ac_dffe_n برای ذخیره‌سازی داده‌ها.

یک ماژول ac_mux_array_n برای خواندن داده‌ها.

4. 🔀 کامپوننت‌های مسیریابی و منطق (Routing & Logic)

4.1. دیکدر آدرس (N-to-2^N Decoder)

تعریف ماژول:

module ac_decoder_n #(parameter ADDR_W = 4) (
    input wire en,
    input wire [ADDR_W-1:0] addr,
    output wire [(1<<ADDR_W)-1:0] out
);

کاربرد:

تخصیص مقادیر ماسک مانند 1 << active_dest و هدایت سیگنال‌های Write Enable.

استراتژی پیاده‌سازی:

استفاده از درخت گیت‌های ac_and و ac_not (سلول‌های C1 و C2).

4.2. مولتی‌پلکسر آرایه‌ای (Array Multiplexer)

تعریف ماژول:

module ac_mux_array_n #(
    parameter DATA_W = 16,
    parameter CHANNELS = 7,
    parameter SEL_W = 3
) (
    input wire [DATA_W*CHANNELS-1:0] in_data,
    input wire [SEL_W-1:0] sel,
    output wire [DATA_W-1:0] out_data
);

کاربرد:

جایگزینی انتخاب داینامیک آرایه، مانند:

weight_row[16*lane_idx+:16]

در ماژول مسیریاب.

استراتژی پیاده‌سازی:

ساخت درخت آبشاری از ماژول‌های ac_muxv یا ac_mux (سلول C1).

5. ✨ کامپوننت‌های اختصاصی (Custom Logic)

5.1. هسته سخت‌افزاری ReLU برای FP16

تعریف ماژول:

module ac_relu_fp16_core (
    input wire [15:0] x,
    output wire [15:0] y
);

کاربرد:

جایگزینی سینتکس رفتاری در ماژول fcnn_relu_fp16.

استراتژی پیاده‌سازی:

پیاده‌سازی مدار شامل دو بخش اصلی:

الف) مدار تشخیص NaN (is_nan):

استفاده از ac_reduce_and برای بررسی بیت‌های نما (x[14:10]).

استفاده از ac_reduce_or برای بررسی بیت‌های کسر (x[9:0]).

ب) سلکتور خروجی:

استفاده از یک ac_muxv برای انتخاب بین مقدار x و صفر، بر اساس بیت علامت x[15].

استفاده از یک ac_muxv نهایی برای انتخاب بین مقدار مرحله قبل و 16'h7e00 در صورت فعال بودن is_nan.

پایان مشخصات کامپوننت‌های فاز دوم (Phase 2 Structural Components).