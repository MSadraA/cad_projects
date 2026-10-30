#!/usr/bin/env python3
"""Rebuild the exact vector diagrams and Persian manual-design report.

Optional documentation dependencies: reportlab, arabic-reshaper, python-bidi.
No dependency here is needed to compile or simulate the hardware.
"""
import argparse
from html import escape
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
NAVY='#16364A'; BLUE='#287AA6'; PALE='#EEF5F8'; GREEN='#27785C'; INK='#203441'; GRAY='#617381'


class Scene:
    def __init__(self,w,h): self.w=w;self.h=h;self.items=[]
    def box(self,x,y,w,h,title,sub='',fill=PALE):
        self.items.append(('box',x,y,w,h,title,sub,fill));return self
    def arrow(self,x1,y1,x2,y2,label=''):
        self.items.append(('arrow',x1,y1,x2,y2,label));return self
    def line(self,x1,y1,x2,y2):
        self.items.append(('line',x1,y1,x2,y2));return self
    def text(self,x,y,text,size=16): self.items.append(('text',x,y,text,size));return self
    def svg(self,path):
        parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}">',
               '<defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M 0 0 L 10 5 L 0 10 Z" fill="#287AA6"/></marker></defs>',
               '<rect width="100%" height="100%" fill="white"/>',
               '<g font-family="DejaVu Sans,Arial,sans-serif" fill="#203441">']
        for item in self.items:
            if item[0]=='box':
                _,x,y,w,h,title,sub,fill=item
                parts += [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="9" fill="{fill}" stroke="{BLUE}" stroke-width="1.7"/>',
                          f'<text x="{x+w/2}" y="{y+h/2-5 if sub else y+h/2+6}" text-anchor="middle" font-size="18" font-weight="bold">{escape(title)}</text>']
                if sub:parts.append(f'<text x="{x+w/2}" y="{y+h/2+20}" text-anchor="middle" font-size="14">{escape(sub)}</text>')
            elif item[0]=='line':
                _,x1,y1,x2,y2=item
                parts.append(f'<path d="M{x1},{y1} L{x2},{y2}" fill="none" stroke="{BLUE}" stroke-width="2"/>')
            elif item[0]=='arrow':
                _,x1,y1,x2,y2,label=item
                parts.append(f'<path d="M{x1},{y1} L{x2},{y2}" fill="none" stroke="{BLUE}" stroke-width="2" marker-end="url(#arrow)"/>')
                if label:parts.append(f'<text x="{(x1+x2)/2+8}" y="{(y1+y2)/2-7}" font-size="13">{escape(label)}</text>')
            else:
                _,x,y,text,size=item
                parts.append(f'<text x="{x}" y="{y}" font-size="{size}" text-anchor="middle">{escape(text)}</text>')
        parts+=['</g></svg>']
        path.write_text('\n'.join(parts)+'\n')
    def pdf(self,c,x,y,width):
        from reportlab.lib.colors import HexColor
        scale=width/self.w
        c.saveState();c.translate(x,y-self.h*scale);c.scale(scale,scale)
        for item in self.items:
            if item[0]=='box':
                _,bx,by,bw,bh,title,sub,fill=item
                c.setStrokeColor(HexColor(BLUE));c.setFillColor(HexColor(fill));c.setLineWidth(1.7)
                c.roundRect(bx,self.h-by-bh,bw,bh,9,stroke=1,fill=1)
                c.setFillColor(HexColor(INK));c.setFont('Sans-Bold',18)
                c.drawCentredString(bx+bw/2,self.h-(by+bh/2-5 if sub else by+bh/2+6),title)
                if sub:c.setFont('Sans',14);c.drawCentredString(bx+bw/2,self.h-(by+bh/2+20),sub)
            elif item[0]=='line':
                _,x1,y1,x2,y2=item
                c.setStrokeColor(HexColor(BLUE));c.setLineWidth(2);c.line(x1,self.h-y1,x2,self.h-y2)
            elif item[0]=='arrow':
                _,x1,y1,x2,y2,label=item
                c.setStrokeColor(HexColor(BLUE));c.setFillColor(HexColor(BLUE));c.setLineWidth(2)
                c.line(x1,self.h-y1,x2,self.h-y2)
                angle=math.atan2(y2-y1,x2-x1);length=10
                p=c.beginPath();p.moveTo(x2,self.h-y2)
                for side in (-0.45,0.45):p.lineTo(x2-length*math.cos(angle+side),self.h-(y2-length*math.sin(angle+side)))
                p.close();c.drawPath(p,fill=1,stroke=0)
                if label:c.setFont('Sans',13);c.drawString((x1+x2)/2+8,self.h-((y1+y2)/2-7),label)
            else:
                _,tx,ty,text,size=item;c.setFillColor(HexColor(INK));c.setFont('Sans',size);c.drawCentredString(tx,self.h-ty,text)
        c.restoreState()
        return self.h*scale


