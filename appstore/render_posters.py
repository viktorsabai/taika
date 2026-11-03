#!/usr/bin/env python3
"""App Store posters: real screenshots inside a phone, short headline above."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/product/Projects/taika")
ASSETS = Path("/Users/product/.cursor/projects/Users-product-Projects-taika/assets")
OUT = ROOT / "appstore" / "screenshots"
W, H = 1290, 2796
BG = (13, 13, 15)
PINK = (242, 92, 166)
WHITE = (255, 255, 255)
BEZEL = (32, 32, 36)

ONMARK = ImageFont.truetype(str(ROOT / "appstore/fonts/Onmark TRIAL Regular.otf"), 68)
HEAD = ImageFont.truetype("/Library/Fonts/SF-Pro-Display-Bold.otf", 92)

# (filename, source, line1, line2)
PAGES = [
    ("01-phrase.png", "IMG_5169-a253e997-786f-4c70-a244-c5206c2a0dd0.png", "Фраза", "на сегодня"),
    ("02-speaker.png", "IMG_5172-e433196e-1343-4ef5-ba86-2331977c16ff.png", "Скажи", "сам"),
    ("03-courses.png", "IMG_5170-7897315c-27ba-470d-a0be-50f1c9be959a.png", "С чего", "начать"),
    ("04-lesson.png", "IMG_5171-5ef986f5-c426-4332-89f1-2c8045abe4f8.png", "Один", "урок"),
    ("05-sound.png", "IMG_5173-24033383-1588-4b2b-9d12-9a1b93db32b4.jpg", "Как", "звучит"),
    ("06-new.png", "IMG_5168-cce2b052-297a-4409-aaaa-e0cd603602c0.png", "Скажи —", "разберём"),
]


def tracked(draw, xy, text, font, fill, tracking=-2.2):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += font.getlength(ch) + tracking


def wordmark(canvas, x, y):
    draw = ImageDraw.Draw(canvas)
    tai = ONMARK.getbbox("tai")
    kaaa = ONMARK.getbbox("kAAA")
    draw.text((x, y), "tai", font=ONMARK, fill=WHITE)
    gap = 8
    kx = x + (tai[2] - tai[0]) + gap
    ky = y + tai[3] - kaaa[3]
    draw.text((kx, ky), "kAAA", font=ONMARK, fill=PINK)


def phone(canvas, shot, top):
    side = 78
    bezel = 16
    radius = 62
    x = side + bezel
    y = top + bezel
    inner_w = W - side * 2 - bezel * 2
    inner_h = H - y
    scale = inner_w / shot.width
    up_h = round(shot.height * scale)
    up = shot.resize((inner_w, up_h), Image.Resampling.LANCZOS)
    up = up.filter(ImageFilter.UnsharpMask(radius=1.2, percent=70, threshold=3))
    up = up.crop((0, 0, inner_w, min(inner_h, up_h)))
    mask = Image.new("L", (inner_w, inner_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, inner_w, inner_h + radius), radius=radius, fill=255
    )
    frame = ImageDraw.Draw(canvas)
    frame.rounded_rectangle(
        (side, top, W - side, H + radius),
        radius=radius + bezel,
        fill=BEZEL,
    )
    canvas.paste(up, (x, y), mask)


def render(name, source, line1, line2):
    shot = Image.open(ASSETS / source).convert("RGB")
    canvas = Image.new("RGB", (W, H), BG)
    wordmark(canvas, 84, 78)
    draw = ImageDraw.Draw(canvas)
    tracked(draw, (80, 188), line1, HEAD, WHITE)
    tracked(draw, (80, 292), line2, HEAD, PINK)
    phone(canvas, shot, 468)
    path = OUT / name
    canvas.save(path, "PNG")
    print(path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for page in PAGES:
        render(*page)


if __name__ == "__main__":
    main()
