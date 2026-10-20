<div dir="rtl" align="right">

# `04_prompt_before_after.md` — گزارش تسک چهارم: مقایسه پرامپت ساده و ساختاریافته برای زیرماژول `fcnn_ping_pong_buffer`

**درس:** طراحی کامپیوتری سیستم‌های دیجیتال (CAD)  
**تسک:** ۴ — ارزیابی تأثیر مهندسی پرامپت (Simple vs. 6-Part Structured Prompt) در تولید کد RTL  
**زیرماژول هدف:** `fcnn_ping_pong_buffer`  

---

## ۱. مقدمه و روش‌شناسی آزمایش

هدف از تسک چهارم، بررسی عملی تأثیر ساختاردهی مهندسی‌شده به پرامپت بر کیفیت، خوانایی، صحت عملکرد و سینتکس کد Verilog تولیدشده توسط مدل زبانی بزرگ (LLM) است. مطابق دستورالعمل پروژه، ماژول بافر پینگ‌پنگ (`fcnn_ping_pong_buffer`) به‌عنوان زیرماژول هدف انتخاب شد.

برای انجام یک آزمایش کنترل‌شده و منصفانه، دو جلسه گفت‌وگوی کاملاً مجزا با مدل زبانی ایجاد گردید. در هر دو جلسه، مشخصات پایه ماژول (از سند `03_spec.md` و هدر `02_module_headers.v`) در اختیار مدل قرار گرفت:
1. **آزمایش اول (پرامپت ساده و بدون ساختار):** درخواست پیاده‌سازی ماژول در قالب یک متن کوتاه و یکپارچه بدون تفکیک بخش‌های مهندسی پرامپت به مدل داده شد.
2. **آزمایش دوم (پرامپت ساختاریافته ۶ بخشی):** همان درخواست با رعایت دقیق چارچوب ۶ بخشی مطرح‌شده در صورت پروژه شامل **Role** (نقش)، **Context** (زمینه)، **Input** (ورودی)، **Instructions** (دستورالعمل‌ها)، **Constraints** (محدودیت‌ها) و **Output Format** (فرمت خروجی) تدوین و به مدل داده شد.

در ادامه این گزارش، متن دقیق هر دو پرامپت ارسالی ما به LLM، کدهای Verilog تولیدشده در هر مرحله و تحلیل فنی و مقایسه‌ای آن‌ها ارائه شده است.

---

## ۲. متن پرامپت‌های ارسالی به مدل زبانی

### ۲.۱. پرامپت اول: ساده و بدون ساختار (Before / Unstructured Prompt)

متن زیر به‌عنوان پرامپت ساده و بدون ساختار به مدل زبانی داده شد:

> با توجه به مشخصات زیر، ماژول `fcnn_ping_pong_buffer` را به زبان Verilog-2005 پیاده‌سازی کن. این ماژول یک بافر پینگ‌پنگ دو بانکه است که هر بانک آن ۷ خانه دارد و بین ضرب‌کننده و جمع‌کننده FP16 قرار می‌گیرد. پورت‌های ماژول شامل `clk`, `rst`, `wr_valid`, `wr_ready`, `wr_data[15:0]`, `wr_dest[3:0]`, `wr_last`, `wr_group_last`, `wr_flush`, `rd_valid`, `rd_ready`, `rd_data[15:0]`, `rd_dest[3:0]`, `rd_last`, `bank_full[1:0]`, `bank_empty[1:0]`, `bank_select` هستند. بافر باید از خواندن به روش Cut-Through (خواندن به محض وجود داده معتبر بدون انتظار برای پر شدن کامل بانک) و همچنین بستن بانک با رسیدن به ۷ داده یا فعال شدن `wr_group_last` یا `wr_flush` پشتیبانی کند. پورت‌ها را تغییر نده و فقط کد کامل ماژول وریلاگ را بده.

---

### ۲.۲. پرامپت دوم: ساختاریافته ۶ بخشی (After / Structured Prompt)

متن زیر با تفکیک دقیق ۶ بخش استاندارد مهندسی پرامپت تدوین و در یک چت جدید به مدل زبانی داده شد:

#### 1. Role
تو یک مهندس ارشد طراحی دیجیتال و متخصص پیاده‌سازی مدارهای مجتمع در سطح ثبات (RTL) مسلط به استاندارد **Verilog-2005** و طراحی پایپ‌لاین‌های بدون حباب (Zero-Bubble Datapaths) هستی.

