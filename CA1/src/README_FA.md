# شتاب‌دهنده FCNN - نسخه مرتب‌شده مطابق صورت پروژه

مرجع رفتار این نسخه دو فایل `docs/requirements/spec.pdf` و `HW1.pdf` است. تصمیم‌های متفاوت نسخه قبلی اصلاح شده‌اند: **بایاس بعد از جمع همه حاصل‌ضرب‌ها اضافه می‌شود؛ Ping-Pong فقط از بانک تکمیل‌شده می‌خواند.** محاسبات binary16، گردکردن RNE و یک نمونه FP16 ADD و MUL حفظ شده است.

این بسته اصلاح خطای کامپایل گزارش‌شده در **ModelSim Intel FPGA Edition 2020.1** را دارد: در ۹ ماژول، ثابت‌های مشتق پیش از اعلان عرض پورت‌ها قرار گرفته‌اند. کد تجمیعی تسک۵ و headerهای تسک۲ نیز از همین نسخه ساخته شده‌اند. توضیح علت، فایل‌های اصلاح‌شده و حدود تست در `docs/MODELSIM_2020_FIX_FA.md` است. بسته را در پوشه تازه استخراج کنید تا فایل‌های نسخه قبلی با آن مخلوط نشوند.

## اجرای مستقیم در ModelSim برای ارائه

برای این مسیر **Python، فایل golden و plusarg لازم نیست**. در ModelSim پوشه جاری را ریشه `FCNN_Clean` قرار دهید؛ همان پوشه‌ای که `rtl` و `run_modelsim.do` را دارد. سپس در Transcript:

```tcl
do run_modelsim.do
```

این فایل کامپایل، بارگذاری، ثبت موج و اجرای تست‌بنچ را انجام می‌دهد. ۸۷ سیگنال در ۹ گروه Top، Controller، SRAM، Scheduler، MUL، Ping-Pong، Accumulator، RF و TB قرار می‌گیرند. پس از پایان، طراحی و موج‌ها بارگذاری‌شده می‌مانند.

تنظیمات ارائه را **در بلوک پارامتر ابتدای `verification/tb_fcnn.v`** عوض کنید؛ مثلاً:

```verilog
parameter INPUT_FILE="data/cases/digit_7/test_image.mem",
// ... سایر پارامترها در همان فایل ...
parameter integer RUNS=3, RESET_AFTER=0, INJECT_BUSY_START=1,
```

فایل را ذخیره و دوباره `do run_modelsim.do` اجرا کنید. همه مسیرهای وزن، بایاس، تصویر، ابعاد، تأخیر و کلاک از TB قابل تنظیم‌اند. **راهنمای مرحله‌ای ارائه، تغییر ورودی و اجرای قدم‌به‌قدم: `docs/MODELSIM_GUI_FA.md`.**

حالت پیش‌فرض `CHECK_OUTPUTS=0` است: ورودی تازه اجرا و تمام logitها و رقم نمایش داده می‌شوند؛ شمارش، ترتیب عملیات، reset، timeout و Xها همچنان بررسی می‌شوند. پیام `E2E_PROTOCOL` به معنای پاس این قراردادهاست، نه تأیید عددی خروجی با golden. برای مقایسه عددی، `CHECK_OUTPUTS=1` و فایل‌های مرجع همان ورودی/مدل و `EXPECTED_DIGIT` را در TB تعیین کنید. runner پایین همیشه این مقایسه را فعال می‌کند.

## regression عددی با Python

این مسیر برای مقایسه خودکار و مجموعه تست‌هاست. نیازمندی: Python 3.10 یا جدیدتر و ModelSim/Questa یا Icarus در PATH. اسکریپت‌های اصلی به NumPy، PyTorch یا بسته دیگری نیاز ندارند. در ویندوز می‌توان `py -3` را جایگزین `python` کرد. از پوشه اصلی پروژه:

```bash
python scripts/run.py --sim modelsim --cases all --runs 2
```

همین تست‌ها در Icarus:

```bash
python scripts/run.py --sim icarus --cases all --runs 2 --reset-after 100
python scripts/verify.py
python scripts/verify_gui.py
python scripts/audit.py
```

تأییدهای واقعی این تحویل با **Icarus 12.0** انجام شده‌اند؛ ModelSim در محیط بررسی موجود نبود. دستور آن آماده است ولی اجرای موفق ModelSim ادعا نمی‌شود. هر خطای کامپایل، assertion، timeout، خروجی غلط، فایل ناقص یا نبود پیام PASS باعث خروج ناموفق runner می‌شود.

## فایل‌ها را از کجا بخوانیم؟

| مسیر | نقش |
|---|---|
| `rtl/fcnn_top.v` | تنها مرز تنظیمات عمومی و اتصال Controller/Datapath |
| `rtl/files.f` | فهرست یکتای فایل‌های RTL برای کامپایل |
| `rtl/fcnn_controller.v` | FSM چهارحالته شروع، لایه‌ها و پایان |
| `rtl/fcnn_local_scheduler.v` | تقویم SRAM، laneها و هندشیک‌های محلی |
| `verification/tb_fcnn.v` | TB اصلی دارای task، scoreboard، restart، reset و timeout |
| `run_modelsim.do` و `modelsim/wave.do` | اجرای GUI بدون Python و چیدمان موج‌های متصل به RTL جاری |
| `config/regression.json` | ابعاد، مدل و انتخاب تصاویر مجموعه تست |
| `scripts/reference_model.py` | مرجع مستقل FP16، بدون استفاده از state یا زمان‌بندی RTL |
| `docs/03_spec.md` | شرح دیتاپث، کنترل، حافظه و پارامترها |
| `docs/requirements_traceability_FA.md` | نگاشت بندهای صورت پروژه به کد و تست |
| `docs/05_plan.md` و `docs/plans/` | برنامه کلی و برنامه ۱۷ ماژول، متناظر با Stepهای RTL |
| `docs/diagrams/` | تصاویر PNG، SVG و منبع قابل ویرایش DOT |
| `docs/interfaces.md` و `docs/architecture.json` | رابط‌ها و hierarchy استخراج‌شده از کد |
| `submission/` | خروجی آماده با نام‌های لازم تسک‌های ۲ و ۵، تولیدشده از همین منابع |
| `verification/results/` | نتیجه واقعی تست‌های همین نسخه و گزارش خطاهای رفع‌شده |
| `data/model/` | تنها نسخه مشترک وزن‌ها و بایاس‌ها |
| `data/cases/` | تصویرهای ورودی؛ فایل‌های FP16 خام بدون تغییر بایت |

