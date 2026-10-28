# اجرای مستقیم FCNN در ModelSim و تغییر تست هنگام ارائه

این مسیر فقط به ModelSim/Questa نیاز دارد و هیچ فرمان Python را اجرا نمی‌کند. تنظیمات سخت‌افزار و تست در همان بلوک پارامتر ابتدای `verification/tb_fcnn.v` هستند. داده‌ها چهار رقم hex برای هر کلمه FP16 و وزن‌ها neuron-major باقی می‌مانند.

## اولین اجرا

1. بسته کامل پروژه را استخراج کنید. پوشه `FCNN_Clean` شامل `rtl`، `verification`، `data` و `run_modelsim.do` است.
2. ModelSim را باز کنید. در Transcript با `cd` به همین پوشه بروید؛ مسیر زیر نمونه است و باید با مسیر واقعی سیستم جایگزین شود. در ویندوز نیز `/` و آکولاد برای مسیر دارای فاصله مناسب‌اند.
3. فایل اجرای پروژه را اجرا کنید:

```tcl
cd {/path/to/FCNN_Clean}
do run_modelsim.do
```

این دستور یک کتابخانه و INI محلی در `build/modelsim_gui` می‌سازد، RTL و TB را کامپایل می‌کند، `tb_fcnn` را با دسترسی به سیگنال‌های داخلی بارگذاری می‌کند، Wave را می‌چیند و `run -all` اجرا می‌کند. نیازی به ساخت پروژه GUI یا کپی فایل‌های وزن کنار تست‌بنچ نیست. مسیرهای پیش‌فرض TB به فایل‌های موجود پروژه اشاره می‌کنند.

پس از پایان موفق، کلاک TB متوقف می‌شود تا `run -all` به Transcript برگردد؛ طراحی unload نمی‌شود. همه خروجی‌ها و تاریخچه موج برای بررسی باقی می‌مانند. در حالت پیش‌فرض دو inference، رقم ۲ و برای هر اجرا ۶۴۰۳ سیکل دیده می‌شود. پیام‌های `[RESULT]` تمام logitها را به ترتیب اندیس و در قالب hex نمایش می‌دهند. گزارش متنی و موج در `build/modelsim_gui/transcript.log` و `fcnn.wlf` ثبت می‌شوند.

اگر به‌جای DO از `source` با مسیر کامل استفاده می‌کنید، اسکریپت مسیر ریشه را از نام فایل به دست می‌آورد. برای فرمان `do run_modelsim.do` همیشه ابتدا پوشه جاری را ریشه همین نسخه پروژه قرار دهید؛ در بعضی نسخه‌های ModelSim، `info script` داخل DO خالی است.

## عوض‌کردن ورودی یا تنظیمات

`verification/tb_fcnn.v` را در ویرایشگر باز کنید. فقط مقادیر بلوک پارامتر ابتدای فایل را تغییر دهید؛ بقیه اتصال‌ها و scoreboard به همین پارامترها وابسته‌اند. فایل را ذخیره و دوباره در Transcript اجرا کنید:

```tcl
do run_modelsim.do
```

این کار شبیه‌سازی قبلی را می‌بندد، TB جدید را کامپایل و حافظه‌ها را از فایل‌ها دوباره مقداردهی می‌کند. صرف `restart` ویرایش پارامتر در فایل Verilog را کامپایل نمی‌کند؛ برای ارائه از دستور بالا استفاده کنید.