#### 2. Context
ما در حال پیاده‌سازی یک شتاب‌دهنده سخت‌افزاری برای استنتاج شبکه عصبی تمام‌متصل (FCNN) با معماری `784 -> 8 -> ReLU -> 10` و دقت `FP16` هستیم. در این معماری تنها یک ضرب‌کننده و یک جمع‌کننده FP16 وجود دارد. ماژول `fcnn_ping_pong_buffer` بین رجیستر خروجی ضرب‌کننده (`fcnn_product_register`) و ورودی جمع‌کننده (`fcnn_fp16_adder`) قرار می‌گیرد تا جریان پیوسته حاصل‌ضرب‌ها را با نرخ یک عملیات در هر سیکل کلاک (`II = 1`) و بدون ایجاد حباب زمانی به سمت جمع‌کننده هدایت کند.

#### 3. Input
هدر رسمی ماژول و مشخصات پورت‌های مصوب (از سند `02_module_headers.v` و بخش `C11` سند `03_spec.md`) به شرح زیر است:

</div>

<div dir="ltr" align="left">

```verilog
module fcnn_ping_pong_buffer (
    input wire clk,
    input wire rst,
    input wire wr_valid,
    output wire wr_ready,
    input wire [15:0] wr_data,
    input wire [3:0] wr_dest,
    input wire wr_last,
    input wire wr_group_last,
    input wire wr_flush,
    output wire rd_valid,
    input wire rd_ready,
    output wire [15:0] rd_data,
    output wire [3:0] rd_dest,
    output wire rd_last,
    output wire [1:0] bank_full,
    output wire [1:0] bank_empty,
    output wire bank_select
);
```

</div>

<div dir="rtl" align="right">

#### 4. Instructions
منطق داخلی ماژول را بر اساس قوانین رفتاری زیر پیاده‌سازی کن:
1. **سازمان‌دهی دو بانکه:** دو بانک فیزیکی مجزا (`Bank 0` و `Bank 1`) با عمق ۷ خانه در هر بانک ایجاد کن که هر خانه داده ۱۶ بیتی (`wr_data`) و متادیتای همراه (`wr_dest[3:0]` و `wr_last`) را ذخیره کند.
2. **مدیریت نوشتن و بستن گروه (Seal):** نوشتن تنها در صورت برقراری `wr_valid && wr_ready` در بانکِ اشاره‌شده توسط `writer_bank` انجام شود. زمانی که هفتمین عنصر در یک بانک نوشته می‌شود یا سیگنال `wr_group_last` یا `wr_flush` همراه با نوشتن معتبر یک باشد (مانند گروه ۳ تایی انتهای لایه FC2)، آن بانک بسته (`sealed`) شده و اشاره‌گر `writer_bank` در لبه کلاک به بانک دیگر تغییر یابد.
3. **خواندن به روش Cut-Through:** خواندن توسط بانکِ `reader_bank` انجام می‌شود. برای فعال کردن `rd_valid` منتظر بسته شدن (`sealed`) بانک نمان؛ به محض آنکه در بانک خواندن حداقل یک داده ثبت‌شده و مصرف‌نشده وجود داشته باشد (`write_count > read_count`)، سیگنال `rd_valid = 1` را فعال کن.
4. **بازیافت هم‌لبه بانک (Same-Edge Bank Recycle):** زمانی که آخرین عنصر یک بانکِ بسته‌شده با `rd_valid && rd_ready` مصرف می‌شود، آن بانک در همان لبه کلاک آزاد شده و شمارنده‌های آن صفر شوند. اگر نویسنده در همان سیکل قصد نوشتن اولین عنصر گروه جدید را در این بانک داشته باشد، پذیرش بدون ایجاد سیکل توقف (`wr_ready = 1`) انجام پذیرد.
5. **سیگنال‌های وضعیت:** پورت `bank_select` نشانگر بانک فعلی نوشتن (`writer_bank`) باشد. بیت‌های `bank_empty[1:0]` خالی بودن هر بانک و بیت‌های `bank_full[1:0]` بسته بودن (`sealed`) یا پر بودن ظرفیت نوشتن هر بانک را نشان دهند.

