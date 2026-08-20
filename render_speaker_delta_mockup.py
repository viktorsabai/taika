from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

W, H = 2560, 1440
img = Image.new("RGB", (W, H), (9, 10, 13))
d = ImageDraw.Draw(img)

# palette
white = (244, 242, 248)
muted = (156, 153, 166)
faint = (102, 99, 112)
pink = (255, 96, 204)
lilac = (216, 154, 255)
line = (67, 67, 78)
card = (22, 22, 28)
card2 = (27, 27, 34)

font_paths = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]
def font(size, bold=False):
    p = font_paths[1] if bold else font_paths[0]
    return ImageFont.truetype(p, size)

f_title = font(34, True)
f_section = font(22, True)
f_label = font(18, True)
f_body = font(18)
f_small = font(15)
f_phone_title = font(22, True)
f_phone_body = font(17)
f_phone_big = font(30, True)
f_phone_translit = font(20, True)

# subtle background bloom
bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(bloom)
bd.ellipse((850, 260, 1700, 1200), fill=(205, 47, 177, 26))
bloom = bloom.filter(ImageFilter.GaussianBlur(150))
img = Image.alpha_composite(img.convert("RGBA"), bloom).convert("RGB")
d = ImageDraw.Draw(img)

def rr(box, radius, fill, outline=None, width=1):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)

def text(x, y, s, f, fill=white, anchor=None):
    d.text((x, y), s, font=f, fill=fill, anchor=anchor)

def gradient_rect(box, radius=18):
    x0, y0, x1, y1 = box
    grad = Image.new("RGB", (x1-x0, y1-y0))
    gd = ImageDraw.Draw(grad)
    for x in range(x1-x0):
        t = x / max(1, (x1-x0-1))
        c = tuple(int((1-t)*pink[i] + t*lilac[i]) for i in range(3))
        gd.line((x, 0, x, y1-y0), fill=c)
    mask = Image.new("L", grad.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0,0,grad.width-1,grad.height-1), radius=radius, fill=255)
    img.paste(grad, (x0,y0), mask)

def phone(box, mode):
    x0, y0, x1, y1 = box
    rr(box, 34, (14,15,19), outline=(95,94,106), width=2)
    rr((x0+16,y0+16,x1-16,y1-16), 25, (13,14,18), outline=(37,38,46), width=1)
    # dynamic island
    rr((x0+((x1-x0)//2)-42,y0+14,x0+((x1-x0)//2)+42,y0+32), 10, (2,3,5))
    text(x0+34,y0+48,"17:32",font(11),muted)
    text(x0+30,y0+78,"Спикер",f_phone_title,white)
    text(x1-35,y0+78,"Скажи сам",font(11,True),pink,anchor="ra")
    d.line((x0+26,y0+110,x1-26,y0+110), fill=(37,37,45), width=1)
    # bottom nav
    nav_y = y1-48
    d.line((x0+22,nav_y-20,x1-22,nav_y-20), fill=(35,36,43), width=1)
    nav = ["⌂", "⌁", "◉", "♡", "◌"]
    for i, n in enumerate(nav):
        xx = x0+42+i*((x1-x0-84)//4)
        text(xx, nav_y, n, font(18,True), pink if i==2 else muted, anchor="mm")
    if mode == "current":
        rr((x0+24,y0+130,x1-24,y1-86), 20, (40,40,47), outline=(75,74,84), width=1)
        text((x0+x1)//2,y0+205,"Скажи фразу",f_phone_body,muted,anchor="mm")
        text((x0+x1)//2,y0+290,"...",f_phone_big,white,anchor="mm")
        rr((x0+38,y1-112,x1-38,y1-66), 16, (72,72,80))
        text((x0+x1)//2,y1-89,"🎙  Начать запись",f_phone_body,white,anchor="mm")
    elif mode == "after":
        # continuous background, compact agent
        text((x0+x1)//2,y0+166,"Скажи по-русски",f_phone_body,muted,anchor="mm")
        # compact AI agent orb
        glow = Image.new("RGBA", (x1-x0, y1-y0), (0,0,0,0))
        gd = ImageDraw.Draw(glow)
        cx, cy = (x0+x1)//2, y0+250
        for r, a in [(68,18),(52,28),(38,42)]:
            gd.ellipse((cx-r,cy-r,cx+r,cy+r), outline=(255,92,207,a), width=2)
        glow = glow.filter(ImageFilter.GaussianBlur(7))
        img.paste(glow, (0,0), glow)
        d.ellipse((cx-25,cy-25,cx+25,cy+25), fill=(250,100,211), outline=(255,220,250), width=2)
        text(cx,cy,"◌",font(22,True),(35,20,34),anchor="mm")
        text(cx,y0+318,"Говорить",f_phone_body,white,anchor="mm")
        # result card
        rr((x0+24,y0+360,x1-24,y1-86), 20, (24,24,31), outline=(82,74,91), width=1)
        text(x0+42,y0+390,"Вы сказали",font(12),faint)
        text(x0+42,y0+420,"Мне нужен адрес",f_phone_body,white)
        text(x0+42,y0+445,"этого места",f_phone_body,white)
        text(x0+42,y0+490,"Транслит",font(12),faint)
        text(x0+42,y0+520,"kŏr tîi-yùu kŏng",f_phone_translit,lilac)
        text(x0+42,y0+548,"tîi-nîi nòi",f_phone_translit,lilac)
        # actions
        actions = [("▶","Слушать"),("□","Копировать"),("♡","Сохранить")]
        for i,(ic, lab) in enumerate(actions):
            xx=x0+55+i*((x1-x0-110)//2)
            text(xx,y0+590,ic,font(20,True),pink,anchor="mm")
            text(xx,y0+615,lab,font(10),muted,anchor="mm")
        gradient_rect((x0+38,y1-140,x1-38,y1-96), radius=15)
        text((x0+x1)//2,y1-118,"Тренировать фразу  →",font(13,True),(25,14,24),anchor="mm")

def rounded_panel(box):
    rr(box, 18, (14,15,19), outline=line, width=1)

# Header
text(58,48,"SPRINT 0 + 1 — ЧТО УВИДИТ ПОЛЬЗОВАТЕЛЬ",f_title,white)
text(58,94,"Один реальный Speaker screen: тот же продуктовый flow, но яснее материал, состояния и следующий шаг.",f_body,muted)

# main panels
left = (70,180,1110,1260)
right = (1450,180,2490,1260)
rounded_panel(left); rounded_panel(right)
text(112,218,"СЕЙЧАС",f_section,muted)
text(1502,218,"ПОСЛЕ SPRINT 0 + 1",f_section,pink)
text(112,258,"Speaker: серый panel, разрыв header/body, неясный результат",f_small,faint)
text(1502,258,"тот же Speaker: continuous glass canvas + instant translation",f_small,faint)
phone((190,330,990,1130), "current")
phone((1570,330,2370,1130), "after")
# arrow
text(1280,705,"→",font(58,True),pink,anchor="mm")
# concise delta footer
text(112,1208,"Sprint 0: material + hierarchy + blur",f_small,muted)
text(1502,1208,"Sprint 1: русский input → translit result → save / train handoff",f_small,muted)

# tiny key below main panels
text(58,1320,"Важно: pronunciation score появляется только внутри отдельного training pipeline — не в instant translation.",f_body,(209,147,225))

# save
img.save("/home/ubuntu/taika-repo/taika-sprint0-sprint1-speaker-delta.png", quality=95)
