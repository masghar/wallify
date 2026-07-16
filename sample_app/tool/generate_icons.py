#!/usr/bin/env python3
"""Rasterize the launcher-icon SVG sources to the 1024x1024 PNGs that
flutter_launcher_icons consumes. Run from sample_app/:  python3 tool/generate_icons.py
On this Mac (conda python + Homebrew cairo) run with:
DYLD_LIBRARY_PATH=/opt/homebrew/lib python3 tool/generate_icons.py
— otherwise cairosvg can't dlopen libcairo.
cairosvg preserves alpha (the old qlmanage path flattened it)."""
import pathlib
import cairosvg

SRC = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icon"
JOBS = {
    "src/spectrum_icon.svg": "icon.png",
    "src/spectrum_background.svg": "icon_background.png",
    "src/spectrum_foreground.svg": "icon_foreground.png",
    "src/spectrum_monochrome.svg": "icon_monochrome.png",
    "src/spectrum_macos.svg": "icon_macos.png",
}

for src, out in JOBS.items():
    cairosvg.svg2png(url=str(SRC / src), write_to=str(SRC / out),
                     output_width=1024, output_height=1024)
    print(f"wrote {out}")
