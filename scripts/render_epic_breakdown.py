#!/usr/bin/env python3
"""Transparent 9:16 schematic: an epic on a line, then a gantt, then one day."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
FPS = 30
DURATION = 13.0
FRAMES = int(FPS * DURATION)

# day span is [start, end) on a 7-day calendar.
# Testing overlaps the end of the build. The metric starts only after release.
ROWS = [
    ("discovery", "зачем", (0, 1)),
    ("decompose", "на части", (1, 2)),
    ("спека", "критерий готово", (2, 3)),
    ("сборка", "дизайн и код", (3, 5)),
    ("тестинг", "проходит ли", (4, 6)),
    ("релиз", "у людей", (5, 6)),
    ("метрика", "изменилось ли", (6, 7)),
]

HITS = [1.05]
for gap in (0.62, 0.74, 0.52, 0.68, 0.5, 0.7):
    HITS.append(HITS[-1] + gap)

GANTT_A, GANTT_B = 5.7, 7.05
COLLAPSE_A, COLLAPSE_B = 9.15, 10.15

INK = (246, 243, 236, 255)
EDGE = (12, 12, 12, 255)
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"

LEFT = 118
CARD_W = 860
ROW_H = 92
ROW_GAP = 16
EPIC_W = 250
EPIC_H = 84
EPIC_GAP = 36
LABEL_COL = 330

STACK = len(ROWS) * ROW_H + (len(ROWS) - 1) * ROW_GAP
BLOCK = EPIC_H + EPIC_GAP + STACK
OY = (H - BLOCK) // 2 - 50

BAR_LEFT = LEFT + LABEL_COL
BAR_RIGHT = LEFT + CARD_W
DAY_W = (BAR_RIGHT - BAR_LEFT) / 7
SPINE_X = LEFT - 28

OUT = Path("/Users/product/Projects/taika/docs/epic-frames")


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
    u = clamp(u)
    c1 = 2.4
    c3 = c1 + 1
    return 1 + c3 * (u - 1) ** 3 + c1 * (u - 1) ** 2


def lerp(a, b, u):
    return a + (b - a) * u


def draw_text(draw, xy, text, font, fill, stroke, stroke_fill, anchor):
    draw.text(
        xy,
        text,
        font=font,
        fill=fill,
        stroke_width=stroke,
        stroke_fill=stroke_fill,
        anchor=anchor,
    )


def row_top(i):
    return OY + EPIC_H + EPIC_GAP + i * (ROW_H + ROW_GAP)


def bar_box(i, t):
    g = ramp(t, GANTT_A, GANTT_B)
    c = ramp(t, COLLAPSE_A, COLLAPSE_B)
    _label, _gloss, (day_a, day_b) = ROWS[i]
    top = row_top(i)
    cy = top + ROW_H / 2

    x_full, w_full = LEFT, CARD_W
    x_bar = BAR_LEFT + day_a * DAY_W + 5
    w_bar = max(36, (day_b - day_a) * DAY_W - 10)
    x_one = BAR_LEFT + 5
    w_one = DAY_W - 10

    x = lerp(lerp(x_full, x_bar, g), x_one, c)
    w = lerp(lerp(w_full, w_bar, g), w_one, c)
    h = lerp(ROW_H, 52, max(g, c))
    return x, cy - h / 2, x + w, cy + h / 2, g, c, cy


def frame_at(t, fonts):
    font_epic, font_kicker, font_label, font_gloss, font_day, font_punch, font_sub = fonts
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    epic_p = ramp(t, 0.12, 0.48)
    if epic_p <= 0:
        return im

    gantt = ramp(t, GANTT_A, GANTT_B)
    collapse = ramp(t, COLLAPSE_A, COLLAPSE_B)
    epic_cy = OY + EPIC_H / 2

    scale = 0.9 + 0.1 * epic_p
    ew, eh = EPIC_W * scale, EPIC_H * scale
    ebox = [LEFT, epic_cy - eh / 2, LEFT + ew, epic_cy + eh / 2]
    draw.rounded_rectangle(ebox, radius=int(24 * scale), fill=INK, outline=EDGE, width=8)
    draw_text(
        draw,
        (LEFT + ew / 2, epic_cy),
        "эпик",
        font_epic,
        EDGE,
        0,
        EDGE,
        "mm",
    )

    kick_a = int(255 * epic_p * (1 - collapse))
    if kick_a > 0:
        draw_text(
            draw,
            (LEFT, OY - 28),
            "не одна задача",
            font_kicker,
            (*INK[:3], kick_a),
            4,
            (*EDGE[:3], kick_a),
            "lm",
        )

    shown = [i for i, hit in enumerate(HITS) if t >= hit]
    if shown:
        y0 = epic_cy
        y1 = row_top(shown[-1]) + ROW_H / 2
        grow = ramp(t, HITS[0] - 0.08, HITS[0] + 0.2)
        y1 = lerp(y0, y1, grow if len(shown) == 1 else 1)
        draw.line([(SPINE_X, y0), (SPINE_X, y1)], fill=EDGE, width=7)
        draw.line([(SPINE_X, y0), (SPINE_X, y1)], fill=INK, width=2)
        draw.line([(SPINE_X, epic_cy), (LEFT - 2, epic_cy)], fill=EDGE, width=7)
        draw.line([(SPINE_X, epic_cy), (LEFT - 2, epic_cy)], fill=INK, width=2)

    # Day columns fade in with the gantt and leave when the week collapses.
    grid_a = int(255 * gantt * (1 - collapse))
    if grid_a > 8:
        for d in range(8):
            x = BAR_LEFT + d * DAY_W
            y_top = epic_cy - 8
            y_bot = row_top(len(ROWS) - 1) + ROW_H
            draw.line([(x, y_top), (x, y_bot)], fill=(*EDGE[:3], grid_a), width=5)
            draw.line([(x, y_top), (x, y_bot)], fill=(*INK[:3], grid_a), width=2)
        for d in range(7):
            draw_text(
                draw,
                (BAR_LEFT + (d + 0.5) * DAY_W, epic_cy),
                str(d + 1),
                font_day,
                (*INK[:3], grid_a),
                4,
                (*EDGE[:3], grid_a),
                "mm",
            )

    for i, (label, gloss, _span) in enumerate(ROWS):
        hit = HITS[i]
        if t < hit:
            continue
        u = clamp((t - hit) / 0.16)
        appear = pop(u) if t < hit + 0.4 else 1.0
        if appear <= 0.02:
            continue

        x0, y0, x1, y1, g, c, cy = bar_box(i, t)
        cx = (x0 + x1) / 2
        mid_y = (y0 + y1) / 2
        hw = (x1 - x0) / 2 * appear
        hh = (y1 - y0) / 2 * appear
        box = [cx - hw, mid_y - hh, cx + hw, mid_y + hh]

        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        tick_a = int(255 * clamp(u * 1.4))
        ld.line([(SPINE_X, cy), (LEFT - 2, cy)], fill=(*EDGE[:3], tick_a), width=7)
        ld.line([(SPINE_X, cy), (LEFT - 2, cy)], fill=(*INK[:3], tick_a), width=2)
        ld.rounded_rectangle(
            box,
            radius=max(4, int(22 * min(appear, 1.1))),
            fill=INK,
            outline=EDGE,
            width=max(2, int(7 * min(appear, 1))),
        )
        im.alpha_composite(layer)
        draw = ImageDraw.Draw(im)

        inside = (1 - g) * (1 if appear > 0.72 else 0)
        if inside > 0.05:
            ia = int(255 * inside)
            draw_text(
                draw,
                (LEFT + 28, cy),
                label,
                font_label,
                (*EDGE[:3], ia),
                0,
                EDGE,
                "lm",
            )
            draw_text(
                draw,
                (LEFT + CARD_W - 28, cy),
                gloss,
                font_gloss,
                (*EDGE[:3], ia),
                0,
                EDGE,
                "rm",
            )

        outside = g * (1 if appear > 0.72 else 0)
        if outside > 0.05:
            oa = int(255 * outside)
            draw_text(
                draw,
                (LEFT + 4, cy),
                label,
                font_label,
                (*INK[:3], oa),
                4,
                (*EDGE[:3], oa),
                "lm",
            )

    punch = ramp(t, COLLAPSE_B - 0.05, COLLAPSE_B + 0.35)
    if punch > 0:
        px = BAR_LEFT + DAY_W + 28
        py = epic_cy - 6
        draw_text(
            draw,
            (px, py - 18),
            "1 день",
            font_punch,
            INK,
            6,
            EDGE,
            "lm",
        )
        draw_text(
            draw,
            (px, py + 36),
            "1 гиперфокус",
            font_sub,
            INK,
            5,
            EDGE,
            "lm",
        )

    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    fonts = (
        ImageFont.truetype(FONT_BOLD, 42),
        ImageFont.truetype(FONT_BOLD, 32),
        ImageFont.truetype(FONT_BOLD, 34),
        ImageFont.truetype(FONT_REG, 28),
        ImageFont.truetype(FONT_BOLD, 28),
        ImageFont.truetype(FONT_BOLD, 52),
        ImageFont.truetype(FONT_BOLD, 32),
    )
    for n in range(FRAMES):
        im = frame_at(n / FPS, fonts)
        im.save(OUT / f"frame_{n:04d}.png")
        if n % 30 == 0:
            print(f"{n}/{FRAMES}", flush=True)
    print("hits", [round(h, 2) for h in HITS], flush=True)
    print("frames", FRAMES, "->", OUT, flush=True)


if __name__ == "__main__":
    main()
