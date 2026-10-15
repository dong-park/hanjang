#!/usr/bin/env python3
"""한장! 픽셀 그림 생성기. 실행: python3 tools/gen_look.py  (레포 루트에서)
작은 격자(1칸 = 1 그림 픽셀)로 그린 뒤 정수 배율 S배로 키워 PNG로 저장한다.
카드·화면 부품·아바타 PNG와 game/ui/theme.tres를 다시 만든다."""
import math, os, shutil
from PIL import Image, ImageDraw, ImageFilter

S = 4  # 모든 그림 공통 배율
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
G = os.path.join(ROOT, "game")
FONT_SRC = "/Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/pixel-onecard-storyboard/fonts"

def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

def shade(c, f):
    return (int(c[0] * f), int(c[1] * f), int(c[2] * f), c[3])

WHITE = hexc("f4f6ff")
NAVY = hexc("151a2e")
COLORS = {"red": hexc("e8333a"), "yellow": hexc("e3a82b"),
          "green": hexc("2f9e5a"), "blue": hexc("2d62c8")}
BLACK = hexc("16161f")

def save(img, *parts, scale=None):
    scale = scale or S
    path = os.path.join(G, "assets", *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(path)

def bitmap(img, rows, x, y, color, scale=1):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "#":
                for a in range(scale):
                    for b in range(scale):
                        px, py_ = x + i * scale + a, y + j * scale + b
                        if 0 <= px < img.width and 0 <= py_ < img.height:
                            img.putpixel((px, py_), color)

def outlined(img, rows, x, y, color, outline, scale=1):
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                bitmap(img, rows, x + dx, y + dy, outline, scale)
    bitmap(img, rows, x, y, color, scale)

def parse(s):
    return s.split(",")

D5 = {
    "0": "01110,10001,10001,10001,10001,10001,01110", "1": "00100,01100,00100,00100,00100,00100,01110",
    "2": "01110,10001,00001,00010,00100,01000,11111", "3": "11110,00001,00001,01110,00001,00001,11110",
    "4": "00010,00110,01010,10010,11111,00010,00010", "5": "11111,10000,11110,00001,00001,10001,01110",
    "6": "00110,01000,10000,11110,10001,10001,01110", "7": "11111,00001,00010,00100,01000,01000,01000",
    "8": "01110,10001,10001,01110,10001,10001,01110", "9": "01110,10001,10001,01111,00001,00010,01100",
}
D3 = {
    "0": "111,101,101,101,111", "1": "010,110,010,010,111", "2": "111,001,111,100,111",
    "3": "111,001,111,001,111", "4": "101,101,111,001,001", "5": "111,100,111,001,111",
    "6": "111,100,111,101,111", "7": "111,001,010,010,010", "8": "111,101,111,101,111",
    "9": "111,101,111,001,111",
}
def conv(d):
    return {k: [r.replace("1", "#").replace("0", ".") for r in parse(v)] for k, v in d.items()}
D5, D3 = conv(D5), conv(D3)
PLUS3 = ["." + "#" + ".", "###", ".#."]
STAR5 = ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "##...##"]
STAR_SM = ["..#..", "#####", ".###.", ".#.#.", "#...#"]
SKIP_SMALL = [".###.", "#..#.", "#.#.#", ".#..#", ".###."]
REV_SMALL = ["..#..", ".###.", "#.#.#", "..#..", "..#.."]
REV_SMALL = ["..#..", ".###.", "..#..", "..#..", "..#.."]
REVERSE = parse("..#.....,.###....,#####...,..#..#..,..#..#..,..#..#..,..#..#..,..######,....###.,.....#..")

def skip_big():
    rows = []
    for y in range(8):
        r = ""
        for x in range(8):
            d = math.hypot(x - 3.5, y - 3.5)
            ring = 2.5 <= d <= 4.0
            slash = abs((x - 3.5) - (y - 3.5)) <= 0.6 and d < 4.0
            r += "#" if ring or slash else "."
        rows.append(r)
    return rows
SKIP_BIG = skip_big()

CS = 2   # 카드 그림 배율 (격자 40x56 -> 80x112)
W, H = 40, 56       # 카드 그림 격자 (몸통 39x52 + 두께 3)
BW, BH = 39, 52
OUTL = hexc("0d1020")

