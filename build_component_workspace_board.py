from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path

OUT = Path('/home/ubuntu/taika-repo/taika-real-canvas-workspace-board.png')
W, H = 2400, 1600
bg = Image.new('RGB', (W, H), '#0b0b0e')
d = ImageDraw.Draw(bg)

font_dir = '/usr/share/fonts/truetype/dejavu'
def font(size, bold=False):
    name = 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'
    return ImageFont.truetype(f'{font_dir}/{name}', size)

white = '#f4f1f6'; muted = '#aaa5b0'; pink = '#f188d8'; lilac = '#cdb7ff'; line = '#3a3741'; green = '#93e6bf'

def txt(x, y, s, size=24, fill=white, bold=False):
    d.text((x,y), s, font=font(size,bold), fill=fill)

def rounded(box, radius, fill, outline=None, width=1):
    d.rounded_rectangle(box, radius, fill=fill, outline=outline, width=width)

def section(x,y,w,title,subtitle=None):
    txt(x,y,title,26,pink,True)
    if subtitle: txt(x,y+38,subtitle,16,muted)
    d.line((x,y+70,x+w,y+70), fill=line, width=2)

# header
rounded((44,34,W-44,118), 22, '#111116', outline='#292631', width=2)
txt(70,55,'TAIKA / SPRINT 0 COMPONENT WORKSPACE',24,white,True)
txt(1700,61,'НЕ НОВЫЕ ФИЧИ → ОБЩИЙ FOUNDATION',17,pink,True)
txt(1700,87,'material · hierarchy · motion · accessibility',15,muted)

# section 1 anatomy
section(60,155,690,'01 / SURFACE ANATOMY','Точно что меняем в первом sprint')
# current fragment
x0,y0=70,260
rounded((x0,y0,x0+330,y0+430), 28, '#27272a', outline='#5b5960', width=2)
txt(x0+24,y0+24,'СЕЙЧАС',16,muted,True)
rounded((x0+20,y0+78,x0+310,y0+390), 30, '#4b4b4e', outline='#77767c', width=2)
txt(x0+42,y0+105,'Игровой парк',25,white,True)
txt(x0+42,y0+176,'Сначала выучи',21,white,True)
txt(x0+42,y0+206,'пару фраз',21,white,True)
txt(x0+42,y0+255,'Серый slab',16,'#d0ccd3')
txt(x0+42,y0+282,'тяжёлая граница',16,'#d0ccd3')
# arrow
rounded((x0+360,y0+200,x0+585,y0+270), 18, '#1c1823', outline=pink, width=2)
txt(x0+385,y0+220,'Sprint 0',20,pink,True)
# new fragment
x1=610
rounded((x1,y0,x1+330,y0+430), 28, '#0e0e12', outline='#383142', width=2)
txt(x1+24,y0+24,'ПОСЛЕ',16,green,True)
# glow behind glass
blur = Image.new('RGBA',(330,430),(0,0,0,0)); bd=ImageDraw.Draw(blur); bd.ellipse((20,90,310,370), fill=(230,120,220,70)); blur=blur.filter(ImageFilter.GaussianBlur(38)); bg.paste(blur,(x1,y0),blur)
d = ImageDraw.Draw(bg)
rounded((x1+20,y0+78,x1+310,y0+390), 30, '#2b2630', outline='#a387b2', width=2)
# inner highlight
d.line((x1+44,y0+95,x1+286,y0+95), fill='#f0d8ed', width=2)
txt(x1+42,y0+105,'Игровой парк',25,white,True)
txt(x1+42,y0+176,'Сначала выучи',21,white,True)
txt(x1+42,y0+206,'пару фраз',21,white,True)
txt(x1+42,y0+255,'translucent glass',16,lilac)
txt(x1+42,y0+282,'continuous canvas',16,lilac)

# token strip
section(850,155,680,'02 / TOKENS','Один recipe для всех overlays')
tokens=[('CANVAS','#0B0B0E'),('GLASS','#2B2630'),('ACCENT','#F188D8'),('INNER','#F0D8ED'),('BLUR','CONTROLLED')]
for i,(name,val) in enumerate(tokens):
    xx=860+(i%3)*210; yy=260+(i//3)*150
    rounded((xx,yy,xx+180,yy+110),18,'#15131a',outline='#3a3741',width=2)
    if name!='BLUR': rounded((xx+20,yy+20,xx+58,yy+58),12,val)
    else: rounded((xx+20,yy+20,xx+58,yy+58),12,'#8a6e9e')
    txt(xx+20,yy+70,name,14,muted,True); txt(xx+75,yy+27,val,15,white,True)
txt(860,590,'Правило: Feature View owns content.',17,white,True)
txt(860,620,'Shared primitive owns material, spacing, motion.',17,muted)
txt(860,650,'Никаких новых one-off cards в Sprint 0.',17,pink)

# section 3 primitive states
section(1580,155,750,'03 / PRIMITIVES + STATES','Не экран Speaker. Набор деталей для всех экранов')
prims=[('GlassMessage','empty / info / recovery','Игровой парк'),('GlassChoice','mode / plan selection','Выбери режим'),('GlassPeek','locked contextual tap','Режим PRO'),('GlassQuota','limit / reset','Осталось 2 из 3'),('GlassPaywall','purchase / restore','Открыть Taika+'),('GlassWorkbench','search / input / result','Введи слово')]
for i,(name,state,example) in enumerate(prims):
    yy=260+i*105
    rounded((1590,yy,2325,yy+82),18,'#17151b',outline='#443949',width=2)
    txt(1610,yy+14,name,19,pink,True)
    txt(1825,yy+15,state,15,muted)
    rounded((2155,yy+13,2305,yy+58),13,'#2c2632',outline='#775d7e',width=1)
    txt(2170,yy+25,example,13,white,True)

# usage examples real screenshot frames
section(60,760,2260,'04 / USAGE EXAMPLES','Один foundation, разные реальные контексты')
paths=[('/home/ubuntu/upload/simulator_screenshot_C0911650-5A63-4764-B434-0CC705207182.webp','Game Park / GlassMessage'),('/home/ubuntu/upload/simulator_screenshot_B6D5497D-0275-4928-B426-9109B00E36A8.webp','Speaker / GlassWorkbench'),('/home/ubuntu/upload/simulator_screenshot_92BB7278-9FD0-4536-BC31-BCDCED80AE08.webp','Paywall / GlassPaywall'),('/home/ubuntu/upload/simulator_screenshot_E0EE195F-B64D-4211-86F6-2E3AB59F4EBC.webp','Search / GlassWorkbench'),('/home/ubuntu/upload/simulator_screenshot_1EAFD88E-2DBF-41B4-8965-B154EA6452CA.webp','Dictionary / GlassMessage')]
for i,(p,label) in enumerate(paths):
    try:
        im=Image.open(p).convert('RGB')
        im.thumbnail((250,540))
        xx=70+i*450; yy=850
        # soft shadow frame
        rounded((xx-10,yy-10,xx+im.width+10,yy+im.height+10),24,'#111116',outline='#4c4352',width=2)
        bg.paste(im,(xx,yy))
        txt(xx,yy+im.height+24,label,15,white,True)
    except Exception:
        pass

# footer legend
rounded((60,1500,2340,1565),18,'#121116',outline='#302a38',width=1)
txt(85,1520,'SPRINT 0 CHANGES: material / hierarchy / motion / accessibility',16,pink,True)
txt(1180,1520,'НЕ МЕНЯЕМ: navigation / product flow / engine / RevenueCat / persistence',15,muted)

bg.save(OUT)
print(OUT)
