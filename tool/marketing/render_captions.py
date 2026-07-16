#!/usr/bin/env python3
"""Pre-render the promo video's text overlays (captions, wordmark, rounded
intro icon) as transparent PNGs in tool/marketing/out/. Needed because this
machine's ffmpeg build has no drawtext filter (no libfreetype).
Run from repo root: python3 tool/marketing/render_captions.py
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "tool" / "marketing" / "out"
FONT = str(ROOT / "tool" / "marketing" / "fonts" / "SpaceGrotesk[wght].ttf")
ICON = ROOT / "sample_app" / "assets" / "icon" / "icon.png"


def render(text, size, out, weight=700, w=1080, h=None):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([weight])
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    bbox = probe.textbbox((0, 0), text, font=f)
    th = bbox[3] - bbox[1]
    h = h or th + 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tw = d.textlength(text, font=f)
    d.text(((w - tw) / 2, (h - th) / 2 - bbox[1]), text, font=f,
           fill=(255, 255, 255, 255))
    img.save(OUT / out)
    print("wrote", out)


def rounded_icon():
    img = Image.open(ICON).resize((360, 360)).convert("RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 359, 359], 80, fill=255)
    img.putalpha(mask)
    img.save(OUT / "intro_icon.png")
    print("wrote intro_icon.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    render("Thousands of free wallpapers", 58, "cap_explore.png")
    render("Set it in one tap", 58, "cap_detail.png")
    render("Backed up with your Google account", 52, "cap_saved.png")
    render("Quiet. Dark. Beautiful.", 58, "cap_dark.png")
    render("Wallify", 110, "wordmark.png")
    rounded_icon()