def mask_from_rows(rows):
    m = Image.new("L", (len(rows[0]), len(rows)), 0)
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch == "#":
                m.putpixel((i, j), 255)
    return m

def scaled_mask(rows, k):
    m = mask_from_rows(rows)
    return m.resize((m.width * k, m.height * k), Image.NEAREST)

def stamp(img, mask, x, y, color=None, outline=OUTL, shadow=True, shadow_dy=2):
    """mask(L)를 굵은 글자로 찍는다: 아래 그림자 + 1픽셀 어두운 테두리 + 꽉 찬 색."""
    color = color or WHITE
    pad = 2
    big = Image.new("L", (mask.width + 2 * pad, mask.height + 2 * pad), 0)
    big.paste(mask, (pad, pad))
    edge = big.filter(ImageFilter.MaxFilter(3)).point(lambda v: 255 if v else 0)
    ox, oy = x - pad, y - pad
    if shadow:
        sh = Image.new("RGBA", big.size, outline)
        img.paste(sh, (ox, oy + shadow_dy), edge)
    img.paste(Image.new("RGBA", big.size, outline), (ox, oy), edge)
    img.paste(Image.new("RGBA", big.size, color), (ox, oy), big)

def centered(img, mask, dy=0, color=None):
    x = (BW - mask.width) // 2
    y = (BH - mask.height) // 2 + dy
    stamp(img, mask, x, y, color)

def card_base(fill, border=WHITE):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 3, BW, BH + 2], fill=(0, 0, 0, 110))                 # 바닥 그림자
    d.rectangle([1, 2, BW - 2, BH + 1], fill=shade(border, 0.6))        # 카드 두께(아래 3픽셀 어두운 면)
    d.rectangle([0, 0, BW - 1, BH - 1], fill=border)                     # 흰 테두리
    d.rectangle([2, 2, BW - 3, BH - 3], fill=fill)                       # 바탕색
    d.rectangle([2, 2, BW - 3, BH - 3], outline=shade(fill, 1.28) if fill[0] + fill[1] + fill[2] > 120 else shade(fill, 2.2))  # 안쪽 밝은 선
    for (x, y) in [(0, 0), (BW - 1, 0), (0, BH - 1), (BW - 1, BH - 1)]:
        img.putpixel((x, y), (0, 0, 0, 0))
    for (x, y) in [(1, 0), (0, 1), (BW - 2, 0), (BW - 1, 1), (1, BH - 1), (0, BH - 2), (BW - 2, BH - 1), (BW - 1, BH - 2)]:
        img.putpixel((x, y), shade(border, 0.9))
    return img

def corner_stars(img, x_off=0):
    star = Image.new("RGBA", (5, 5), (0, 0, 0, 0))
    bitmap(star, STAR_SM, 0, 0, WHITE)
    img.alpha_composite(star, (BW - 9, 4))
    img.alpha_composite(star.rotate(180), (4, BH - 9))

def put_corner_glyph(img, rows, color=None):
    """왼쪽 위 + 오른쪽 아래 (180도 돌린 그림) 두 곳에만 찍는다."""
    layer = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
    stamp(layer, mask_from_rows(rows), 4, 4, color, shadow=False)
    img.alpha_composite(layer, (0, 0))
    img.alpha_composite(layer.rotate(180), (0, 0))

def circle_mask(size, r_out, r_in=None):
    m = Image.new("L", (size, size), 0)
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if d <= r_out and (r_in is None or d >= r_in):
                m.putpixel((x, y), 255)
    return m

def skip_mask():
    size = 30
    m = circle_mask(size, 14.8, 10.8)         # 굵기 4픽셀 원
    d = ImageDraw.Draw(m)
    c = (size - 1) / 2
    for t in range(-14, 15):                     # 원을 꽉 가로지르는 대각 막대(두께 4)
        for w in range(-2, 2):
            x, y = int(round(c + t * 0.7071 + w * 0.7071)), int(round(c + t * 0.7071 - w * 0.7071))
            if math.hypot(x - c, y - c) <= 14.8 and 0 <= x < size and 0 <= y < size:
                m.putpixel((x, y), 255)
    for t in range(-14, 15):
        for w in range(-2, 2):
            x, y = int(round(c + t * 0.7071 + w * 0.7071 + 1)), int(round(c + t * 0.7071 - w * 0.7071))
            if math.hypot(x - c, y - c) <= 14.8 and 0 <= x < size and 0 <= y < size:
                m.putpixel((x, y), 255)
    return m