| تنظیم در ابتدای TB | کاربرد |
|---|---|
| `INPUT_FILE` | تصویر انتخابی؛ مثلاً `data/cases/digit_7/test_image.mem` |
| `FC1_WEIGHTS_FILE`, `FC2_WEIGHTS_FILE` | فایل‌های وزن لایه‌ها |
| `FC1_BIAS_FILE`, `FC2_BIAS_FILE` | فایل‌های بایاس |
| `N_INPUTS`, `N_HIDDEN`, `N_OUTPUTS` | ابعاد شبکه؛ فایل‌ها باید با آن‌ها متناسب باشند |
| `LANES`, `SRAM_LATENCY` | پیش‌فرض رسمی هر دو ۷؛ تغییر آن‌ها برای آزمایش ماژولاریتی است |
| `CLOCK_PERIOD_NS` | دوره کلاک شبیه‌سازی؛ پیش‌فرض ۱۰ ns |
| `RUNS` | تعداد اجرای موفق پیاپی؛ بدون reset بین آن‌ها |
| `RESET_AFTER` | صفر: بدون لغو اولیه؛ مثبت: لغو اجرای اولیه در سیکل تعیین‌شده و سپس RUNS اجرای تازه |
| `INJECT_BUSY_START` | تزریق start در busy و بررسی نادیده‌گرفتن آن؛ صفر یا یک |
| `TIMEOUT_CYCLES` | صفر: حد خودکار مشتق از ابعاد؛ مثبت: سقف انتظار مشخص |
| `DUMP_WAVE` | ذخیره VCD با `$dumpvars`؛ برای Wave خود ModelSim لازم نیست، چون WLF فعال است |
| `VCD_FILE` | مسیر خروجی VCD در صورت فعال‌بودن DUMP_WAVE؛ پیش‌فرض `fcnn.vcd` |
| `CHECK_OUTPUTS` | فعال‌کردن مقایسه عددی با golden؛ در ادامه توضیح داده شده است |

مثلاً برای ورودی شماره ۷، مقدار موجود پارامتر را به این صورت تغییر دهید:

```verilog
parameter INPUT_FILE="data/cases/digit_7/test_image.mem",
```

برای تصویر تازه TA، فایل را مثلاً در `inputs/ta_image.mem` بگذارید و همان مسیر را در `INPUT_FILE` بنویسید. فرمت رسمی تصویر ۷۸۴ کلمه FP16 است. تغییر پیکسل‌ها با ویرایش خود فایل نیز ممکن است؛ بعد از ذخیره دوباره DO را اجرا کنید. تغییر ابعاد شبکه به وزن‌ها و بایاس‌های متناسب نیاز دارد.

در تنظیمات رسمی، `RESET_AFTER=6350` ریست در FC2 را آزمایش می‌کند. این عدد فقط نمونه سناریوی همین شبکه است؛ برای ابعاد دیگر باید زمانی انتخاب شود که `busy=1` باشد. ریست بعد از پایان اجرا با پیام روشن رد می‌شود.

## دیدن موج‌ها و اجرای مرحله‌ای

فایل `modelsim/wave.do`، ۸۷ سیگنال را در ۹ گروه مرتب می‌کند. همه مسیرها توسط audit با hierarchy فعلی کنترل می‌شوند.

| گروه | چیزی که می‌توان نشان داد |
|---|---|
| Top | کلاک، reset، start، busy، done، رقم و باس خروجی |
| Controller | state/next_state و شروع و پایان لایه‌ها؛ IDLE=0، FC1=1، FC2=2، DONE=3 |
| SRAM and rows | درخواست‌ها، آدرس‌ها، valid پاسخ و ردیف‌های نگه‌داشته‌شده |
| Scheduler | lane، فاصله درخواست، فاصله بایاس و پایان خواندن hidden |
| Multiplier | operandها، محصول و tag مقصد/پایان |
| Ping-Pong | valid/ready، داده، مقصد، occupancy، بانک خواندن/نوشتن و seal |
| Accumulators | ورودی/خروجی ADD، `bias_pending` و accumulatorهای FC1/FC2 |
| ReLU and RF | مقدار قبل/بعد ReLU، hiddenها، RF مشترک و آماده‌شدن خروجی |
| Testbench | شمارنده عملیات، completion، failures و وضعیت بررسی عددی |

state و آدرس‌ها به‌صورت عددی و داده‌های FP16 به‌صورت hex نمایش داده می‌شوند. هر logit یک برش ۱۶بیتی از باس است؛ اندیس صفر در کم‌ارزش‌ترین ۱۶ بیت قرار دارد. آرایه `fc2_acc` یا `rf_mem` را می‌توان در Wave باز کرد یا از Memory List دید. X اولیه حافظه/داده پیش از valid به‌تنهایی خروجی معتبر محسوب نمی‌شود.