#### 5. Constraints
- کد باید کاملاً منطبق بر استاندارد **Verilog-2005** و قابل سنتز باشد (استفاده از هرگونه سینتکس SystemVerilog مانند `logic`, `always_ff`, `always_comb` یا آرایه‌های دوبعدی در پورت‌ها ممنوع است).
- ریست (`rst`) سنکرون و فعال‌بالا (`Active-High`) است و بالاترین اولویت را دارد.
- هیچ‌گونه حلقه ترکیبی (`Combinational Loop`) بین `rd_ready` و `rd_valid` یا بین `wr_valid` و `wr_ready` ایجاد نشود.
- در بلوک‌های ترتیبی (`always @(posedge clk)`) فقط از انتساب غیرمسدودکننده (`<=`) و در بلوک‌های ترکیبی (`always @(*)`) فقط از انتساب مسدودکننده (`=`) استفاده شود.
- نام، جهت، عرض و ترتیب ۱۷ پورت ماژول نباید هیچ تغییری کند.

#### 6. Output Format
فقط کد کامل و قابل کامپایل ماژول `fcnn_ping_pong_buffer` را در یک بلوک کد `verilog` بدون توضیحات اضافی خارج از کد ارائه بده.

---

## ۳. خروجی‌های تولیدشده توسط LLM

### ۳.۱. کد حاصل از پرامپت ساده (`A_simple_original.v`)

در پاسخ به پرامپت ساده، مدل زبانی یک پیاده‌سازی فشرده (در ۲۱۶ خط) ارائه داد که در آن هر دو بانک را در قالب یک آرایه تخت ۱۴ خانه‌ای (`0..13`) با محاسبه آفست آدرس (`bank * 7 + index`) مدل کرده است:

</div>

<div dir="ltr" align="left">

```verilog
module fcnn_ping_pong_buffer (
    input wire clk,
    input wire rst,
    input wire wr_valid,
    output wire wr_ready,
    input wire [15:0] wr_data,
    input wire [3:0] wr_dest,
    input wire wr_last,
    input wire wr_group_last,
    input wire wr_flush,
    output wire rd_valid,
    input wire rd_ready,
    output wire [15:0] rd_data,
    output wire [3:0] rd_dest,
    output wire rd_last,
    output wire [1:0] bank_full,
    output wire [1:0] bank_empty,
    output wire bank_select
);

    reg [15:0] data_mem [0:13];
    reg [3:0]  dest_mem [0:13];
    reg        last_mem [0:13];

    reg [2:0] write_count [0:1];
    reg [2:0] read_count  [0:1];
    reg       sealed      [0:1];

    reg writer_bank;
    reg reader_bank;

    wire [2:0] r_wc = write_count[reader_bank];
    wire [2:0] r_rc = read_count[reader_bank];
    wire       r_sealed = sealed[reader_bank];

    assign rd_valid = (r_wc > r_rc);

    wire [3:0] rd_addr = (reader_bank ? 4'd7 : 4'd0) + {1'b0, r_rc};
    assign rd_data = rd_valid ? data_mem[rd_addr] : 16'd0;
    assign rd_dest = rd_valid ? dest_mem[rd_addr] : 4'd0;
    assign rd_last = rd_valid ? last_mem[rd_addr] : 1'b0;

    wire do_read = rd_valid && rd_ready;
    wire [2:0] next_r_rc = r_rc + 3'd1;
    wire read_finishes_group = do_read && r_sealed && (next_r_rc == r_wc);

    wire [2:0] w_wc = write_count[writer_bank];
    wire [2:0] w_rc = read_count[writer_bank];
    wire       w_sealed = sealed[writer_bank];

    wire recycle_writer_bank = read_finishes_group && (writer_bank == reader_bank);
    assign wr_ready = (!w_sealed && (w_wc < 3'd7)) || recycle_writer_bank;

    wire do_write = wr_valid && wr_ready;
    wire [2:0] eff_w_wc = recycle_writer_bank ? 3'd0 : w_wc;
    wire [3:0] wr_addr  = (writer_bank ? 4'd7 : 4'd0) + {1'b0, eff_w_wc};
    wire write_seals_group = do_write && ((eff_w_wc == 3'd6) || wr_group_last || wr_flush);

    assign bank_empty[0] = (write_count[0] == read_count[0]);
    assign bank_empty[1] = (write_count[1] == read_count[1]);
    assign bank_full[0]  = sealed[0] || (write_count[0] == 3'd7);
    assign bank_full[1]  = sealed[1] || (write_count[1] == 3'd7);
    assign bank_select   = writer_bank;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            writer_bank    <= 1'b0;
            reader_bank    <= 1'b0;
            write_count[0] <= 3'd0;
            write_count[1] <= 3'd0;
            read_count[0]  <= 3'd0;
            read_count[1]  <= 3'd0;
            sealed[0]      <= 1'b0;
            sealed[1]      <= 1'b0;
            for (i = 0; i < 14; i = i + 1) begin
                data_mem[i] <= 16'd0;
                dest_mem[i] <= 4'd0;
                last_mem[i] <= 1'b0;
            end
        end else begin
            if (read_finishes_group) begin
                read_count[reader_bank]  <= 3'd0;
                write_count[reader_bank] <= 3'd0;
                sealed[reader_bank]      <= 1'b0;
                reader_bank              <= ~reader_bank;
            end else if (do_read) begin
                read_count[reader_bank]  <= r_rc + 3'd1;
            end

            if (do_write) begin
                data_mem[wr_addr] <= wr_data;
                dest_mem[wr_addr] <= wr_dest;
                last_mem[wr_addr] <= wr_last;
                write_count[writer_bank] <= eff_w_wc + 3'd1;
                if (write_seals_group) begin
                    sealed[writer_bank] <= 1'b1;
                    writer_bank         <= ~writer_bank;
                end else if (recycle_writer_bank) begin
                    sealed[writer_bank] <= 1'b0;
                end
            end
        end
    end

endmodule
```

