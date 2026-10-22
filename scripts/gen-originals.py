#!/usr/bin/env python3
"""Generates the wow.lol Originals: poster art and short looping clips.

Every pixel here is drawn from scratch (no photographs, no artist likenesses) —
the packs are typographic posters named after the artists, in a palette and
motif chosen per pack.  Each pack gets two clips:

  * a **parallax** cut, whose foreground plane drifts against a slightly
    oversized background — the PosteBoard video pipeline writes those planes
    with a layer scale and an off-centre position, which is what gives
    PosterKit's depth effect something to travel against (the "gyro" look);
  * an **animated** cut, where the motif itself moves — smoke, shimmer, scan.

Outputs, all relative to the repo root:

    Originals/Clips/<slug>-<variant>.mp4      1080x1920, 24 fps, 4 s loop
    Originals/Thumbs/<slug>-<variant>.jpg     540x960 first frame

Run with --probe to write a single PNG of each pack's still frame instead of
encoding the clips, which is how the art gets reviewed without waiting for
ffmpeg.
"""

from __future__ import annotations

import argparse
import math
import os
import subprocess
import sys
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIPS = os.path.join(ROOT, "Originals", "Clips")
THUMBS = os.path.join(ROOT, "Originals", "Thumbs")

W, H = 1080, 1920
FPS = 24
SECONDS = 3
FRAMES = FPS * SECONDS

FONT_DIR = r"C:\Windows\Fonts"
FONTS = {
    "impact": os.path.join(FONT_DIR, "impact.ttf"),
    "black": os.path.join(FONT_DIR, "ariblk.ttf"),
    "serif": os.path.join(FONT_DIR, "georgiab.ttf"),
    "mono": os.path.join(FONT_DIR, "consolab.ttf"),
}


def font(kind: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONTS[kind], size)


@dataclass
class Artist:
    slug: str
    name: str
    tag: str
    motif: str
    palette: tuple[str, str, str]
    variants: tuple[str, ...] = ("parallax", "animated")
    note: str = ""
    accent: str = "#FFFFFF"
    keywords: list[str] = field(default_factory=list)


ARTISTS: list[Artist] = [
    Artist(
        slug="2pac",
        name="2PAC",
        tag="THUG LIFE",
        motif="bandana",
        palette=("#14090B", "#5C1020", "#E23B3B"),
        accent="#F0C24B",
        note="crimson bandana field, smoke, gothic caps",
        keywords=["thug life", "west side"],
    ),
    Artist(
        slug="blamian",
        name="BLAMIAN",
        tag="NO SKIP",
        motif="chrome",
        palette=("#080A18", "#2A0E4A", "#22D3EE"),
        accent="#FF4FD8",
        note="liquid chrome wordmark over a neon grid",
        keywords=["chrome", "neon"],
    ),
    Artist(
        slug="biggie",
        name="BIG",
        tag="KING OF NEW YORK",
        motif="crown",
        palette=("#070C1C", "#122A63", "#C9A227"),
        accent="#F5D97A",
        note="royal blue velvet, gold crown geometry",
        keywords=["brooklyn", "gold"],
    ),
    Artist(
        slug="snoop",
        name="SNOOP",
        tag="DOGG POUND",
        motif="wire",
        palette=("#04120A", "#0E3B23", "#7BE495"),
        accent="#F3F7E9",
        note="lowrider wire-wheel mandala, drifting smoke",
        keywords=["west coast", "smoke"],
    ),
    Artist(
        slug="dre",
        name="DRE",
        tag="STILL D.R.E.",
        motif="arcs",
        palette=("#0A0A0C", "#1B1D22", "#E23B3B"),
        accent="#E8ECF2",
        note="graphite, chrome arcs, red sweep",
        keywords=["compton", "chrome"],
    ),
]

BY_SLUG = {artist.slug: artist for artist in ARTISTS}


# --------------------------------------------------------------------------
# helpers


