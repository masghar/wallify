#!/usr/bin/env python3
"""Compose store screenshots, feature graphic, README hero, and the video
helper images from the raw captures. Run from repo root:
    python3 tool/marketing/frame_screenshots.py
"""
import pathlib
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
RAW = ROOT / "marketing" / "screenshots" / "raw"
STORE = ROOT / "marketing" / "screenshots" / "store"
GITHUB = ROOT / "marketing" / "github"
OUT = ROOT / "tool" / "marketing" / "out"
FONT = str(ROOT / "tool" / "marketing" / "fonts" / "SpaceGrotesk[wght].ttf")
ICON = ROOT / "sample_app" / "assets" / "icon" / "icon.png"

STOPS = [(0.00, (0x4A, 0x7D, 0xF5)), (0.33, (0x8B, 0x5C, 0xF0)),
         (0.66, (0xE8, 0x56, 0x7B)), (1.00, (0xFF, 0xA5, 0x3C))]

SHOTS = [  # (raw name, store filename, headline)
    ("explore",  "01_explore.png",  "Thousands of free wallpapers"),
    ("detail",   "02_detail.png",   "Set it in one tap"),
    ("saved",    "03_saved.png",    "Your library, everywhere"),
    ("settings", "04_settings.png", "Make it yours"),
    ("about",    "05_about.png",    "Quiet, dark, beautiful"),
]


def font(size, weight=700):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([weight])
    return f


def gradient(w, h):
    """Diagonal 4-stop gradient as a PIL image (project spectrum)."""
    x = np.linspace(0, 1, w)[None, :]
    y = np.linspace(0, 1, h)[:, None]
    t = np.clip((x + y) / 2, 0, 1)
    img = np.zeros((h, w, 3))
    for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
        m = (t >= t0) & (t <= t1)
        f = np.where(m, (t - t0) / (t1 - t0), 0)
        for ch in range(3):
            img[..., ch] += np.where(m, c0[ch] + (c1[ch] - c0[ch]) * f, 0)
    return Image.fromarray(img.astype("uint8"), "RGB")


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *img.size], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def phone_frame(shot, screen_w):
    """Screenshot inside a dark rounded bezel; returns RGBA."""
    screen_h = round(screen_w * shot.height / shot.width)
    screen = rounded(shot.resize((screen_w, screen_h)), radius=screen_w // 14)
    bezel = 14
    body = Image.new("RGBA",
                     (screen_w + 2 * bezel, screen_h + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle(
        [0, 0, body.width - 1, body.height - 1],
        radius=screen_w // 14 + bezel, fill=(14, 15, 19, 255))
    body.alpha_composite(screen, (bezel, bezel))
    return body


def drop_shadow(canvas, box_img, pos, blur=40, alpha=110):
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    solid = Image.new("RGBA", box_img.size, (0, 0, 0, alpha))
    solid.putalpha(box_img.split()[3].point(lambda a: alpha if a else 0))
    sh.alpha_composite(solid, (pos[0], pos[1] + 18))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))


def centered_text(draw, cx, y, text, f, fill=(255, 255, 255)):
    w = draw.textlength(text, font=f)
    draw.text((cx - w / 2, y), text, font=f, fill=fill)


def store_shot(raw_name, out_name, headline):
    canvas = gradient(1080, 1920).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    centered_text(d, 540, 120, headline, font(64))
    shot = Image.open(RAW / f"{raw_name}.png").convert("RGB")
    frame = phone_frame(shot, screen_w=760)
    pos = ((1080 - frame.width) // 2, 320)
    drop_shadow(canvas, frame, pos)
    canvas.alpha_composite(frame, pos)
    canvas.convert("RGB").save(STORE / out_name)
    print("wrote", out_name)


def feature_graphic():
    canvas = gradient(1024, 500).convert("RGBA")
    icon = rounded(Image.open(ICON).resize((300, 300)), 66)
    canvas.alpha_composite(icon, (90, 100))
    d = ImageDraw.Draw(canvas)
    # Tagline at size 40 measures 639px but only ~522px fit right of the
    # icon -- it clipped at the canvas edge. Size 32 measures 509px.
    d.text((460, 155), "Wallify", font=font(110))
    d.text((463, 300), "Free wallpapers, beautifully dark.", font=font(32, 500))
    canvas.convert("RGB").save(ROOT / "marketing" / "feature_graphic.png")
    print("wrote feature_graphic.png")


def hero():
    canvas = gradient(1280, 640).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    icon = rounded(Image.open(ICON).resize((88, 88)), 20)
    canvas.alpha_composite(icon, (70, 60))
    d.text((180, 66), "Wallify", font=font(64))
    d.text((72, 210), "Free wallpapers,", font=font(50, 500))
    d.text((72, 274), "beautifully dark.", font=font(50, 500))
    # Fan shifted right and slimmed vs the brief (x=600/810/1020, w=210):
    # the left phone's rotated bbox reached x~445 and overlapped the tagline
    # (which ended at x~502), and frame bottoms ran past y=640. At w=200 and
    # x=660/860/1055 all three rotated frames clear the text and sit fully
    # inside the canvas. Shadows added to match the store shots.
    for i, (name, angle, x) in enumerate(
            [("explore", -8, 660), ("detail", 0, 860), ("saved", 8, 1055)]):
        shot = Image.open(RAW / f"{name}.png").convert("RGB")
        frame = phone_frame(shot, screen_w=200).rotate(
            angle, expand=True, resample=Image.BICUBIC)
        pos = (x - frame.width // 2, 100 + (16 if i != 1 else 0))
        drop_shadow(canvas, frame, pos, blur=24, alpha=90)
        canvas.alpha_composite(frame, pos)
    canvas.convert("RGB").save(GITHUB / "hero.png")
    print("wrote hero.png")


def video_helpers():
    gradient(1080, 1920).save(OUT / "gradient_1080x1920.png")
    # Frame overlay: opaque gradient border + bezel with a transparent screen
    # window; ffmpeg overlays each recording UNDER this (window w=900).
    overlay = gradient(1080, 1920).convert("RGBA")
    w = 900
    h = 1560  # full aspect (w * 2400/1080 = 2000) is too tall; window is center-cropped
    x0, y0 = (1080 - w) // 2, (1920 - h) // 2
    d = ImageDraw.Draw(overlay)
    d.rounded_rectangle([x0 - 14, y0 - 14, x0 + w + 14, y0 + h + 14],
                        radius=78, fill=(14, 15, 19, 255))
    hole = Image.new("L", overlay.size, 255)
    ImageDraw.Draw(hole).rounded_rectangle([x0, y0, x0 + w, y0 + h],
                                           radius=64, fill=0)
    overlay.putalpha(hole)
    overlay.save(OUT / "phone_frame_overlay.png")
    # Outro card.
    outro = gradient(1080, 1920).convert("RGBA")
    icon = rounded(Image.open(ICON).resize((360, 360)), 80)
    outro.alpha_composite(icon, (360, 560))
    d = ImageDraw.Draw(outro)
    centered_text(d, 540, 1010, "Wallify", font(120))
    centered_text(d, 540, 1200, "canabyte.ca", font(48, 500))
    outro.convert("RGB").save(OUT / "outro.png")
    print("wrote video helpers")


if __name__ == "__main__":
    for p in (STORE, GITHUB, OUT):
        p.mkdir(parents=True, exist_ok=True)
    for raw_name, out_name, headline in SHOTS:
        store_shot(raw_name, out_name, headline)
    feature_graphic()
    hero()
    video_helpers()
