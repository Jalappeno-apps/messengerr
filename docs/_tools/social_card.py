#!/usr/bin/env python3
"""Generates the docs site's social-sharing image and icon PNGs.

    python3 docs/_tools/social_card.py

Writes docs/assets/images/social-card.png (1200x630, Open Graph / Twitter), favicon-32.png and
apple-touch-icon.png. The outputs are committed, so the site build needs neither Python nor fonts.
Needs Pillow (pip install pillow). Text uses Nunito (SIL OFL, bundled in _tools/fonts) and the
system monospace font for the install command (macOS path; edit for Linux).
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "assets", "images")
NUNITO = os.path.join(HERE, "fonts", "Nunito[wght].ttf")
FONT_MONO = "/System/Library/Fonts/Menlo.ttc"

SIENNA = (132, 42, 0)
CREAM = (254, 252, 247)
PEACH = (253, 240, 220)
AMBER = (239, 168, 16)
INK = (11, 14, 11)
MUTED = (106, 100, 87)
TERM = (23, 18, 13)


def nunito(size, weight):
    f = ImageFont.truetype(NUNITO, size)
    f.set_variation_by_axes([weight])
    return f


def mono(size):
    return ImageFont.truetype(FONT_MONO, size)


def gradient(width, height, top, bottom):
    img = Image.new("RGB", (width, height), top)
    px = img.load()
    for y in range(height):
        t = y / (height - 1)
        row = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(width):
            px[x, y] = row
    return img


def draw_mark(size):
    """The logo from assets/images/logo.svg (a 32-unit grid), at `size` pixels, with transparency."""
    scale = 4  # supersample for smooth edges
    s = size * scale
    k = s / 32.0
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=8 * k, fill=SIENNA + (255,))
    # the "m" is Nunito ExtraBold, 18 units wide, baseline at y=21.75 (same geometry as the SVG)
    d.text((16 * k, 21.75 * k), "m", font=nunito(round(23.34 * k), 800), fill=CREAM + (255,), anchor="ms")
    d.ellipse([(25.6 - 2.3) * k, (7.4 - 2.3) * k, (25.6 + 2.3) * k, (7.4 + 2.3) * k], fill=AMBER + (255,))
    return img.resize((size, size), Image.LANCZOS)


def social_card():
    w, h = 1200, 630
    card = gradient(w, h, CREAM, PEACH)

    glow = Image.new("RGBA", (w, h), AMBER + (0,))  # same hue as the glow, so blurring does not tint it grey
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-260, -300, 620, 460], fill=AMBER + (60,))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    card = Image.alpha_composite(card.convert("RGBA"), glow)
    d = ImageDraw.Draw(card)

    card.alpha_composite(draw_mark(132), (84, 84))
    d.text((240, 104), "messengerr", font=nunito(64, 800), fill=SIENNA)
    d.text((242, 178), "Email and SMS from a CSV list", font=nunito(26, 600), fill=MUTED)

    headline = nunito(72, 800)
    d.text((84, 270), "Send templated messages", font=headline, fill=INK)
    d.text((84, 354), "to a list, safely.", font=headline, fill=INK)

    d.text((84, 462), "Preview first. Never lose track of who got what.",
           font=nunito(28, 600), fill=MUTED)

    m = mono(28)
    text = "gem install messengerr"
    pad_x, pad_y = 26, 18
    tw = d.textlength("$ " + text, font=m)
    box = [84, 520, 84 + tw + pad_x * 2, 520 + 28 + pad_y * 2 + 4]
    d.rounded_rectangle(box, radius=14, fill=TERM)
    d.text((84 + pad_x, 520 + pad_y), "$", font=m, fill=(143, 135, 122))
    d.text((84 + pad_x + d.textlength("$ ", font=m), 520 + pad_y), text, font=m, fill=(230, 225, 214))

    d.text((w - 84, h - 72), "jalappeno-apps.github.io/messengerr", font=nunito(24, 600),
           fill=MUTED, anchor="ra")
    d.rectangle([0, h - 10, w, h], fill=SIENNA)
    card.convert("RGB").save(os.path.join(OUT, "social-card.png"), optimize=True)


def icons():
    draw_mark(32).save(os.path.join(OUT, "favicon-32.png"), optimize=True)
    # iOS draws its own rounded corners, so give it a full-bleed square.
    inner = Image.new("RGB", (180, 180), SIENNA)
    mark = draw_mark(124)
    inner.paste(mark, (28, 28), mark)
    inner.save(os.path.join(OUT, "apple-touch-icon.png"), optimize=True)


if __name__ == "__main__":
    social_card()
    icons()
    print("wrote social-card.png, favicon-32.png, apple-touch-icon.png in", os.path.normpath(OUT))
