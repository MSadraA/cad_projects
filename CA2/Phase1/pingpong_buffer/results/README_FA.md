# نتیجهٔ واقعی راستی‌آزمایی

ابزار: Icarus Verilog 12.0؛ شمارش: Yosys 0.33. تمام زمان‌ها زمان واقعی اجرای شبیه‌سازی هستند و زمان کامپایل جدا در JSON ثبت شده است.

| آزمون | زمان (ثانیه) | نتیجه |
|---|---:|---|
| `tb_actel_cells` | 0.008 | [PASS] ACTEL_CELLS checks=1028 |
| `tb_building_blocks` | 1.335 | [PASS] BUILDING_BLOCKS checks=41992 |
| `tb_fp16_adder` | 654.579 | [PASS] ADD vectors=404014 policies=2 checks=808028 |
| `tb_fp16_multiplier` | 261.668 | [PASS] MUL vectors=404014 policies=2 checks=808028 |
| `tb_ping_pong_buffer_LANES1_DEST_W1` | 0.344 | [PASS] PINGPONG lanes=1 items=1200 blocked=878 simultaneous=852 |
| `tb_ping_pong_buffer_LANES2_DEST_W1` | 0.557 | [PASS] PINGPONG lanes=2 items=1200 blocked=1093 simultaneous=730 |
| `tb_ping_pong_buffer_LANES3_DEST_W2` | 0.750 | [PASS] PINGPONG lanes=3 items=1200 blocked=944 simultaneous=778 |
| `tb_ping_pong_buffer_LANES5_DEST_W3` | 1.073 | [PASS] PINGPONG lanes=5 items=1200 blocked=1135 simultaneous=671 |
| `tb_ping_pong_buffer_LANES7_DEST_W4` | 1.052 | [PASS] PINGPONG lanes=7 items=1200 blocked=1047 simultaneous=644 |
| `tb_ping_pong_buffer_LANES8_DEST_W4` | 1.283 | [PASS] PINGPONG lanes=8 items=1200 blocked=1116 simultaneous=596 |
| `tb_ping_pong_buffer_LANES9_DEST_W5` | 1.278 | [PASS] PINGPONG lanes=9 items=1200 blocked=973 simultaneous=668 |

جمع‌کننده و ضرب‌کننده هر کدام ۴۰۴۰۱۴ جفت ورودی و دو سیاست عددی دارند: مجموع ۱۶۱۶۰۵۶ مقایسهٔ عددی بین RTL و مرجع مستقل. تمام تست‌بنچ‌ها و سورس‌های RTL با SHA-256 ثبت شده‌اند و با نسخهٔ نهایی یکسان‌اند.

فایل‌های compile.log خالی به معنی کامپایل بدون پیام تشخیصی‌اند. `ca1_integration_compile.log` هشدارهای inherited timescale از RTL دست‌نخوردهٔ CA1 دارد؛ کامپایل و elaboration آن موفق بوده است.

شمارش native با ModelSim اجرا نشده است. فایل gated هر ماژول از شمارش وزنی نمونه‌های برگ elaborated و بدون بهینه‌سازی به دست آمده است. خود ابزار C++ با ۶۳ اجرای هم‌زمان و انتظار مجموع ۷۱۴ بررسی شده و درست بوده است.

نسخهٔ کامل فراداده‌دار بافر ۴۴۹۹ گیت دارد و زیر سقف نیست؛ نسخهٔ دادهٔ ۱۶بیتی ۳۵۳۹ گیت دارد. ابهام exp=32 و مانتیس صفر در README و قرارداد توضیح داده شده است.