def rgb(value: str) -> tuple[int, int, int]:
    """'#22D3EE' → (34, 211, 238)."""
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1: str, c2: str, t: float) -> tuple[int, int, int]:
    a = tuple(int(c1[i:i + 2], 16) for i in (1, 3, 5))
    b = tuple(int(c2[i:i + 2], 16) for i in (1, 3, 5))
    return tuple(int(round(lerp(a[i], b[i], t))) for i in range(3))


def radial(size, centre, radius, colour, strength=1.0):
    """A soft radial glow as an RGBA layer."""
    w, h = size
    y, x = np.mgrid[0:h, 0:w]
    d = np.sqrt((x - centre[0]) ** 2 + (y - centre[1]) ** 2) / max(radius, 1)
    alpha = np.clip(1.0 - d, 0, 1) ** 2 * 255 * strength
    layer = np.zeros((h, w, 4), dtype=np.uint8)
    layer[..., 0], layer[..., 1], layer[..., 2] = colour
    layer[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(layer, "RGBA")


def vertical_gradient(size, stops):
    """stops: [(t, "#rrggbb"), …] — soft vertical bands, no banding steps."""
    w, h = size
    y = np.linspace(0, 1, h)
    out = np.zeros((h, w, 3), dtype=np.float32)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        band = (y >= t0) & (y <= t1)
        if not band.any():
            continue
        f = (y[band] - t0) / max(t1 - t0, 1e-6)
        a = np.array([int(c0[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32)
        b = np.array([int(c1[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32)
        out[band] = (a[None, None, :] * (1 - f[:, None, None])
                     + b[None, None, :] * f[:, None, None])
    return Image.fromarray(out.astype(np.uint8), "RGB")


def grain(image: Image.Image, amount=8.0, seed=0) -> Image.Image:
    rng = np.random.default_rng(seed)
    arr = np.asarray(image.convert("RGB"), dtype=np.float32)
    noise = rng.normal(0, amount, arr.shape[:2])[..., None]
    return Image.fromarray(np.clip(arr + noise, 0, 255).astype(np.uint8), "RGB")


def vignette(image: Image.Image, strength=0.55) -> Image.Image:
    w, h = image.size
    y, x = np.mgrid[0:h, 0:w]
    d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    mask = np.clip(1.0 - (d / math.sqrt(2)) * 1.35, 0, 1) ** 1.6
    arr = np.asarray(image.convert("RGB"), dtype=np.float32)
    return Image.fromarray((arr * (1 - strength + strength * mask[..., None])).astype(np.uint8), "RGB")


def gradient_text(text, kind, size, colours, size_skew=1.0) -> Image.Image:
    """Text with a vertical gradient through it, trimmed to its own bounds."""
    f = font(kind, size)
    probe = Image.new("L", (8, 8))
    draw = ImageDraw.Draw(probe)
    box = draw.textbbox((0, 0), text, font=f)
    pad = int(size * 0.18) + 12
    w = box[2] - box[0] + pad * 2
    h = box[3] - box[1] + pad * 2
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((pad - box[0], pad - box[1]), text, font=f, fill=255)
    grad = vertical_gradient((w, h), [(i / (len(colours) - 1), c) for i, c in enumerate(colours)])
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    if size_skew != 1.0:
        out = out.resize((int(w * size_skew), h), Image.LANCZOS)
    return out


def paste_centre(canvas, layer, cy, cx=None, rotate=0.0):
    if rotate:
        layer = layer.rotate(rotate, expand=True, resample=Image.BICUBIC)
    w, h = layer.size
    x = int((canvas.width - w) / 2 if cx is None else cx - w / 2)
    y = int(cy - h / 2)
    canvas.alpha_composite(layer, (x, y))


# --------------------------------------------------------------------------
# motifs — each returns (background, foreground) where foreground is the plane
# that drifts for the parallax cut


def bandana_field(artist: Artist, phase: float) -> Image.Image:
    """Paisley-ish lattice, the one motif that reads as a bandana."""
    base = vertical_gradient((W, H), [(0, artist.palette[0]), (0.55, artist.palette[1]), (1, "#0B0507")])
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = 96
    drift = phase * step
    for j, y in enumerate(range(-step, H + step, step)):
        for i, x in enumerate(range(-step, W + step, step)):
            cx = x + (step // 2 if j % 2 else 0) + drift
            cy = y + math.sin(phase * 2 * math.pi + i * 0.3) * 4
            r = 20
            colour = (*mix(artist.palette[2], "#8A0F1F", 0.2 + 0.3 * ((i + j) % 3) / 2), 120)
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=colour)
            d.ellipse((cx - r * 1.8, cy - r * 1.8, cx + r * 1.8, cy + r * 1.8),
                      outline=(*mix(artist.palette[2], "#000000", 0.5), 70), width=3)
            d.arc((cx - r * 1.4, cy - r * 1.4, cx + r * 1.4, cy + r * 1.4),
                  200 + 40 * math.sin(phase * 6.28 + i), 320, fill=(*artist.accent_rgb, 90), width=3)
    base = Image.alpha_composite(base.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(0.4)))
    return base


def chrome_field(artist: Artist, phase: float) -> Image.Image:
    base = vertical_gradient((W, H), [(0, "#05060F"), (0.62, artist.palette[1]), (1, "#0B0713")])
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    horizon = int(H * 0.62)
    for i in range(-14, 15):
        x = W // 2 + i * 90 + math.sin(phase * 6.28 + i) * 10
        d.line([(W // 2 + i * 24, horizon), (x * 1.9 - W // 2, H)], fill=(*rgb(artist.palette[2]), 60), width=2)
    for k in range(9):
        t = (k / 9 + phase * 0.25) % 1
        y = int(horizon + (H - horizon) * (t ** 2))
        d.line([(0, y), (W, y)], fill=(*rgb(artist.palette[2]), int(110 * (1 - t))), width=2)
    glow = radial((W, H), (W // 2, horizon), W * 0.9, mix(artist.accent, "#1B0033", 0.55), 0.55)
    return Image.alpha_composite(Image.alpha_composite(base.convert("RGBA"), layer), glow)


def crown_field(artist: Artist, phase: float) -> Image.Image:
    base = vertical_gradient((W, H), [(0, "#050818"), (0.5, artist.palette[1]), (1, "#05070F")])
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = W // 2, int(H * 0.3)
    ring = 300 + 8 * math.sin(phase * 6.28)
    d.ellipse((cx - ring, cy - ring, cx + ring, cy + ring), outline=(*rgb(artist.palette[2]), 90), width=3)
    d.ellipse((cx - ring * 0.7, cy - ring * 0.7, cx + ring * 0.7, cy + ring * 0.7),
              outline=(*artist.accent_rgb, 60), width=2)
    # a crown of five spikes, geometric rather than pictorial
    base_y = cy + 120
    pts = []
    for i in range(11):
        a = math.pi * (1 + i / 10)
        r = 220 if i % 2 == 0 else 150
        pts.append((cx + math.cos(a) * r, base_y + math.sin(a) * r * 0.9))
    d.polygon(pts, fill=(*rgb(artist.palette[2]), 45), outline=(*artist.accent_rgb, 150))
    return Image.alpha_composite(base.convert("RGBA"), layer)


def wire_field(artist: Artist, phase: float) -> Image.Image:
    base = vertical_gradient((W, H), [(0, "#03100A"), (0.6, artist.palette[1]), (1, "#020A06")])
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = W // 2, int(H * 0.34)
    for r in range(60, 300, 26):
        tilt = phase * 6.28
        d.arc((cx - r, cy - r * 0.72, cx + r, cy + r * 0.72),
              int(math.degrees(tilt)) % 360, int(math.degrees(tilt)) % 360 + 250,
              fill=(*rgb(artist.palette[2]), 70), width=2)
    for k in range(24):
        a = phase * 6.28 + k * math.pi / 12
        d.line([(cx, cy), (cx + math.cos(a) * 300, cy + math.sin(a) * 300 * 0.72)],
               fill=(*artist.accent_rgb, 35), width=1)
    glow = radial((W, H), (cx, cy), W * 0.85, mix(artist.palette[2], "#02150C", 0.6), 0.5)
    return Image.alpha_composite(Image.alpha_composite(base.convert("RGBA"), layer), glow)


def arc_field(artist: Artist, phase: float) -> Image.Image:
    base = vertical_gradient((W, H), [(0, "#08080A"), (0.55, "#14161B"), (1, "#07070A")])
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = W // 2, int(H * 0.46)
    for k in range(7):
        r = 180 + k * 74
        start = (phase * 360 + k * 22) % 360
        d.arc((cx - r, cy - r, cx + r, cy + r), start, start + 120,
              fill=(*rgb(artist.palette[2]), 120 - k * 12), width=4)
        d.arc((cx - r, cy - r, cx + r, cy + r), start + 180, start + 250,
              fill=(*artist.accent_rgb, 60), width=2)
    sweep = radial((W, H), (cx, cy), W * 0.8, mix(artist.palette[2], "#000000", 0.62), 0.45)
    return Image.alpha_composite(Image.alpha_composite(base.convert("RGBA"), layer), sweep)


FIELDS = {
    "bandana": bandana_field,
    "chrome": chrome_field,
    "crown": crown_field,
    "wire": wire_field,
    "arcs": arc_field,
}


# --------------------------------------------------------------------------
# typography


def wordmark(artist: Artist) -> Image.Image:
    kind = {"bandana": "impact", "chrome": "black", "crown": "serif",
            "wire": "black", "arcs": "black"}[artist.motif]
    size = {"bandana": 250, "chrome": 168, "crown": 300, "wire": 190, "arcs": 320}[artist.motif]
    colours = {
        "bandana": ["#FFF2D8", artist.accent, artist.palette[2]],
        "chrome": ["#FFFFFF", "#D7E6F2", artist.accent],
        "crown": ["#FFF6CC", artist.accent, artist.palette[2]],
        "wire": ["#F4FFF8", artist.accent, "#1E6B3E"],
        "arcs": ["#FFFFFF", "#CDD3DC", artist.palette[2]],
    }[artist.motif]
    text = gradient_text(artist.name, kind, size, colours)
    # squeeze anything wider than the frame
    if text.width > W - 90:
        scale = (W - 90) / text.width
        text = text.resize((int(text.width * scale), int(text.height * scale)), Image.LANCZOS)
    return text


def tagline(artist: Artist) -> Image.Image:
    f = font("mono", 44)
    text = artist.tag
    probe = Image.new("L", (8, 8))
    box = ImageDraw.Draw(probe).textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0] + 80, box[3] - box[1] + 40
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 2,
                        fill=(*artist.accent_rgb, 34), outline=(*artist.accent_rgb, 120), width=2)
    d.text(((w - (box[2] - box[0])) / 2, (h - (box[3] - box[1])) / 2 - box[1]), text,
           font=f, fill=(*artist.accent_rgb, 235))
    return layer


# --------------------------------------------------------------------------
# frame assembly


def setup(artist: Artist):
    artist.accent_rgb = tuple(int(artist.accent[i:i + 2], 16) for i in (1, 3, 5))
    return artist


def decor(canvas: Image.Image, artist: Artist, phase: float) -> Image.Image:
    """The poster furniture: a dashed badge, halftone, a frame, editorial marks.

    These are what stop a wallpaper from reading as a gradient with a word on
    it.  They sit behind the type, so the mark stays legible on top of them.
    """
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = W // 2, int(H * 0.44)

    # dashed badge ring, rotating once per loop
    for k in range(48):
        a0 = (k / 48) * 360 + phase * 360 * (1 if artist.motif in ("arcs", "wire") else 0.35)
        if k % 2:
            continue
        d.arc((cx - 400, cy - 400, cx + 400, cy + 400), a0, a0 + 3.4,
              fill=(*artist.accent_rgb, 70), width=3)
    d.ellipse((cx - 452, cy - 452, cx + 452, cy + 452),
              outline=(*artist.accent_rgb, 40), width=2)

    # halftone patch in the upper third, fading out
    rng = np.random.default_rng(hash(artist.slug) % 999)
    for j, y in enumerate(range(120, 900, 34)):
        for x in range(40, W - 40, 34):
            r = 2.6 * (1 - (y - 120) / 900) + rng.uniform(0, 0.9)
            if (x // 34 + j) % 3 == 0:
                continue
            d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 26))
    layer = layer.filter(ImageFilter.GaussianBlur(0.6))
    canvas = Image.alpha_composite(canvas, layer)

    # inner frame, the way a printed sleeve has one
    frame = ImageDraw.Draw(canvas)
    inset = 54
    frame.rounded_rectangle((inset, inset, W - inset, H - inset), radius=38,
                            outline=(*artist.accent_rgb, 55), width=3)

    # editorial furniture: pack number, vertical side label, edition line
    small = font("mono", 26)
    index = [a.slug for a in ARTISTS].index(artist.slug) + 1
    frame.text((inset + 42, inset + 34), f"WOW.LOL ORIGINALS  ·  {index:02d}", font=small,
               fill=(255, 255, 255, 140))
    side = font("mono", 22)
    label = "   ".join(artist.tag.upper())
    strip = Image.new("RGBA", (len(label) * 15 + 40, 40), (0, 0, 0, 0))
    ImageDraw.Draw(strip).text((10, 8), label, font=side, fill=(*artist.accent_rgb, 150))
    strip = strip.rotate(90, expand=True)
    canvas.alpha_composite(strip, (W - inset - strip.width - 6, int(H * 0.5) - strip.height // 2))
    return canvas


def frame(artist: Artist, variant: str, t: float) -> Image.Image:
    """One frame. `t` is 0..1 through the loop; the loop must close seamlessly."""
    phase = t
    field_fn = FIELDS[artist.motif]
    back = field_fn(artist, phase)

    # Oversized background plane + a foreground plane that drifts against it: the
    # two planes are what the caml writer turns into depth travel.
    zoom = 1.10 if variant == "parallax" else 1.04
    back = back.resize((int(W * zoom), int(H * zoom)), Image.LANCZOS)
    dx = int(math.sin(phase * 2 * math.pi) * 18)
    dy = int(math.cos(phase * 2 * math.pi) * 14)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    canvas.paste(back, (int((W - back.width) / 2) + dx, int((H - back.height) / 2) + dy))

    # smoke / dust: a handful of translucent blobs on their own slow orbits
    smoke = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rng = np.random.default_rng(int(hash(artist.slug) % 997) + 7)
    for k in range(4 if artist.motif in ("bandana", "wire") else 3):
        base_x = rng.uniform(0.1, 0.9) * W
        base_y = rng.uniform(0.15, 0.85) * H
        rad = rng.uniform(180, 340)
        a = phase * 2 * math.pi + k
        blob = radial((W, H), (base_x + math.sin(a) * 60, base_y - (phase * H * 0.12)),
                      rad, mix(artist.accent, "#000000", 0.30),
                      0.20 if variant == "animated" else 0.11)
        smoke = Image.alpha_composite(smoke, blob)
    canvas = Image.alpha_composite(canvas, smoke.filter(ImageFilter.GaussianBlur(24)))

    canvas = decor(canvas, artist, phase)

    # the type, on the drifting foreground plane
    mark = wordmark(artist)
    fg_dx = int(-dx * 1.6) if variant == "parallax" else 0
    fg_dy = int(-dy * 1.2) if variant == "parallax" else 0
    lift = int(math.sin(phase * 2 * math.pi) * 6)
    paste_centre(canvas, mark, H * 0.46 + fg_dy + lift, W / 2 + fg_dx)

    tag = tagline(artist)
    paste_centre(canvas, tag, H * 0.46 + mark.height * 0.62 + 60 + fg_dy)

    # a hairline rule under the tagline and the pack's own mark
    d = ImageDraw.Draw(canvas)
    rule_y = int(H * 0.46 + mark.height * 0.62 + 130)
    d.line([(W * 0.18, rule_y), (W * 0.82, rule_y)], fill=(*artist.accent_rgb, 60), width=2)
    small = font("mono", 27)
    caption = artist.note.upper()
    box = d.textbbox((0, 0), caption, font=small)
    if box[2] - box[0] < W - 200:
        d.text(((W - (box[2] - box[0])) / 2, rule_y + 32), caption, font=small,
               fill=(255, 255, 255, 120))

    if variant == "animated":
        # a sweep of light across the frame, once per loop
        sweep_x = int(lerp(-300, W + 300, phase))
        beam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(beam).polygon(
            [(sweep_x, 0), (sweep_x + 220, 0), (sweep_x - 160, H), (sweep_x - 380, H)],
            fill=(*artist.accent_rgb, 26))
        canvas = Image.alpha_composite(canvas, beam.filter(ImageFilter.GaussianBlur(40)))

    canvas = vignette(canvas.convert("RGB"), 0.5)
    return grain(canvas, 2.6, seed=int(t * 1000)).convert("RGB")


# --------------------------------------------------------------------------
# encoding


def encode(artist: Artist, variant: str) -> tuple[str, str]:
    os.makedirs(CLIPS, exist_ok=True)
    os.makedirs(THUMBS, exist_ok=True)
    slug = f"{artist.slug}-{variant}"
    mp4 = os.path.join(CLIPS, slug + ".mp4")
    jpg = os.path.join(THUMBS, slug + ".jpg")

    first = frame(artist, variant, 0.0)
    first.resize((540, 960), Image.LANCZOS).save(jpg, quality=82, optimize=True)

    import imageio_ffmpeg
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    cmd = [
        ffmpeg, "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24",
        "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-an", "-c:v", "libx264", "-preset", "faster", "-crf", "26",
        "-pix_fmt", "yuv420p", "-profile:v", "high", "-level", "4.2",
        "-movflags", "+faststart", mp4,
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    try:
        for i in range(FRAMES):
            # the last frame is not a duplicate of the first, so the loop closes
            # on a step rather than a stutter
            img = frame(artist, variant, i / FRAMES)
            proc.stdin.write(img.tobytes())
    finally:
        proc.stdin.close()
        if proc.wait() != 0:
            raise SystemExit(f"ffmpeg failed for {slug}")
    size = os.path.getsize(mp4)
    print(f"{slug:24s} {size / 1e6:5.1f} MB  {frames_duration()}")
    return mp4, jpg


def frames_duration() -> str:
    return f"{SECONDS}s @ {FPS}fps"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe", metavar="DIR", nargs="?", const="Originals/Probe",
                        help="write one still per pack instead of encoding")
    parser.add_argument("--only", help="comma-separated slugs")
    args = parser.parse_args()

    wanted = args.only.split(",") if args.only else [a.slug for a in ARTISTS]

    if args.probe:
        out = args.probe if os.path.isabs(args.probe) else os.path.join(ROOT, args.probe)
        os.makedirs(out, exist_ok=True)
        for artist in ARTISTS:
            if artist.slug not in wanted:
                continue
            setup(artist)
            for variant in artist.variants:
                img = frame(artist, variant, 0.18)
                img.resize((540, 960), Image.LANCZOS).save(
                    os.path.join(out, f"{artist.slug}-{variant}.jpg"), quality=86)
            print("probed", artist.slug)
        return 0

    for artist in ARTISTS:
        if artist.slug not in wanted:
            continue
        setup(artist)
        for variant in artist.variants:
            encode(artist, variant)
    print("done —", FRAMES, "frames per clip")
    return 0


if __name__ == "__main__":
    sys.exit(main())