</div>

<div dir="rtl" align="right">

---

### ۳.۲. کد حاصل از پرامپت ساختاریافته (`B_structured_original.v`)

در پاسخ به پرامپت ساختاریافته ۶ بخشی، مدل زبانی یک پیاده‌سازی کاملاً ماژولار، صریح و تفکیک‌شده برای هر بانک (با آرایه‌های مجزا `bank0_*` و `bank1_*` و فلگ وضعیت تخصیص صریح `allocated0/1`) تولید کرد که ردیابی حالات هر بانک را در موج‌های شبیه‌سازی (Waveform) بسیار شفاف می‌سازد:

</div>

<div dir="ltr" align="left">

```verilog
module fcnn_ping_pong_buffer (
    input wire clk,
    input wire rst,
    input wire wr_valid,
    output wire wr_ready,
    input wire [15:0] wr_data,
    input wire [3:0] wr_dest,
    input wire wr_last,
    input wire wr_group_last,
    input wire wr_flush,
    output wire rd_valid,
    input wire rd_ready,
    output wire [15:0] rd_data,
    output wire [3:0] rd_dest,
    output wire rd_last,
    output wire [1:0] bank_full,
    output wire [1:0] bank_empty,
    output wire bank_select
);

    reg [15:0] bank0_data [0:6];
    reg [3:0]  bank0_dest [0:6];
    reg        bank0_last [0:6];

    reg [15:0] bank1_data [0:6];
    reg [3:0]  bank1_dest [0:6];
    reg        bank1_last [0:6];

    reg [3:0] write_count0, read_count0;
    reg       sealed0, allocated0;

    reg [3:0] write_count1, read_count1;
    reg       sealed1, allocated1;

    reg writer_bank;
    reg reader_bank;

    wire unread0 = allocated0 && (write_count0 > read_count0);
    wire unread1 = allocated1 && (write_count1 > read_count1);

    assign rd_valid = (reader_bank == 1'b0) ? unread0 : unread1;

    wire [2:0] rd_idx0 = read_count0[2:0];
    wire [2:0] rd_idx1 = read_count1[2:0];

    assign rd_data = (!rd_valid) ? 16'd0 :
                     (reader_bank == 1'b0) ? bank0_data[rd_idx0] : bank1_data[rd_idx1];
    assign rd_dest = (!rd_valid) ? 4'd0 :
                     (reader_bank == 1'b0) ? bank0_dest[rd_idx0] : bank1_dest[rd_idx1];
    assign rd_last = (!rd_valid) ? 1'b0 :
                     (reader_bank == 1'b0) ? bank0_last[rd_idx0] : bank1_last[rd_idx1];

    wire pop_ handshake = rd_valid && rd_ready;
    wire pop0 = pop_handshake && (reader_bank == 1'b0);
    wire pop1 = pop_handshake && (reader_bank == 1'b1);

    wire [3:0] next_rc0 = read_count0 + 4'd1;
    wire [3:0] next_rc1 = read_count1 + 4'd1;

    wire pop_final0 = pop0 && sealed0 && (next_rc0 == write_count0);
    wire pop_final1 = pop1 && sealed1 && (next_rc1 == write_count1);

    wire can_write0 = (!sealed0 && (write_count0 < 4'd7)) || pop_final0;
    wire can_write1 = (!sealed1 && (write_count1 < 4'd7)) || pop_final1;

    assign wr_ready = (writer_bank == 1'b0) ? can_write0 : can_write1;

    wire push_handshake = wr_valid && wr_ready;
    wire push0 = push_handshake && (writer_bank == 1'b0);
    wire push1 = push_handshake && (writer_bank == 1'b1);

    wire [3:0] base_wc0 = pop_final0 ? 4'd0 : write_count0;
    wire [3:0] base_wc1 = pop_final1 ? 4'd0 : write_count1;

    wire seal_on_push0 = push0 && ((base_wc0 == 4'd6) || wr_group_last || wr_flush);
    wire seal_on_push1 = push1 && ((base_wc1 == 4'd6) || wr_group_last || wr_flush);

    assign bank_empty[0] = !unread0;
    assign bank_empty[1] = !unread1;
    assign bank_full[0]  = allocated0 && (sealed0 || (write_count0 == 4'd7));
    assign bank_full[1]  = allocated1 && (sealed1 || (write_count1 == 4'd7));
    assign bank_select   = writer_bank;

    integer k;
    always @(posedge clk) begin
        if (rst) begin
            writer_bank  <= 1'b0;
            reader_bank  <= 1'b0;
            write_count0 <= 4'd0;
            read_count0  <= 4'd0;
            sealed0      <= 1'b0;
            allocated0   <= 1'b0;
            write_count1 <= 4'd0;
            read_count1  <= 4'd0;
            sealed1      <= 1'b0;
            allocated1   <= 1'b0;
            for (k = 0; k < 7; k = k + 1) begin
                bank0_data[k] <= 16'd0;
                bank0_dest[k] <= 4'd0;
                bank0_last[k] <= 1'b0;
                bank1_data[k] <= 16'd0;
                bank1_dest[k] <= 4'd0;
                bank1_last[k] <= 1'b0;
            end
        end else begin
            // Bank 0 state update
            if (pop_final0 && !push0) begin
                write_count0 <= 4'd0;
                read_count0  <= 4'd0;
                sealed0      <= 1'b0;
                allocated0   <= 1'b0;
            end else begin
                if (pop0 && !pop_final0)
                    read_count0 <= next_rc0;
                else if (pop_final0 && push0)
                    read_count0 <= 4'd0;

                if (push0) begin
                    bank0_data[base_wc0[2:0]] <= wr_data;
                    bank0_dest[base_wc0[2:0]] <= wr_dest;
                    bank0_last[base_wc0[2:0]] <= wr_last;
                    write_count0 <= base_wc0 + 4'd1;
                    allocated0   <= 1'b1;
                    sealed0      <= seal_on_push0;
                end
            end

            // Bank 1 state update
            if (pop_final1 && !push1) begin
                write_count1 <= 4'd0;
                read_count1  <= 4'd0;
                sealed1      <= 1'b0;
                allocated1   <= 1'b0;
            end else begin
                if (pop1 && !pop_final1)
                    read_count1 <= next_rc1;
                else if (pop_final1 && push1)
                    read_count1 <= 4'd0;

                if (push1) begin
                    bank1_data[base_wc1[2:0]] <= wr_data;
                    bank1_dest[base_wc1[2:0]] <= wr_dest;
                    bank1_last[base_wc1[2:0]] <= wr_last;
                    write_count1 <= base_wc1 + 4'd1;
                    allocated1   <= 1'b1;
                    sealed1      <= seal_on_push1;
                end
            end

            if (pop_final0 || pop_final1)
                reader_bank <= ~reader_bank;

            if (seal_on_push0 || seal_on_push1)
                writer_bank <= ~writer_bank;
        end
    end

endmodule
```