برای توقف بعد از بارگذاری در زمان صفر و اجرای دلخواه:

```tcl
set FCNN_AUTORUN 0
do run_modelsim.do
run 200 ns
run 10 ns
run -all
wave zoom full
```

با دوره پیش‌فرض، `run 10 ns` یک دوره کلاک جلو می‌رود. برای برگشت به اجرای خودکار:

```tcl
set FCNN_AUTORUN 1
do run_modelsim.do
```

## تفاوت نمایش نتیجه و بررسی عددی

در حالت پیش‌فرض `CHECK_OUTPUTS=0`، هیچ رقم مورد انتظار یا golden اجباری نیست. TB همه logitها و رقم محاسبه‌شده را نمایش می‌دهد و ترتیب/تعداد عملیات، metadata، reset، timeout، پایداری خروجی، busy-start و X در operandهای مصرف‌شده را بررسی می‌کند. فایل ورودی گمشده یا داده ناقص با پیام FAIL متوقف می‌شود. پیام موفق این حالت **`[PASS] E2E_PROTOCOL ... checked_outputs=0`** است و به معنای اثبات درست‌بودن عددی شبکه نیست.

برای golden موجود و متناظر با همان مدل، ورودی و ابعاد، این پارامترها را در TB تنظیم کنید:

```verilog
parameter integer CHECK_OUTPUTS=1, EXPECTED_DIGIT=2,
parameter EXPECTED_LOGITS_FILE="inputs/reference_logits.mem",
parameter EXPECTED_HIDDEN_FILE="inputs/reference_hidden.mem"
```

عدد ۲ در این مثال مخصوص ورودی reference است. فایل‌ها باید logit و hiddenهای صحیح همان ورودی را داشته باشند؛ hidden بعد از ReLU مقایسه می‌شود. در این حالت همه hiddenها، logitها و رقم بررسی می‌شوند و پیام موفق **`[PASS] E2E ... checked_outputs=1`** است. فعال‌کردن این حالت بدون تنظیم رقم معتبر یا فایل‌های لازم، FAIL می‌شود.

runner مستقل Python همچنان golden تازه می‌سازد و برای regression عددی همیشه `check_outputs=1` می‌فرستد. runner یک protocol PASS را به‌عنوان موفقیت عددی قبول نمی‌کند. هنگام تغییر تصویر یا وزن، golden قدیمی را برای ورودی جدید استفاده نکنید.

## آنچه در این نسخه واقعاً تست شده

اجرای بدون plusarg، تغییر تصویر/دوره کلاک/ریست از پارامتر TB، تصویر تازه، شبکه کوچک با فایل‌های متناسب، تولید VCD، مقایسه عددی با پارامترهای TB و guardهای خطا با Icarus Verilog-2005 تست شده‌اند. regression رسمی و شش پیکربندی نیز با TB جدید دوباره اجرا شده‌اند. برای DOها، جریان Tcl با فرمان‌های شبیه‌سازِ stub بررسی شده است؛ این تست، اجرای ModelSim نیست.

ModelSim در محیط این اصلاح نصب نبود. بنابراین اجرای واقعی GUI یا ظاهر Wave در ModelSim ادعا نمی‌شود. فایل‌ها برای اجرای مستقل آن آماده‌اند و باید خروجی ModelSim سیستم مقصد ملاک آن تأیید باشد.

مراجع فرمان‌های ابزار: [ModelSim Reference Manual](https://ww1.microchip.com/downloads/aemdocuments/documents/fpga/ProductDocuments/SupportingCollateral/modelsim_reference_manual_v101c.pdf) برای `vmap`، `vsim` و WLF؛ [Questa SIM Tutorial](https://ww1.microchip.com/downloads/aemDocuments/documents/FPGA/swdocs/questasim/questa_sim_tut_2024_2.pdf) برای دسترسی `+acc` و Wave. منطق FCNN و انتظارهای عددی از صورت پروژه و منابع خود پروژه می‌آیند.
