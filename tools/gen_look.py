#!/usr/bin/env python3
"""한장! 픽셀 그림 생성기. 실행: python3 tools/gen_look.py  (레포 루트에서)
작은 격자(1칸 = 1 그림 픽셀)로 그린 뒤 정수 배율 S배로 키워 PNG로 저장한다.
카드·화면 부품·아바타 PNG와 game/ui/theme.tres를 다시 만든다."""
import math, os, shutil
from PIL import Image, ImageDraw

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

def save(img, *parts):
    path = os.path.join(G, "assets", *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((img.width * S, img.height * S), Image.NEAREST).save(path)

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
    "0": "01110,10001,10011,10101,11001,10001,01110", "1": "00100,01100,00100,00100,00100,00100,01110",
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

W, H = 20, 28       # 카드 그림 격자 (몸통 19x26 + 그림자)
BW, BH = 19, 26

def card_base(fill, border=WHITE):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 2, 1 + BW - 1, 2 + BH - 1], fill=(0, 0, 0, 110))   # 두께 그림자
    d.rectangle([0, 0, BW - 1, BH - 1], fill=border)
    d.rectangle([1, 1, BW - 2, BH - 2], fill=fill)
    # 모서리 둥글림
    for (x, y) in [(0, 0), (BW - 1, 0), (0, BH - 1), (BW - 1, BH - 1)]:
        img.putpixel((x, y), (0, 0, 0, 0))
    # 가장자리 아래 두께 줄
    d.line([2, BH, BW - 2, BH], fill=shade(border, 0.62))
    return img

def corner_layer(sym, sym_rows, color):
    layer = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
    if sym_rows:
        bitmap(layer, sym_rows, 2, 2, color)
    bitmap(layer, STAR5, BW - 2 - 5 - 0, 2, color) if False else None
    bitmap(layer, STAR_SM, BW - 7, 2, color)
    return layer

def put_corners(img, small_rows, color):
    layer = corner_layer(None, small_rows, color)
    img.alpha_composite(layer, (0, 0))
    img.alpha_composite(layer.rotate(180), (0, 0))

def glyph_center(img, rows, color, outline, scale=2, dy=0, w=None):
    gw = len(rows[0]) * scale
    gh = len(rows) * scale
    x = 1 + (BW - 2 - gw) // 2
    y = 1 + (BH - 2 - gh) // 2 + dy
    outlined(img, rows, x, y, color, outline, scale)

def plus_value(digit, y_dy=0):
    # +N : 3x3 plus(배율2) + 틈 + 숫자(배율2)
    rows = []
    for j in range(7):
        r = ""
        if 2 <= j < 5 or True:
            pass
        rows.append(r)
    return None

def make_card(color_name, value):
    base = COLORS.get(color_name, BLACK)
    img = card_base(base)
    outline = shade(base, 0.55) if color_name in COLORS else (0, 0, 0, 255)
    if value.isdigit():
        glyph_center(img, D5[value], WHITE, outline)
        put_corners(img, D3[value], WHITE)
    elif value == "skip":
        glyph_center(img, SKIP_BIG, WHITE, outline)
        put_corners(img, SKIP_SMALL, WHITE)
    elif value == "reverse":
        glyph_center(img, REVERSE, WHITE, outline)
        put_corners(img, REV_SMALL, WHITE)
    elif value == "plus2":
        draw_plus(img, "2", WHITE, outline, 0)
        put_corners(img, D3["2"], WHITE)
    elif value == "wild":
        quad(img, 9, 0)
        put_corners(img, None, WHITE)
    elif value == "wild4":
        draw_plus(img, "4", WHITE, outline, -5)
        quad(img, 7, 7)
        put_corners(img, D3["4"], WHITE)
    return img

def draw_plus(img, digit, color, outline, dy):
    gw, gh = 6 + 1 + 10, 14
    x = 1 + (BW - 2 - gw) // 2
    y = 1 + (BH - 2 - gh) // 2 + dy
    outlined(img, PLUS3, x, y + 4, color, outline, 2)
    outlined(img, D5[digit], x + 7, y, color, outline, 2)

def quad(img, size, dy):
    x = 1 + (BW - 2 - size) // 2
    y = 1 + (BH - 2 - size) // 2 + dy
    h = size // 2
    d = ImageDraw.Draw(img)
    d.rectangle([x - 1, y - 1, x + size, y + size], fill=WHITE)
    cs = ["red", "yellow", "blue", "green"]
    for i, n in enumerate(cs):
        qx, qy = x + (i % 2) * (h + 1), y + (i // 2) * (h + 1)
        d.rectangle([qx, qy, qx + h - (0 if i % 2 else 1) - (0), qy + h - (0 if i // 2 else 1)], fill=COLORS[n])

def make_back():
    fill = hexc("27346b")
    img = card_base(fill, hexc("c9d0ff"))
    for y in range(3, BH - 3, 3):
        for x in range(3 + (y // 3 % 2) * 1, BW - 3, 3):
            img.putpixel((x, y), hexc("33427f"))
    big = STAR5
    bitmap(img, big, 2 + 2, 7 + 2, hexc("141a3d"), 2)
    bitmap(img, big, 2, 7, hexc("b9c6ff"), 2)
    return img

def gen_cards():
    for c in COLORS:
        for v in [str(i) for i in range(10)] + ["skip", "reverse", "plus2"]:
            save(make_card(c, v), "cards", f"{c}_{v}.png")
    save(make_card("wild", "wild"), "cards", "wild.png")
    save(make_card("wild", "wild4"), "cards", "wild4.png")
    save(make_back(), "cards", "back.png")

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
Copyright (c) The Galmuri Project Authors, https://galmuri.quiple.dev/

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