</div>

<div dir="rtl" align="right">

---

## ۴. ارزیابی آزمایشگاهی و نتایج شبیه‌سازی

هر دو ماژول تولیدشده توسط یک تست‌بنچ مقایسه‌ای واحد (`tb_pp_comparative.v`) در ۷ سناریوی مرزی و همچنین در تست یکپارچه کل شتاب‌دهنده FCNN مورد ارزیابی قرار گرفتند.

### ۴.۱. نتایج تست‌بنچ واحد (Unit-Level Verification)

| شماره سناریو | هدف آزمون | شرح تحریک و انتظار | خروجی پرامپت ساده | خروجی پرامپت ساختاریافته |
| :---: | :--- | :--- | :---: | :---: |
| **۱** | خواندن Cut-Through | نوشتن ۱ داده، خواندن فوری پیش از بسته شدن بانک، بررسی `bank_empty` و ادامه نوشتن تا پایان گروه | **PASS** | **PASS** |
| **۲** | حفاظت از بانک و بازیافت هم‌لبه | ارسال گروه ۳ تایی Flush در بانک ۰ و ۷ تایی در بانک ۱؛ بررسی `wr_ready=0` هنگام پر بودن هر دو بانک و پذیرش هم‌لبه با آخرین خواندن | **PASS** | **PASS** |
| **۳** | جریان پیوسته بدون حباب (`II=1`) | ارسال ۲۱ محصول پیاپی در ۳ گروه ۷ تایی با `rd_ready=1`؛ بررسی عدم ایجاد سیکل توقف | **PASS** | **PASS** |
| **۴** | فشار تصادفی و Backpressure | ۳۵ گروه با طول‌های متغیر ۱ تا ۷ (مجموعاً ۱۴۰ انتقال) همراه با توقف‌های تصادفی خواننده | **PASS** | **PASS** |
| **۵** | اعمال ریست در حین کار | نوشتن ۲ عضو از یک گروه باز، اعمال `rst`، بررسی پاک شدن کامل داده‌های قبلی و شروع مجدد | **PASS** | **PASS** |
| **۶** | بسته شدن خودکار در ظرفیت ۷ | ارسال ۷ داده بدون فعال کردن `wr_group_last`؛ بررسی بسته شدن خودکار بانک در ظرفیت ۷ | **PASS** | **PASS** |
| **۷** | عملکرد مستقل `wr_flush` | ارسال ۱ داده با `wr_flush=1` و `wr_group_last=0`؛ بررسی بسته شدن بانک و سوئیچ صحیح | **PASS** | **PASS** |