def diagrams():
    adder=Scene(900,650)
    adder.box(220,18,460,65,'Unpack / classify inputs','s[15], e[14:10], f[9:0]')
    adder.box(220,112,460,65,'Magnitude compare + swap','15-bit compare; sign from larger magnitude')
    adder.box(220,206,460,65,'Align smaller significand','13-bit shift-right-jam; delta exponent')
    adder.box(220,300,460,65,'Shared ADD / SUB carry chain','specialized low zeros and high hidden-one')
    adder.box(60,402,365,65,'Normalize sum','packed 8/4 and 2/1 conditional shifts')
    adder.box(475,402,365,65,'Carry normalization','fraction = sum[12:3]; exponent + 1')
    adder.box(220,512,460,65,'Truncate + exponent checks','zero / underflow / overflow / input bypass')
    adder.text(450,627,'result[15:0]',20)
    for y1,y2 in [(83,112),(177,206),(271,300)]:adder.arrow(450,y1,450,y2)
    adder.arrow(350,365,242,402,'no carry');adder.arrow(550,365,657,402,'ADD carry')
    adder.arrow(242,467,350,512);adder.arrow(657,467,550,512);adder.arrow(450,577,450,601)
    mul=Scene(900,590)
    mul.box(220,15,460,65,'Unpack / classify','sign = sign_a XOR sign_b')
    mul.box(220,110,460,65,'Exact 11 x 11 significand product','100 AND + 99 FA + 11 HA')
    mul.box(50,220,380,65,'P[21] = 0','fraction = P[19:10]; correction = 0')
    mul.box(470,220,380,65,'P[21] = 1','fraction = P[20:11]; correction = 1')
    mul.box(220,340,460,65,'Signed 7-bit exponent','ea + eb + correction - 15')
    mul.box(220,450,460,65,'Pack truncated output','valid / underflow / saturation selection')
    mul.text(450,565,'result[15:0]',20)
    mul.arrow(450,80,450,110);mul.arrow(350,175,240,220);mul.arrow(550,175,660,220)
    mul.arrow(240,285,350,340);mul.arrow(660,285,550,340);mul.arrow(450,405,450,450);mul.arrow(450,515,450,540)
    pp=Scene(900,610)
    pp.box(210,10,480,65,'Shared one-hot write pointer','7 S2 cells; rotate by wiring; group-close reset')
    pp.box(40,145,340,220,'BANK 0','7 x W payload + 6 mutable end flags')
    pp.box(520,145,340,220,'BANK 1','7 x W payload + 6 mutable end flags')
    pp.text(210,315,'pop0: shift toward fixed head',14);pp.text(690,315,'pop1: shift toward fixed head',14)
    pp.box(210,420,480,70,'Head selector','W C1 cells; read_bank selects bank head')
    pp.box(210,525,480,65,'Bank control','sealed0, sealed1, read_bank; derive write_bank')
    pp.arrow(300,75,210,145,'decoded write enable');pp.arrow(600,75,690,145,'decoded write enable')
    pp.arrow(210,365,340,420,'head0');pp.arrow(690,365,560,420,'head1')
    pp.text(450,403,'wr_data[W-1:0] feeds both banks',14)
    pp.arrow(450,490,450,525,'end / valid / ready')
    fsm=Scene(900,420)
    fsm.box(55,30,310,75,'EMPTY','not sealed; no accepted payload')
    fsm.box(535,30,310,75,'FILLING','not sealed; group incomplete')
    fsm.box(535,290,310,75,'SEALED / READING','sealed; data exposed only in read bank')
    fsm.arrow(365,68,535,68,'push, not group_last')
    fsm.arrow(690,105,690,290,'push with group_last')
    fsm.line(535,330,210,330)
    fsm.arrow(210,330,210,105,'pop of stored end flag')
    fsm.arrow(260,105,550,290,'one-item group')
    fsm.text(450,400,'Conceptual states; RTL uses flags and one-hot position, not an encoded FSM.',14)
    scenes={'adder':adder,'multiplier':mul,'ping_pong':pp,'bank_states':fsm}
    target=ROOT/'docs/diagrams';target.mkdir(exist_ok=True)
    for name,scene in scenes.items():scene.svg(target/(name+'.svg'))
    return scenes


