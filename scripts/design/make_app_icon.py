"""Chalkline app icon: an iron logbook page with three set rows — two
logged (chalk bar + filled chalk check), the next one waiting (faint bar +
signal-orange check ring) — over the set table's rule. Colors are the
Chalkline tokens (panel #171614, onPanel #F2EEE5, accent #EC4E25).

Usage: python3 scripts/design/make_app_icon.py fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
Requires Pillow (pip install pillow).
"""
from PIL import Image, ImageDraw
import sys

S = 4  # supersampling
W = 1024 * S
IRON = (0x17, 0x16, 0x14, 255)
CHALK = (0xF2, 0xEE, 0xE5, 255)
CHALK_FAINT = (0xF2, 0xEE, 0xE5, 70)
ACCENT = (0xEC, 0x4E, 0x25, 255)

def px(v):
    return int(round(v * S))

img = Image.new("RGBA", (W, W), IRON)
layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)

rows = [  # (center y, bar end x, state)
    (290, 600, "done"),
    (472, 548, "done"),
    (654, 640, "next"),
]
left, bar_h = 184, 84
cx, r = 806, 70
for cy, bar_end, state in rows:
    bar = (px(left), px(cy - bar_h / 2), px(bar_end), px(cy + bar_h / 2))
    d.rounded_rectangle(bar, radius=px(bar_h / 2), fill=CHALK if state == "done" else CHALK_FAINT)
    circle = (px(cx - r), px(cy - r), px(cx + r), px(cy + r))
    if state == "done":
        d.ellipse(circle, fill=CHALK)
        # checkmark in iron
        pts = [(cx - 30, cy + 2), (cx - 8, cy + 26), (cx + 34, cy - 24)]
        d.line([(px(x), px(y)) for x, y in pts], fill=IRON, width=px(17), joint="curve")
        for x, y in (pts[0], pts[-1]):
            d.ellipse((px(x - 8.5), px(y - 8.5), px(x + 8.5), px(y + 8.5)), fill=IRON)
    else:
        d.ellipse(circle, outline=ACCENT, width=px(18))

# rule under the rows (the table rule of the set table)
d.rounded_rectangle((px(left), px(772), px(cx + r), px(784)), radius=px(6), fill=(0xF2, 0xEE, 0xE5, 60))

img = Image.alpha_composite(img, layer).resize((1024, 1024), Image.LANCZOS).convert("RGB")
img.save(sys.argv[1], optimize=True)
