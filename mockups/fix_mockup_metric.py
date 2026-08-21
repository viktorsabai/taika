from PIL import Image, ImageDraw, ImageFont

src = "/home/ubuntu/taika-repo/mockups/grade_sheet_editorial_final_v3.png"
out = "/home/ubuntu/taika-repo/mockups/grade_sheet_editorial_final.png"
img = Image.open(src).convert("RGB")
draw = ImageDraw.Draw(img)
# The third lesson fraction is the only incorrect generated text. Cover only that glyph area.
draw.rectangle((198, 2160, 343, 2225), fill=(25, 27, 28))
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 43)
draw.text((207, 2164), "8/8", font=font, fill=(244, 244, 246))
img.save(out, quality=96)