def report(scenes):
    import arabic_reshaper
    from bidi.algorithm import get_display
    from reportlab.pdfgen import canvas
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.lib.colors import HexColor,white
    from reportlab.lib.pagesizes import A4
    pdfmetrics.registerFont(TTFont('Sans','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
    pdfmetrics.registerFont(TTFont('Sans-Bold','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))
    regression=json.loads((ROOT/'results/icarus/regression.json').read_text())
    assert len(regression['results'])==11 and all(x['pass'] for x in regression['results']), 'Complete regression first'
    counts=json.loads((ROOT/'results/gate_counts.json').read_text())
    manifest=json.loads((ROOT/'tb/vectors/manifest.json').read_text())
    assert not manifest['quick'] and manifest['vectors']==404014
    path=ROOT/'docs/CAD_CA2_Phase1_Report_FA.pdf'
    c=canvas.Canvas(str(path),pagesize=A4)
    c.setTitle('CAD CA2 Phase 1 - Manual Actel Synthesis')
    c.setAuthor('810102420 / 810101469')
    page_w,page_h=A4;left=54;right=page_w-54;width=right-left;y=0
    def rtl(s):return get_display(arabic_reshaper.reshape(s))
    def page(number,title,sub='طراحی کامپیوتری سیستم‌های دیجیتال | پاییز ۱۴۰۵'):
        nonlocal y
        if number>1:c.showPage()
        c.setFillColor(HexColor(NAVY));c.rect(0,page_h-23,page_w,23,fill=1,stroke=0)
        c.setFont('Sans',9);c.setFillColor(white);c.drawString(left,page_h-15,'CAD / CA2 / PHASE 1')
        c.drawRightString(right,page_h-15,'810102420  |  810101469')
        c.setFillColor(HexColor(INK));c.setFont('Sans-Bold',18);c.drawRightString(right,page_h-66,rtl(title))
        c.setFont('Sans',9);c.setFillColor(HexColor(GRAY));c.drawRightString(right,page_h-88,rtl(sub))
        c.setStrokeColor(HexColor('#D6E3EB'));c.line(left,page_h-101,right,page_h-101)
        c.line(left,45,right,45);c.setFont('Sans',8);c.drawString(left,30,'Manual Actel mapping | 2026-10-29');c.drawRightString(right,30,f'{number} / 9')
        y=page_h-125
    def fa(text,size=10.4,gap=8):
        nonlocal y
        words=text.split();lines=[];line=''
        for word in words:
            trial=(line+' '+word).strip()
            if pdfmetrics.stringWidth(rtl(trial),'Sans',size)>width and line:
                lines.append(line);line=word
            else:line=trial
        if line:lines.append(line)
        c.setFont('Sans',size);c.setFillColor(HexColor(INK))
        for line in lines:
            if y<61:raise RuntimeError(f'Page overflow near {line}')
            c.drawRightString(right,y,rtl(line));y-=size*1.65
        y-=gap
    def en(text,size=10):
        nonlocal y
        if y<61:raise RuntimeError('Page overflow')
        c.setFont('Sans',size);c.setFillColor(HexColor(INK));c.drawString(left,y,text);y-=size*1.7
    def heading(text):
        nonlocal y
        y-=4;c.setFont('Sans-Bold',12);c.setFillColor(HexColor(BLUE));c.drawRightString(right,y,rtl(text));y-=23
    def table(headers,rows,colwidths=None):
        nonlocal y
        colwidths=colwidths or [width/len(headers)]*len(headers)
        row_h=26
        for index,row in enumerate([headers]+rows):
            if y-row_h<58:raise RuntimeError('Table overflow')
            c.setFillColor(HexColor(NAVY if index==0 else (PALE if index%2 else '#FFFFFF')))
            c.rect(left,y-row_h,width,row_h,stroke=0,fill=1)
            xx=left
            for cell,cw in zip(row,colwidths):
                cell=str(cell);c.setFont('Sans-Bold' if index==0 else 'Sans',9)
                c.setFillColor(white if index==0 else HexColor(INK))
                c.drawCentredString(xx+cw/2,y-17,rtl(cell) if re_farsi(cell) else cell);xx+=cw
            y-=row_h
        y-=15
    def figure(name,width_scale=1):
        nonlocal y
        draw_w=width*width_scale;used=scenes[name].pdf(c,left+(width-draw_w)/2,y,draw_w);y-=used+13

    page(1,'گزارش فاز اول پروژهٔ دوم CAD')
    heading('سنتز دستی شتاب‌دهندهٔ عصبی با سلول‌های Actel')
    fa('این تحویل سه واحد تمرین اول را با اتصال دستی سلول‌های قابل برنامه‌ریزی بازطراحی می‌کند. جمع‌کننده و ضرب‌کننده ترکیبی هستند و بافر دارای دو بانک مستقل، کنترل جریان و reset سنکرون است. سایر RTLهای شتاب‌دهنده تغییر نکرده‌اند.')
    table(['Module','C1','C2','S2','Gates / limit'],[
        ['FP16 adder',225,72,0,'3042 / 3060'],['FP16 multiplier',372,133,0,'5183 / 5340'],
        ['16-bit ping-pong',33,1,246,'3539 / 3540']], [167,49,49,49,width-314])
    heading('سه تصمیمی که باید پیش از ارائه دیده شوند')
    fa('۱. متن تمرین، مانتیس صفر را معادل صفر بودن کل ورودی می‌گیرد. حالت پیش‌فرض همین تفسیر لفظی را اجرا می‌کند؛ تفسیر شامل hidden-one نیز با پارامتر جداگانه و تست مستقل موجود است.')
    fa('۲. نمای ۳۲ در فیلد ۵بیتی FP16 قابل نمایش نیست. در این تحویل، نمای ۳۱ و کسر صفر به عنوان کد سرریز انتخاب شده است. این یک فرض مستند و نیازمند تأیید TA است.')
    fa('۳. نسخهٔ قبلی بافر برای هر داده، مقصد و last مستقل ذخیره می‌کند. نسخهٔ دادهٔ خالص زیر سقف است؛ نسخهٔ کاملاً سازگار با CA1 نیز ارائه شده ولی ۴۴۹۹ گیت هزینه دارد. این دو شمارش نباید به جای هم ارائه شوند.')
    heading('محتوای قابل بررسی')
    fa('کد ساختاری، طراحی دستی، SVG نمودارها، تست‌بنچ جداگانه، مدل صحیح دقیق مستقل، فایل gated برای هر top، ابزار اجرای تست و گزارش‌های واقعی داخل بسته قرار دارند. آزمون کامل شامل ۴۰۴۰۱۴ جفت ورودی برای هر واحد حسابی و دو سیاست عددی است.')

    page(2,'قرارداد عددی و ابهام‌های متن')
    en('FP16 word = { sign[15], exponent[14:10], fraction[9:0] }')
    en('Normal magnitude = (1024 + fraction) * 2^(exponent - 25)')
    fa('در حالت پیش‌فرض، exp=0 یا fraction=0 به معنی ورودی صفر است. بنابراین 3C00 که در binary16 معمول 1.0 است، در این قرارداد صفر محسوب می‌شود. این رفتار به صورت عمدی مطابق متن فاز اول است و نباید به عنوان IEEE کامل معرفی شود.')
    fa('تمام subnormalها به صفر تبدیل می‌شوند. خروجی زیر محدودهٔ نرمال و خنثی‌شدن دقیق نیز +0 هستند. بیت‌های پایین significand نهایی حذف می‌شوند؛ هیچ round-up یا RNE وجود ندارد. jam صرفاً اطلاعات لازم برای borrow را حفظ می‌کند.')
    table(['a','b','ADD','MUL','Condition'],[
        ['3C00','3E00','3E00','0000','zero-fraction input'],
        ['3E00','3E00','4200','4080','1.5 and 1.5'],
        ['3C01','BC01','0000','BC02','cancellation / truncate'],
        ['0401','8402','0000','0000','underflow'],
        ['7BFF','7BFF','7C00','7C00','overflow code']], [70,70,70,70,width-280])
    fa('ورودی‌های exp=31 در صورت تمرین به عنوان NaN یا Inf تعریف نشده‌اند. پیاده‌سازی پس از قاعدهٔ صفر، فیلد نما را حسابی پردازش می‌کند و انتشار NaN/Inf ادعا نمی‌شود. دامنهٔ عادی استفاده، صفر و ورودی‌های نرمال با exp بین ۱ و ۳۰ است.')
    fa('پارامتر ZERO_FRAC_IS_ZERO=0 فقط ابهام مانتیس را تغییر می‌دهد. پارامتر OVERFLOW_EXP کد سرریز را انتخاب می‌کند. پیش‌فرض دوم 31 است؛ نوشتن 5\'d32 نما را به صفر قطع می‌کند و کد مستقل قابل نمایش نمی‌سازد.')

    page(3,'طراحی دستی جمع‌کننده')
    figure('adder',0.9)
    fa('عملوندها ابتدا بر اساس اندازه مرتب می‌شوند. significand کوچک با اختلاف نما و دو بیت guard/jam هم‌تراز می‌شود. زنجیرهٔ carry مشترک، جمع یا تفریق را اجرا می‌کند؛ علامت از عملوند بزرگ‌تر می‌آید.')
    fa('carry جمع، یک شیفت راست و افزایش نما می‌خواهد. در نبود carry، normalizer شمارش صفرهای پیشرو و شیفت چپ را هم‌زمان انجام می‌دهد. خروجی نهایی با حذف بیت‌های پایین و سپس انتخاب حالت صفر و سرریز ساخته می‌شود.')
    fa('ساختارهای با ثابت مشخص، دستی کوچک شده‌اند: دو بیت پایین عملوند بزرگ صفر و بیت بالای آن ۱ است. mux چهاربه‌یک C1 نیز دو سطح barrel را در یک سلول پیاده می‌کند. جزئیات اتصال پین‌ها در طراحی دستی Markdown آمده است.')

    page(4,'طراحی دستی ضرب‌کننده')
    figure('multiplier',0.88)
    table(['Significand network','Quantity','Weighted gates'],[
        ['Partial-product AND2',100,1000],['Full adders',99,3069],['Half adders',11,220],['Subtotal','',4289]], [230,90,width-320])
    fa('۲۱ حاصل‌ضرب جزئی به دلیل leading-one ثابت، به سیم یا ثابت تبدیل می‌شوند؛ ۱۰۰ حاصل‌ضرب دیگر با C1 ساخته شده‌اند. درخت compressor و جمع نهایی تمام ۲۲ بیت حاصل‌ضرب را می‌سازند. انتخاب بیت ۲۱، نرمال‌سازی و تصحیح یک‌بیتی نما را مشخص می‌کند.')
    fa('نمای میانی ۷بیتی علامت‌دار است. ورودی صفر و underflow، +0 می‌شوند و overflow به کد قراردادی می‌رود. مولد نت‌لیست فقط اتصال‌های همین طرح دستی را بازتولید می‌کند؛ کامپایل به اجرای آن وابسته نیست.')

    page(5,'معماری بافر و قرارداد جریان')
    figure('ping_pong',0.95)
    fa('اشاره‌گر one-hot، نوشتن خانهٔ انتخاب‌شده را فعال می‌کند. خواندن هر بانک با شیفت همان بانک به سمت head ثابت انجام می‌شود؛ در نتیجه mux بزرگ انتخاب خانه حذف شده است. هر بیت داده فقط یک S2 دارد که hold، write و shift را انتخاب می‌کند.')
    fa('گروه کوتاه با end زودتر sealed می‌شود. برای خانهٔ نهایی end ثابت ۱ است، چون تولیدکننده باید گروه را حداکثر همان‌جا ببندد. خروجی یک بانک ناتمام معتبر نیست و بانک sealed تا مصرف end قابل نوشتن نیست.')
    fa('ردگیری وضعیت و مقادیر معتبر با CA1 چرخه‌به‌چرخه مقایسه شده است. دادهٔ خروجی در rd_valid=0 قابل استفاده نیست. payload reset نمی‌شود؛ reset سنکرون فقط وضعیت اعتبار و اشاره‌گر را مقداردهی می‌کند.')

    page(6,'وضعیت بانک و حذف حالت زائد')
    figure('bank_states',0.95)
    en('write_bank = read_bank XOR sealed0 XOR sealed1')
    fa('پس از reset، رابطه برقرار است. بسته شدن گروه یک sealed را تغییر می‌دهد و انتخاب نوشتن را عوض می‌کند. آزاد شدن گروه، read_bank و همان sealed را هم‌زمان تغییر می‌دهد؛ انتخاب نوشتن ثابت می‌ماند. این ناوردا برای دو رویداد هم‌زمان نیز حفظ می‌شود.')
    fa('به همین دلیل ثبات مستقل write_bank حذف و با یک C2 بازسازی شده است. این تغییر رفتار قانونی را محدود نمی‌کند و هزینهٔ وزن‌دار را دو گیت کم می‌کند. مرزهای گروه و last مربوط به نورون با هم یکی فرض نشده‌اند.')
    table(['Storage / control','S2','Gates'],[
        ['Payload: 2 x 7 x 16',224,2912],['Mutable end flags',12,156],['One-hot position',7,91],
        ['sealed0 / sealed1 / read_bank',3,39],['33 C1 + 1 C2','-',341],['Total',246,3539]],[280,70,width-350])

    page(7,'شمارش گیت و محدودیت نسخهٔ CA1')
    table(['Top','C1','C2','S2','Gates'],[
        ['Adder',225,72,0,3042],['Multiplier',372,133,0,5183],['Payload buffer',33,1,246,3539],
        ['CA1 metadata buffer',38,1,316,4499]],[197,55,55,55,width-362])
    en('Gates = 10*C1 + 11*C2 + 13*S1 + 13*S2')
    fa('در شمارش مستقل، همهٔ برگ‌های Actel به صورت black box می‌مانند. شبکه فقط elaborate و flatten می‌شود؛ هیچ بهینه‌سازی، حذف ثابت، اشتراک سلول یا remap انجام نمی‌شود. شمارش متنی نام ماژول‌ها جایگزین تعداد نمونه‌های واقعی نشده است. FDCP داخلی دوباره شمرده نمی‌شود.')
    heading('حد پایین بافر کامل قبلی')
    en('14 * (16 data + 4 destination + 1 last) = 294 independent bits')
    en('294 * 13 = 3822 gates > 3540, before control or output muxes')
    fa('پس حتی ثبات‌های لبه‌ای داده و فراداده، پیش از کنترل و خروجی، از سقف بیشترند. نسخهٔ کامل، پنج بیت اضافه برای هر کلمه و پنج mux خروجی می‌خواهد: ۹۱۰ گیت ذخیره و ۵۰ گیت انتخاب، یعنی ۹۶۰ گیت اضافه. مجموع واقعی ۴۴۹۹ است.')
    fa('نسخهٔ ۳۵۳۹گیتی، بافر دادهٔ ۱۶بیتی است؛ نسخهٔ ۴۴۹۹گیتی رابط، پارامترها و فرادادهٔ مستقل CA1 را حفظ می‌کند. برای حفظ شفافیت تحویل، هر دو کد و هر دو شمارش جدا ارائه شده‌اند. سقف سه top فاز اول در تنظیمات پیش‌فرض رعایت شده است.')
    heading('روش اجرایی TA')
    fa('اصل C++های TA و ابزار قابل‌حمل همراه بسته‌اند. ابزار ModelSim برای هر top فقط یک DUT می‌سازد و gated را از صفر شروع می‌کند. تست‌بنچ عددی دارای دو DUT است و برای شمارش مناسب نیست. اجرای native در ModelSim انجام نشده؛ اعداد حاضر حاصل elaboration مستقل هستند.')

    page(8,'راستی‌آزمایی و شواهد اجرا')
    table(['Verification','Coverage','Result'],[
        ['FP16 ADD','404014 pairs x 2 policies','PASS'],['FP16 MUL','404014 pairs x 2 policies','PASS'],
        ['Building blocks','41992 checks','PASS'],['Actel cells','1028 checks','PASS'],
        ['Ping-pong / CA1 miter','7 parameter sets x 1200 items','PASS'],
        ['Gate / structural audit','3 phase-1 tops within limits','PASS']],[185,220,width-405])
    fa('oracle مستقل، مقدار هر ورودی را به یک عدد صحیح دقیق در واحد ۲ به توان منفی ۲۴ تبدیل می‌کند. جمع در همان واحد و ضرب در واحد ۲ به توان منفی ۴۸ دقیق‌اند. تنها encode نهایی، truncate و flush را اعمال می‌کند؛ هیچ محاسبه یا state از RTL به مدل مرجع منتقل نشده است.')
    fa('ورودی‌ها شامل همهٔ کدهای ۱۶بیتی در برابر چهار anchor، جفت‌های تمام نماها با کسرهای مرزی، مقادیر مجاور با علامت مخالف، مرزهای underflow/overflow و ۱۰۰ هزار جفت تصادفی با seed ثابت هستند. آزمون تمام ۲ به توان ۳۲ جفت ورودی یا اثبات رسمی کامل ادعا نشده است.')
    fa('بافر در LANES برابر ۱، ۲، ۳، ۵، ۷، ۸ و ۹ و DEST_W متناسب بررسی شده است. scoreboard ترتیب FIFO، تکمیل گروه، backpressure، ثبات خروجی، reset، ظرفیت و انتقال هم‌زمان را کنترل می‌کند. وضعیت و دادهٔ معتبر نسخهٔ جدید با CA1 مقایسه می‌شود.')
    fa('ابزارها: Icarus Verilog 12.0 و Yosys 0.33. ModelSim در محیط ساخت موجود نبود. اتصال top کامل CA1 با سه جایگزین compile/elaborate شد و ۱۴ RTL غیرهدف در کپی ادغام‌شده بایت‌به‌بایت ثابت ماندند. inference کامل شبکه بررسی نشده است.')

    page(9,'اجرای پروژه و راهنمای ارائه')
    heading('مسیر پیشنهادی')
    fa('ابتدا README و قرارداد عددی را بخوانید. سپس از ریشهٔ بسته تست کامل، شمارش و audit را اجرا کنید. در ویندوز می‌توان py -3 را به جای python نوشت. برای اجرای RTL و مدل مرجع، NumPy و PyTorch لازم نیستند.')
    en('python scripts/run.py')
    en('python scripts/count_gates.py --check')
    en('python scripts/audit.py')
    fa('برای GUI در ModelSim، مسیر جاری را ریشهٔ بسته بگذارید و TEST را انتخاب کنید. فایل‌های وکتور کامل از قبل وجود دارند و مسیر GUI به Python وابسته نیست. فایل شمارش هنگام regression فعال نیست.')
    en('set TEST tb_fp16_adder')
    en('do run_modelsim.do')
    heading('محل شواهد و طراحی')
    for line in ['docs/01_contract_FA.md','docs/02_manual_design_FA.md','docs/03_traceability_FA.md',
                 'docs/diagrams/*.svg','results/icarus/regression.json','results/gates/<top>/gated.txt',
                 'results/source_audit.json','integration/README_FA.md']:
        en(line,9.5)
    heading('حدود ادعا و موارد نیازمند پاسخ TA')
    fa('رفتار مانتیس صفر، نمای ناممکن ۳۲ و سقف گیتِ بافر دارای فراداده باید با TA روشن شود. این گزارش تفسیر انتخاب‌شده را مستند کرده و پاسخ TA را جایگزین نکرده است. نتایج عددی و gate count به همین قرارداد و پارامترهای ثبت‌شده مربوط‌اند.')
    fa('این مدارها مدل زمانی پس از جانمایی نیستند؛ Fmax، توان و تأخیر مسیر بحرانی اندازه‌گیری نشده‌اند. بسته شامل فایل موقت شبیه‌ساز یا نتایج قدیمی تمرین اول نیست و فقط ماژول‌های فاز اول را به عنوان RTL جدید ارائه می‌کند.')
    c.save();print(path.name)


def re_farsi(text): return any('\u0600'<=x<='\u06ff' for x in text)


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--diagrams-only',action='store_true');args=ap.parse_args()
    scenes=diagrams()
    if not args.diagrams_only:report(scenes)
