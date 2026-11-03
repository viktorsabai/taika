#!/usr/bin/env python3
"""Transparent 9:16 solo-product bingo for a Reels overlay."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
FPS = 30
DURATION = 11.0
FRAMES = int(FPS * DURATION)

LABELS = [
    "деплой", "фикс", "код",
    "оффер", "рилс", "прогрев",
    "сабай", "том ям", "закат",
]

# Jumps around the board and mixes code, promo, and sabai.
ORDER = [2, 5, 6, 0, 8, 3, 1, 7, 4]
# Uneven gaps so the hits don't feel like a metronome.
HITS = [1.05]
for gap in (0.58, 0.82, 0.46, 0.9, 0.52, 0.74, 0.44, 0.86):
    HITS.append(HITS[-1] + gap)

INK = (246, 243, 236, 255)
EDGE = (12, 12, 12, 255)
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

CELL = 250
GAP = 36
GRID = CELL * 3 + GAP * 2
OX = (W - GRID) // 2
OY = (H - GRID) // 2 - 30

OUT = Path("/Users/product/Projects/taika/docs/solo-bingo-frames")


def clamp(u: float) -> float:
    return max(0.0, min(1.0, u))


def ease(u: float) -> float:
    u = clamp(u)
    return 1 - (1 - u) ** 3


def ramp(t, a, b):
    if t < a:
        return 0.0
    if b <= a:
        return 1.0
    return ease((t - a) / (b - a))


def pop(u: float) -> float:
    """0 at the start, overshoots, settles at 1. Whole shape, not a drawn stroke."""
    u = clamp(u)
    c1 = 2.4
    c3 = c1 + 1
    return 1 + c3 * (u - 1) ** 3 + c1 * (u - 1) ** 2


def cell_center(i):
    r, c = divmod(i, 3)
    x = OX + c * (CELL + GAP) + CELL / 2
    y = OY + r * (CELL + GAP) + CELL / 2
    return x, y


def draw_text(draw, xy, text, font, fill, stroke, stroke_fill):
    draw.text(
        xy,
        text,
        font=font,
        fill=fill,
        stroke_width=stroke,
        stroke_fill=stroke_fill,
        anchor="mm",
    )


def frame_at(t, font):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    line_p = ramp(t, 0.12, 0.7)
    if line_p > 0:
        for k in (1, 2):
            x = OX + k * CELL + (k - 1) * GAP + GAP / 2
            y0 = OY + (1 - line_p) * GRID * 0.5
            y1 = OY + line_p * GRID + (1 - line_p) * GRID * 0.5
            draw.line([(x, y0), (x, y1)], fill=EDGE, width=7)
            draw.line([(x, y0), (x, y1)], fill=INK, width=2)
            y = OY + k * CELL + (k - 1) * GAP + GAP / 2
            x0 = OX + (1 - line_p) * GRID * 0.5
            x1 = OX + line_p * GRID + (1 - line_p) * GRID * 0.5
            draw.line([(x0, y), (x1, y)], fill=EDGE, width=7)
            draw.line([(x0, y), (x1, y)], fill=INK, width=2)

    words_p = ramp(t, 0.35, 0.7)
    if words_p <= 0:
        return im

    hits = {index: hit for hit, index in zip(HITS, ORDER)}

    for i, label in enumerate(LABELS):
        cx, cy = cell_center(i)
        hit = hits[i]
        u = 0.0 if t < hit else clamp((t - hit) / 0.16)
        scale = pop(u) if t >= hit else 0.0

        if scale > 0.02:
            layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            half = (CELL * 0.46) * scale
            box = [cx - half, cy - half, cx + half, cy + half]
            ld.rounded_rectangle(
                box,
                radius=max(4, int(32 * min(scale, 1.15))),
                fill=INK,
                outline=EDGE,
                width=max(2, int(8 * min(scale, 1))),
            )
            im.alpha_composite(layer)
            draw = ImageDraw.Draw(im)
            draw_text(draw, (cx, cy), label, font, EDGE, 0, EDGE)
        else:
            ink = (*INK[:3], int(255 * words_p))
            draw_text(draw, (cx, cy), label, font, ink, 5, (*EDGE[:3], int(255 * words_p)))

    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype(FONT_PATH, 46)
    for n in range(FRAMES):
        t = n / FPS
        im = frame_at(t, font)
        im.save(OUT / f"frame_{n:04d}.png")
        if n % 30 == 0:
            print(f"{n}/{FRAMES}", flush=True)
    print("frames", FRAMES, "->", OUT, flush=True)


if __name__ == "__main__":
    main()