## تنظیم تست‌ها

```bash
# یک تصویر، سه inference پیاپی بدون reset بین اجراهای موفق
python scripts/run.py --cases reference --runs 3

# انتخاب چند تصویر، ذخیره waveform در build/wave/<case>/fcnn.vcd
python scripts/run.py --cases digit_0,digit_8 --runs 1 --wave --tag wave

# ریست در لایه دوم و سپس اجرای مجدد
python scripts/run.py --cases reference --reset-after 6350 --runs 2 --tag fc2_abort

# آزمایش تأخیر متفاوت SRAM؛ مقدار رسمی پروژه ۷ است
python scripts/run.py --cases reference --set SRAM_LATENCY=11 --runs 1 --tag latency11

# ساخت مدل و داده کوچک برای آزمون پارامترها؛ داده رسمی را تغییر نمی‌دهد
python scripts/generate_cases.py --output build/custom --inputs 15 --hidden 3 --outputs 5 --lanes 7 --latency 7
python scripts/run.py --suite build/custom/suite.json --runs 2 --tag custom

# تست واحدها در ModelSim، در صورت نصب آن
python scripts/verify.py --sim modelsim --groups fp,units,parameters
# مسیر تمام ورودی‌های RTL از TB قابل تغییر است؛ فایل‌ها خودکار با همین نام‌ها آماده می‌شوند
python scripts/run.py --cases reference --runs 1 --file-param INPUT_FILE=inputs/pixels.mem --tag paths
```

در TB، پارامترهای ابعاد، تأخیر و هر پنج مسیر فایل مستقیماً به Top ارسال می‌شوند. کنترل سناریو در GUI با پارامترهای TB است؛ runner همان تنظیمات را با `+runs`، `+reset_after`، `+busy_start`، `+timeout`، `+check_outputs`، `+expected_digit`، `+expected_file`، `+hidden_file` و `+wave` override می‌کند و golden مستقل می‌سازد. برای suite سفارشی در runner، مسیر `model_dir` و `image` هر case را در JSON معرفی کنید؛ ابعاد فایل‌ها پیش از شبیه‌سازی بررسی می‌شود.

`build/` فقط خروجی بازتولیدپذیر است: داده‌های کپی‌شده، oracle، باینری، log و نتایج JSON. فایل‌های آن برای تحویل و کامپایل اصلی لازم نیستند. هیچ فایل ورودی به ردیف ۱۱۲بیتی تبدیل و به RTL داده نمی‌شود؛ تشکیل ردیف داخل SRAM انجام می‌شود.

## حفظ هماهنگی پس از ویرایش

```bash
python scripts/design_docs.py --render
python scripts/design_docs.py --check
python scripts/lint.py
python scripts/audit.py
```

رندر تصاویر به Graphviz (`dot`) نیاز دارد؛ بررسی هماهنگی بدون آن اجرا می‌شود. lint به Verilator نیاز دارد و جای سنتز را نمی‌گیرد. حذف یا تغییر داده اصلی باعث خطای manifest می‌شود؛ داده جدید را به‌عنوان suite جدا معرفی کنید.

## خروجی تسک ۵

```bash
python scripts/export_task5.py --output submission/Task5_Submission.zip --partition-output submission/sub_modules.zip
```

نسخه آماده در `submission/Task5_Submission.zip` موجود است. دستور بالا آن و `sub_modules.zip` تسک۲ را بازتولید می‌کند. فایل header تسک۲ فقط قرارداد پورت است و پیاده‌سازی عملکردی نیست.

این دستور `05_code.v`، برنامه تجمیعی `05_plan.md` و تصاویر طراحی را از منابع یکتا تولید می‌کند. آن فایل تجمیعی را هم‌زمان با `rtl/*.v` کامپایل نکنید. این پروژه بازبینی و اجرای واقعی تسک ۵/تست‌های مرتبط را مستند می‌کند؛ سوابق پرامپت تسک ۴ و گفت‌وگوهای مستقل تسک ۶ در ZIP اولیه وجود نداشتند و برای آن‌ها سابقه ساختگی تولید نشده است. جدول وضعیت تحویل در `docs/requirements_traceability_FA.md` آمده است.

نتایج فعلی: برای هر یک از ۱۱ تصویر، **۶۴۰۳ سیکل**، **۶۳۵۲ ضرب**، **۶۳۷۰ جمع**، **۹۰۸ ردیف وزن** و **۸۹۶ ردیف تصویر**. تفاوت تعداد جمع و ضرب، همان ۱۸ جمع جداگانه بایاس است. این نتیجه شبیه‌سازی عملکردی است؛ گزارش سنتز، Fmax یا گواهی مصرف BRAM محسوب نمی‌شود.