def reverse_mask():
    m = Image.new("L", (30, 30), 0)
    d = ImageDraw.Draw(m)
    d.rectangle([1, 6, 20, 9], fill=255)
    d.polygon([(19, 1), (29, 7.5), (19, 14)], fill=255)
    return Image.composite(Image.new("L", m.size, 255), m, m.rotate(180))

def plus_mask(digit):
    k = 3
    plus = scaled_mask(PLUS3, k)
    dig = scaled_mask(D5[digit], k)
    m = Image.new("L", (plus.width + 2 + dig.width, dig.height), 0)
    m.paste(plus, (0, (dig.height - plus.height) // 2))
    m.paste(dig, (plus.width + 2, 0))
    return m

def color_circle(img, cx, cy, r, ring=True):
    d = ImageDraw.Draw(img)
    cs = {(-1, -1): "red", (1, -1): "yellow", (-1, 1): "blue", (1, 1): "green"}
    if ring:
        for y in range(cy - r - 2, cy + r + 3):
            for x in range(cx - r - 2, cx + r + 3):
                dd = math.hypot(x - cx + 0.0, y - cy + 0.0)
                if dd <= r + 2:
                    img.putpixel((x, y), OUTL if dd > r + 1 else WHITE)
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if math.hypot(x - cx, y - cy) <= r:
                if x == cx or y == cy:
                    img.putpixel((x, y), WHITE)
                else:
                    img.putpixel((x, y), COLORS[cs[(1 if x > cx else -1, 1 if y > cy else -1)]])

def make_card(color_name, value):
    base = COLORS.get(color_name, BLACK)
    img = card_base(base)
    if value.isdigit():
        centered(img, scaled_mask(D5[value], 4))
        put_corner_glyph(img, D5[value])
        corner_stars(img)
    elif value == "skip":
        centered(img, skip_mask())
        put_corner_glyph(img, SKIP_SMALL)
        corner_stars(img)
    elif value == "reverse":
        centered(img, reverse_mask())
        put_corner_glyph(img, REV_SMALL)
        corner_stars(img)
    elif value == "plus2":
        centered(img, plus_mask("2"))
        put_corner_glyph(img, D5["2"])
        corner_stars(img)
    elif value == "wild":
        stamp(img, circle_mask(31, 15.5), (BW - 31) // 2, (BH - 31) // 2, WHITE)
        color_circle(img, BW // 2, BH // 2, 12)
        corner_stars(img)
        c = Image.new("RGBA", (9, 9), (0, 0, 0, 0)); color_circle(c, 4, 4, 2, ring=False)
        img.alpha_composite(c, (4, 4)); img.alpha_composite(c.rotate(180), (BW - 13, BH - 13))
    elif value == "wild4":
        m = plus_mask("4")
        stamp(img, m, (BW - m.width) // 2, 6, WHITE)
        color_circle(img, BW // 2, 38, 6)
        put_corner_glyph(img, D5["4"])
        corner_stars(img)
    return img

def make_back():
    fill = hexc("27346b")
    img = card_base(fill, hexc("c9d0ff"))
    for y in range(5, BH - 4, 4):
        for x in range(5 + (y // 4 % 2) * 2, BW - 4, 4):
            img.putpixel((x, y), hexc("33427f"))
    stamp(img, scaled_mask(STAR5, 3), (BW - 21) // 2, (BH - 21) // 2, hexc("b9c6ff"), outline=hexc("141a3d"))
    deco = Image.new("RGBA", (7, 7), (0, 0, 0, 0))
    bitmap(deco, ["#####..", "#......", "#..#...", "#.###..", "#..#...", "#......", "......."], 0, 0, hexc("7f93e8"))
    img.alpha_composite(deco, (4, 4))
    img.alpha_composite(deco.transpose(Image.FLIP_LEFT_RIGHT), (BW - 11, 4))
    img.alpha_composite(deco.transpose(Image.FLIP_TOP_BOTTOM), (4, BH - 11))
    img.alpha_composite(deco.rotate(180), (BW - 11, BH - 11))
    return img

def gen_cards():
    for c in COLORS:
        for v in [str(i) for i in range(10)] + ["skip", "reverse", "plus2"]:
            save(make_card(c, v), "cards", f"{c}_{v}.png", scale=CS)
    save(make_card("wild", "wild"), "cards", "wild.png", scale=CS)
    save(make_card("wild", "wild4"), "cards", "wild4.png", scale=CS)
    save(make_back(), "cards", "back.png", scale=CS)


# ---------- 화면 부품 ----------
def box(w, h, fill, border, hi=None, lo=None):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if lo:
        d.rectangle([0, 1, w - 1, h - 1], fill=lo)       # 두께 그림자
        d.rectangle([0, 0, w - 1, h - 2], fill=border)
    else:
        d.rectangle([0, 0, w - 1, h - 1], fill=border)
    bh = h - 1 if lo else h
    d.rectangle([1, 1, w - 2, bh - 2], fill=fill)
    if hi:
        d.line([1, 1, w - 2, 1], fill=hi)
    for (x, y) in [(0, 0), (w - 1, 0), (0, bh - 1), (w - 1, bh - 1)]:
        img.putpixel((x, y), (0, 0, 0, 0))
    return img

def gen_ui():
    save(box(12, 12, hexc("1c2547"), hexc("4a5aa8"), lo=hexc("0b0f20")), "ui", "panel.png")
    for name, fill, hi in (("normal", "2a3d96", "4a63d0"), ("hover", "3550bd", "6a85f0"),
                           ("pressed", "1f2e78", "2a3d96"), ("disabled", "2a2f4a", "3a4064")):
        border = hexc("c9d0ff") if name != "disabled" else hexc("6a7098")
        save(box(16, 12, hexc(fill), border, hi=hexc(hi), lo=hexc("0b0f20")), "ui", f"button_{name}.png")
    save(box(12, 10, hexc("0e1224"), hexc("4a5aa8")), "ui", "input.png")
    save(box(12, 10, hexc("0e1224"), hexc("5ae0ff")), "ui", "input_focus.png")
    # 아바타 칸 18x18 (안쪽 16x16에 얼굴)
    for name, border, outer in (("normal", "c9d0ff", None), ("turn", "5ae0ff", "5ae0ff"), ("gray", "6a7098", None)):
        img = Image.new("RGBA", (22, 22), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        if outer:
            d.rectangle([0, 0, 21, 21], fill=hexc(outer, 70))
            d.rectangle([1, 1, 20, 20], fill=hexc(outer, 130))
        d.rectangle([2, 2, 19, 19], fill=hexc(border))
        d.rectangle([3, 3, 18, 18], fill=hexc("2a376e") if name != "gray" else hexc("30344a"))
        for (x, y) in [(2, 2), (19, 2), (2, 19), (19, 19)]:
            img.putpixel((x, y), (0, 0, 0, 0) if not outer else hexc(outer, 130))
        save(img, "ui", f"avatar_frame_{name}.png")
    # 왕관 9x6
    crown = Image.new("RGBA", (9, 6), (0, 0, 0, 0))
    bitmap(crown, parse("#...#...#,##.###.##,#########,#########,#########,.#######."), 0, 0, hexc("ffd23f"))
    bitmap(crown, parse("........., ........., ........., ........., ........., ........."), 0, 0, WHITE)
    for x in (2, 4, 6):
        crown.putpixel((x, 3), hexc("e8333a"))
    save(crown, "ui", "crown.png")
    # 방향 고리 64x64
    ring = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    col, cx, cy, r = hexc("3b52c8"), 31.5, 31.5, 26
    for y in range(64):
        for x in range(64):
            dd = math.hypot(x - cx, y - cy)
            if abs(dd - r) < 1.0:
                ang = math.atan2(y - cy, x - cx) % (2 * math.pi)
                if int(ang / (2 * math.pi) * 40) % 2 == 0:
                    ring.putpixel((x, y), col)
    tri = ["#....", "###..", "#####", "###..", "#...."]  # 오른쪽 가리킴
    def arrow(rows, px, py_):
        bitmap(ring, rows, px, py_, hexc("5a74f0"))
    right = ["#....", "###..", "#####", "###..", "#...."]
    down = [r_ for r_ in zip(*right)]
    down = ["".join(c) for c in down]
    left = [r_[::-1] for r_ in right]
    up = [r_[::-1] for r_ in down]
    # 시계 방향: 위 → 오른쪽 가리킴, 오른쪽 → 아래, 아래 → 왼쪽, 왼쪽 → 위
    arrow(right, 29, 3)
    arrow(down, 56, 29)
    arrow(left, 29, 56)
    arrow(up, 3, 29)
    save(ring, "ui", "ring.png")
    save(box(8, 6, hexc("0e1224"), hexc("4a5aa8")), "ui", "timebar_bg.png")
    tf = Image.new("RGBA", (4, 4), hexc("5ae0ff"))
    ImageDraw.Draw(tf).line([0, 0, 3, 0], fill=hexc("b8f4ff"))
    save(tf, "ui", "timebar_fill.png")
    tile = Image.new("RGBA", (16, 16), NAVY)
    for (x, y) in ((3, 3), (11, 11)):
        tile.putpixel((x, y), hexc("222b52"))
    save(tile, "ui", "bg_tile.png")

FACE = parse("................,.....HHHHHH.....,....HHHHHHHH....,...HHHHHHHHHH...,"
             "...HHHHHHHHHH...,...HHSSSSSSHH...,...HSSSSSSSSH...,...HSEESSEESH...,"
             "...HSEESSEESH...,...SSSSSSSSSS...,...SCCSSSSCCS...,...SSSSMMSSSS...,"
             "....SSSSSSSS....,.....SSSSSS.....,................,................")
FACE = [r.replace("1", "#") for r in FACE]
def gen_avatars():
    hairs = [("blue", "3aa0f0", False), ("green", "35c26a", False), ("pink", "f06ea8", True), ("brown", "7a4a2a", False)]
    for i, (n, hc, long_) in enumerate(hairs):
        img = Image.new("RGBA", (16, 16), hexc("2a376e"))
        pal = {"H": hexc(hc), "S": hexc("f6c9a0"), "E": hexc("2a1a1a"), "C": hexc("f09a8c"), "M": hexc("b0483c")}
        for y, row in enumerate(FACE):
            assert len(row) == 16, (y, row)
            for x, ch in enumerate(row):
                if ch in pal:
                    img.putpixel((x, y), pal[ch])
        if long_:
            for y in range(9, 14):
                img.putpixel((3, y), pal["H"]); img.putpixel((12, y), pal["H"])
        if n == "brown":
            for x in range(6, 10):
                img.putpixel((x, 5), pal["H"])
        # 머리 윗선 밝은 점
        img.putpixel((6, 2), shade(pal["H"], 1.3) if False else tuple(min(255, int(v * 1.25)) for v in pal["H"][:3]) + (255,))
        save(img, "avatars", f"face_{i}.png")

# ---------- 폰트 ----------
OFL_NOTE = """Galmuri font family (Galmuri11, Galmuri11-Bold)
Copyright (c) 2019-2025 Lee Minseo (quiple@quiple.dev), https://github.com/quiple/galmuri

This Font Software is licensed under the SIL Open Font License, Version 1.1.
This license is copied below, and is also available with a FAQ at:
https://openfontlicense.org

-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded,
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply
to any document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software components as
distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting,
or substituting -- in part or in whole -- any of the components of the
Original Version, by changing formats or by porting the Font Software to a
new environment.

"Author" refers to any designer, engineer, programmer, technical
writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components,
in Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the corresponding
Copyright Holder. This restriction only applies to the primary font name as
presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created
using the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
OTHER DEALINGS IN THE FONT SOFTWARE.
"""
def gen_fonts():
    d = os.path.join(G, "assets", "fonts")
    os.makedirs(d, exist_ok=True)
    for f in ("Galmuri11.ttf", "Galmuri11-Bold.ttf"):
        src = os.path.join(FONT_SRC, f)
        if os.path.exists(src):
            shutil.copy(src, d)
    with open(os.path.join(d, "OFL.txt"), "w") as fh:
        fh.write(OFL_NOTE)

# ---------- 테마 ----------
def gen_theme():
    res = [("Texture2D", "res://assets/ui/" + n + ".png") for n in
           ["panel", "button_normal", "button_hover", "button_pressed", "button_disabled",
            "input", "input_focus", "timebar_bg", "timebar_fill"]]
    res += [("FontFile", "res://assets/fonts/Galmuri11.ttf"), ("FontFile", "res://assets/fonts/Galmuri11-Bold.ttf")]
    ids = {p.split("/")[-1].rsplit(".", 1)[0]: i + 1 for i, (_, p) in enumerate(res)}
    lines = [f'[gd_resource type="Theme" load_steps={len(res) + 12} format=3]', ""]
    for i, (t, p) in enumerate(res):
        lines.append(f'[ext_resource type="{t}" path="{p}" id="{i + 1}"]')
    lines.append("")
    def sb(name, tex, m, cm):
        lines.extend([f'[sub_resource type="StyleBoxTexture" id="sb_{name}"]',
                      f'texture = ExtResource("{ids[tex]}")',
                      *(f"texture_margin_{s} = {m * S}.0" for s in ("left", "top", "right", "bottom")),
                      *(f"content_margin_{s} = {v}.0" for s, v in zip(("left", "top", "right", "bottom"), cm)),
                      "axis_stretch_horizontal = 1", "axis_stretch_vertical = 1", ""])
    sb("panel", "panel", 4, (20, 16, 20, 24))
    for n in ("normal", "hover", "pressed", "disabled"):
        sb("btn_" + n, "button_" + n, 4, (24, 14, 24, 22) if n != "pressed" else (24, 18, 24, 18))
    sb("input", "input", 4, (16, 8, 16, 8))
    sb("input_focus", "input_focus", 4, (16, 8, 16, 8))
    sb("bar_bg", "timebar_bg", 3, (0, 0, 0, 0))
    sb("bar_fill", "timebar_fill", 1, (0, 0, 0, 0))
    lines += ["[resource]",
              f'default_font = ExtResource("{ids["Galmuri11"]}")', "default_font_size = 22",
              'Label/colors/font_color = Color(0.91, 0.925, 1, 1)',
              'Button/colors/font_color = Color(1, 1, 1, 1)',
              'Button/colors/font_hover_color = Color(1, 1, 1, 1)',
              'Button/colors/font_pressed_color = Color(0.85, 0.9, 1, 1)',
              'Button/colors/font_disabled_color = Color(0.55, 0.58, 0.7, 1)',
              'Button/styles/normal = SubResource("sb_btn_normal")',
              'Button/styles/hover = SubResource("sb_btn_hover")',
              'Button/styles/pressed = SubResource("sb_btn_pressed")',
              'Button/styles/disabled = SubResource("sb_btn_disabled")',
              'Button/styles/focus = SubResource("sb_btn_hover")',
              'LineEdit/colors/font_color = Color(1, 1, 1, 1)',
              'LineEdit/colors/font_placeholder_color = Color(0.45, 0.5, 0.7, 1)',
              'LineEdit/colors/caret_color = Color(0.35, 0.88, 1, 1)',
              'LineEdit/styles/normal = SubResource("sb_input")',
              'LineEdit/styles/focus = SubResource("sb_input_focus")',
              'Panel/styles/panel = SubResource("sb_panel")',
              'PanelContainer/styles/panel = SubResource("sb_panel")',
              'ProgressBar/styles/background = SubResource("sb_bar_bg")',
              'ProgressBar/styles/fill = SubResource("sb_bar_fill")',
              'BoldLabel/base_type = &"Label"',
              f'BoldLabel/fonts/font = ExtResource("{ids["Galmuri11-Bold"]}")',
              ""]
    with open(os.path.join(G, "ui", "theme.tres"), "w") as fh:
        fh.write("\n".join(lines))

if __name__ == "__main__":
    gen_cards(); gen_ui(); gen_avatars(); gen_fonts(); gen_theme()
    print("ok")