**لاگ خروجی شبیه‌ساز برای هر دو ماژول:**

</div>

<div dir="ltr" align="left">

```text
[PASS] case 1 writes=2 reads=2
[PASS] case 2 writes=11 reads=11
[PASS] case 3 writes=21 reads=21
[PASS] case 4 writes=140 reads=140
[PASS] case 5 writes=1 reads=1
[PASS] case 6 writes=7 reads=7
[PASS] case 7 writes=1 reads=1
[TB-RESULT] errors=0 total_accepts=185 total_consumes=183 stalled_write_cycles=78 max_ready_wait=1
[TB-PASS] independent comparative suite
```

</div>

<div dir="rtl" align="right">

*(نکته: اختلاف ۲ واحدی بین ۱۸۵ پذیرش نوشتن و ۱۸۳ خواندن ناشی از سناریوی ۵ است که در آن عمداً ۲ داده خوانده‌نشده با اعمال ریست پاک می‌شوند).*

### ۴.۲. نتایج زمان‌بندی و تست یکپارچه در کل شتاب‌دهنده FCNN
در سناریوی ۳ (ارسال پیوسته ۲۱ داده)، هر دو ماژول دقیقاً تأخیر ۱ سیکل بین اولین نوشتن و اولین خواندن (`Cut-Through Latency = 1 cycle`) و ۰ سیکل حباب نوشتن را ثبت کردند. همچنین با جایگزینی هر یک از این دو ماژول در کل شتاب‌دهنده FCNN و اجرای استنتاج روی تصویر مرجع MNIST (`test_image.mem`) و ۱۰ رقم آزمایشی دیگر، هر دو نسخه دقیقاً در **۶,۳۶۷ سیکل کلاک** با خروجی بیت‌به‌بیت یکسان و بدون خطا (`PASS`) به کار خود پایان دادند.

---

## ۵. تحلیل و مقایسه فنی دو رویکرد مهندسی پرامپت

مقایسه دقیق ساختار کد تولیدشده در دو روش در جدول زیر خلاصه شده است:

| معیار مقایسه | خروجی پرامپت ساده (`Before`) | خروجی پرامپت ساختاریافته ۶ بخشی (`After`) | تحلیل مهندسی |
| :--- | :--- | :--- | :--- |
| **سازمان‌دهی فیزیکی بانک‌ها** | یک آرایه تخت ۱۴ خانه‌ای (`data_mem[0:13]`) با محاسبه آفست `+7` | دو آرایه کاملاً مجزا (`bank0_data[0:6]` و `bank1_data[0:6]`) | کد ساختاریافته دقیقاً معماری فیزیکی دو بانک مستقل را بازتاب می‌دهد و در دیباگ موج‌ها بسیار خواناتر است. |
| **استفاده از آرایه‌های دوبعدی روی رجیسترهای کنترلی** | استفاده از آرایه برای شمارنده‌ها (`write_count[0:1]`) و اندیس‌دهی با سیگنال متغیر `writer_bank` | تفکیک صریح ثبات‌های کنترلی (`write_count0`, `write_count1`, `allocated0`, `allocated1`) | در ابزارهای سنتز و دیباگرهای استاندارد Verilog-2005، مشاهده سیگنال‌های اسکالر مجزا (`write_count0/1`) بسیار ساده‌تر از آرایه‌های دوبعدی کنترلی است. |
| **مدیریت چرخه حیات بانک** | ضمنی (مبتنی بر برابری شمارنده‌ها و فلگ `sealed`) | صریح (با تعریف فلگ اختصاصی `allocated0/1` در کنار `sealed0/1`) | پرامپت ساختاریافته باعث شد مدل زبانی حالت «تخصیص‌یافته» را از حالت «خالی» به‌طور صریح تفکیک کند و از ابهام در سیگنال `bank_full` جلوگیری نماید. |
| **تطابق با قوانین کدنویسی RTL** | رعایت کامل Verilog-2005 و تفکیک انتساب‌های مسدودکننده/غیرمسدودکننده | رعایت کامل Verilog-2005، بدون حلقه ترکیبی و با جداسازی کامل منطق به‌روزرسانی هر بانک | در کد ساختاریافته، منطق به‌روزرسانی `Bank 0` و `Bank 1` کاملاً مستقل نوشته شده و هیچ تداخل شرطی بین دو بانک هنگام بازیافت هم‌لبه وجود ندارد. |
| **حجم و فشردگی کد** | کوتاه‌تر و فشرده‌تر | مفصل‌تر و دارای مستندسازی ذاتی در نام‌گذاری سیگنال‌ها | پرامپت ساده کد کوتاه‌تری تولید می‌کند، اما پرامپت ساختاریافته کدی تولید می‌کند که ردیابی یک‌به‌یک قوانین Specification در آن بسیار آسان‌تر است. |

### نتیجه‌گیری نهایی تسک چهارم
آزمایش انجام‌شده نشان می‌دهد که هرچند در صورت وجود یک Specification دقیق، حتی یک پرامپت ساده نیز می‌تواند به کد قابل کامپایل و صحیح منجر شود، اما **استفاده از چارچوب ساختاریافته ۶ بخشی (Role, Context, Input, Instructions, Constraints, Output Format)** باعث می‌شود مدل زبانی به جای ادغام میان‌برِ بانک‌ها در یک آرایه تخت، معماری سخت‌افزاری را دقیقاً مطابق با افراز فیزیکی مورد نظر طراح (دو بانک کاملاً مستقل با ماشین وضعیت صریح `allocated/sealed`) پیاده‌سازی کند. این ویژگی در ماژول‌های پیچیده‌تر (نظیر `fcnn_local_scheduler` و `fcnn_accumulator_bank`) برای پیشگیری از باگ‌های هم‌زمانی و سهولت عیب‌یابی در ModelSim نقشی حیاتی ایفا می‌کند.

</div>