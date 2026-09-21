#!/usr/bin/env python3
"""Typeset approved SoulBuddy artwork and unmodified device captures for ads.

Requires Python 3.10+, Pillow, FFmpeg, fontconfig, P052 and Inter system fonts.
No network requests, generative artwork, font redistribution or Ads mutations.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import subprocess
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

FORMATS = {"landscape": (1200, 628), "square": (1200, 1200), "portrait": (1200, 1500)}
VIDEOS = {"landscape": (1920, 1080), "square": (1080, 1080), "vertical": (1080, 1920)}
GREEN = (21, 57, 45)
CREAM = (248, 240, 222)
GOLD = (205, 174, 108)
DARK = (24, 57, 46)
SOURCE_GIT_SHA = {
    "today-device.png": "fd5a172d361e4b0290650d0bdb1f00aa4173e5dd",
    "orientation-device.png": "0fe5f270565ada554db1e41bd68649e3e666b982",
    "soulbuddy-icon-1024.png": "4ac87f5fca35b086317fda986656244e7cfab047",
}


def run(args: list[str], timeout: int = 240) -> str:
    try:
        p = subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           text=True, timeout=timeout)
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"{args[0]} failed: {exc.stderr[-6000:]}") from exc
    return p.stdout


@lru_cache(maxsize=8)
def font_path(family: str) -> str:
    result = run(["fc-match", "-f", "%{family}|%{file}", family])
    name, path = result.split("|", 1)
    if family.lower() not in name.lower() or not Path(path).is_file():
        raise RuntimeError(f"Install the {family} font family. Font files are not bundled.")
    return path


@lru_cache(maxsize=96)
def font(family: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(font_path(family), size)


class Renderer:
    def __init__(self, sources: Path, output: Path):
        self.sources, self.output = sources, output
        self.images: dict[str, Image.Image] = {}
        self.records: list[dict] = []
        for name in [*SOURCE_GIT_SHA, "ascent.jpg", "renewal.jpg", "scripture.jpg"]:
            candidates = [sources / name, sources / "sources" / name,
                          sources / "brand" / name, sources / "visuals" / name]
            p = next((p for p in candidates if p.is_file()), None)
            if p is None:
                raise FileNotFoundError(f"Missing approved source: {name}")
            data = p.read_bytes()
            if name in SOURCE_GIT_SHA:
                actual = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
                if actual != SOURCE_GIT_SHA[name]:
                    raise ValueError(f"Source {name} changed; re-review crops and update provenance.")
            self.images[name] = Image.open(p).convert("RGB")
        for name in ("today-device.png", "orientation-device.png"):
            if self.images[name].size != (1280, 2800):
                raise ValueError("Unexpected device capture dimensions")
            # Same system-bar-only crop as the reviewed store-assets build.
            self.images[name] = self.images[name].crop((0, 158, 1280, 2663))
        output.mkdir(parents=True, exist_ok=True)

    @staticmethod
    def background(w: int, h: int, light: bool = False) -> Image.Image:
        base = (249, 242, 228) if light else GREEN
        glow = (224, 213, 185) if light else (57, 81, 54)
        small = Image.new("RGB", (240, 240))
        pix = small.load()
        for y in range(240):
            for x in range(240):
                d = math.hypot((x - 205) / 220, (y - 125) / 190)
                a = max(0, 1 - d) ** 1.4 * 0.6
                pix[x, y] = tuple(round(base[i] * (1-a) + glow[i] * a) for i in range(3))
        return small.resize((w, h), Image.Resampling.BICUBIC)

    @staticmethod
    def text(im: Image.Image, lines: list[str], x: int, y: int, size: int,
             width: int, color=CREAM, serif=True, leading=1.10) -> int:
        family = "P052" if serif else "Inter"
        d = ImageDraw.Draw(im)
        while size >= 14:
            f = font(family, size)
            if all(d.textlength(s, font=f) <= width for s in lines):
                break
            size -= 1
        else:
            raise ValueError("Text cannot fit")
        for line in lines:
            bounds = d.textbbox((x, y), line, font=f, anchor="lt")
            if bounds[0] < 0 or bounds[2] > im.width or bounds[3] > im.height:
                raise ValueError(f"Text outside canvas: {line}")
            d.text((x, y), line, font=f, fill=color, anchor="lt")
            y += round(size * leading)
        return y

    def brand(self, im: Image.Image, x: int, y: int, size=62, light=False):
        icon = self.images["soulbuddy-icon-1024.png"].resize((size, size), Image.Resampling.LANCZOS)
        # Preserve the exact existing icon artwork; do not draw a substitute.
        im.paste(icon, (x, y))
        self.text(im, ["SoulBuddy"], x+size+18, y+round(size*.16), round(size*.60),
                  450, DARK if light else CREAM)

    def screen(self, im: Image.Image, name: str, x: int, y: int, width: int):
        src = self.images[name]
        height = round(width * src.height / src.width)
        if x < 0 or y < 0 or x+width > im.width or y+height > im.height:
            raise ValueError(f"Screenshot is outside canvas: {name}")
        layer = Image.new("RGBA", im.size)
        d = ImageDraw.Draw(layer)
        d.rounded_rectangle((x-9, y+7, x+width+9, y+height+19), radius=18, fill=(0, 15, 9, 90))
        im.paste(Image.alpha_composite(im.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(16))).convert("RGB"))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((x-3, y-3, x+width+3, y+height+3), radius=9, fill=(205, 190, 157))
        # Uniformly scaled capture, no invented controls, text or progress.
        im.paste(src.resize((width, height), Image.Resampling.LANCZOS), (x, y))
        return height

    def art(self, im: Image.Image, name: str, box: tuple[int, int, int, int]):
        x, y, w, h = box
        piece = ImageOps.fit(self.images[name], (w, h), method=Image.Resampling.LANCZOS,
                             centering=(0.5, 0.35))
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w-1, h-1), radius=min(w//2, 130), fill=255)
        im.paste(piece, (x, y), mask)

    def footer(self, im: Image.Image, y: int, light=False, text="PRAYER  ·  SCRIPTURE  ·  PRACTICE"):
        d = ImageDraw.Draw(im)
        d.line((72, y, 1128, y), fill=(163, 145, 109) if light else (73, 95, 69), width=1)
        self.text(im, [text], 74, y+19, 18, 1048,
                  (91, 100, 78) if light else GOLD, serif=False)

    def image_ad(self, theme: str, kind: str) -> Image.Image:
        w, h = FORMATS[kind]
        light = theme == "02-daily-habits"
        clean = theme == "03-app-first"
        im = self.background(w, h, light)
        fg = DARK if light else CREAM
        subtle = (84, 101, 87) if light else (216, 222, 200)
        self.brand(im, 72, 58, 62, light)
        screen = "orientation-device.png" if light else "today-device.png"
        if kind == "landscape":
            if clean:
                self.art(im, "ascent.jpg", (72, 160, 455, 380))
                self.screen(im, "orientation-device.png", 665, 105, 225)
                self.screen(im, "today-device.png", 854, 48, 270)
            else:
                lines = ["Build faithful", "daily habits."] if light else ["Let Christ reshape", "your life."]
                self.text(im, lines, 72, 190, 68, 710, fg)
                body = ["Prayer, Scripture and reflection."] if light else ["One faithful habit at a time."]
                self.text(im, body, 76, 373, 28, 680, subtle, serif=False)
                self.screen(im, screen, 842, 48, 282)
                self.text(im, ["A CHRISTIAN PRAYER & JOURNAL APP"], 77, 528, 16, 700,
                          (133, 101, 44) if light else GOLD, serif=False)
        elif kind == "square":
            if clean:
                self.art(im, "ascent.jpg", (76, 192, 348, 743))
                self.screen(im, "orientation-device.png", 469, 305, 344)
                self.screen(im, "today-device.png", 711, 193, 404)
            else:
                lines = ["Build faithful", "daily habits."] if light else ["Let Christ", "reshape", "your life."]
                end = self.text(im, lines, 74, 310, 78, 528, fg, leading=1.13)
                body = ["Prayer. Scripture.", "A daily practice."] if light else ["Prayer. Scripture.", "One faithful step."]
                self.text(im, body, 79, end+46, 30, 508, subtle, serif=False, leading=1.45)
                self.screen(im, screen, 676, 192, 436)
            if not clean:
                self.footer(im, 1080, light)
        else:
            if clean:
                self.art(im, "ascent.jpg", (75, 228, 489, 960))
                self.screen(im, "orientation-device.png", 593, 367, 385)
                self.screen(im, "today-device.png", 710, 258, 405)
            else:
                lines = ["Build faithful", "daily habits."] if light else ["Let Christ reshape", "your life."]
                self.text(im, lines, 76, 220, 88, 1040, fg, leading=1.09)
                body = "Prayer, Scripture and reflection." if light else "One faithful habit at a time."
                self.text(im, [body], 81, 454, 30, 1030, subtle, serif=False)
                if light:
                    self.art(im, "renewal.jpg", (77, 720, 468, 480))
                else:
                    self.art(im, "ascent.jpg", (77, 618, 468, 696))
                self.screen(im, screen, 686, 550, 420)
        return im

    def save_image(self, im: Image.Image, rel: str, **meta):
        p = self.output / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        im.convert("RGB").save(p, optimize=True, compress_level=9)
        with Image.open(p) as exported:
            if exported.mode != "RGB" or exported.size != im.size:
                raise ValueError(f"Invalid export: {rel}")
        size = p.stat().st_size
        if size >= 5_000_000:
            raise ValueError(f"Image exceeds 5 MB: {rel}")
        self.records.append({"file": rel, "width": im.width, "height": im.height,
                             "bytes": size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest(), **meta})

    def video_frame(self, scene: int, kind: str) -> Image.Image:
        # Render composition in reference units then uniformly scale to video size.
        target = VIDEOS[kind]
        horizontal = kind == "landscape"
        vertical = kind == "vertical"
        w, h = (1920, 1080) if horizontal else ((1080, 1920) if vertical else (1080, 1080))
        im = self.background(w, h)
        self.brand(im, 108 if horizontal else 84, 86 if horizontal else 170 if vertical else 64,
                   74 if horizontal else 64)
        copy = [
            (["Let Christ", "reshape your life."], ["One faithful habit at a time."]),
            (["Begin with one", "faithful habit."], ["Prayer. Scripture. Reflection."]),
            (["Let truth shape", "your choices."], ["Listen. Reflect. Put faith into practice."]),
            (["Your next", "faithful step."], ["Get SoulBuddy on Google Play."]),
        ]
        lines, sub = copy[scene]
        source = "orientation-device.png" if scene == 2 else "today-device.png"
        if horizontal:
            self.text(im, lines, 110, 320, 105, 1055, leading=1.16)
            self.text(im, sub, 115, 622, 38, 1000, (219, 226, 206), serif=False)
            if scene == 0:
                self.art(im, "ascent.jpg", (1310, 115, 470, 850))
            else:
                self.screen(im, source, 1342, 116, 422)
            self.text(im, ["PRAYER  ·  SCRIPTURE  ·  PRACTICE"], 117, 910, 26, 1100, GOLD, serif=False)
        elif vertical:
            self.text(im, lines, 88, 366, 83, 900, leading=1.10)
            self.text(im, sub, 91, 596, 32, 900, (219, 226, 206), serif=False)
            if scene == 0:
                self.art(im, "ascent.jpg", (190, 766, 670, 888))
            else:
                self.screen(im, source, 300, 764, 460)
        else:
            self.text(im, lines, 77, 319, 70, 536, leading=1.12)
            self.text(im, sub, 82, 544, 25, 525, (219, 226, 206), serif=False)
            if scene == 0:
                self.art(im, "ascent.jpg", (662, 198, 346, 721))
            else:
                self.screen(im, source, 649, 190, 352)
        return im.resize(target, Image.Resampling.LANCZOS)

    def build_images(self):
        for theme in ("01-transformation", "02-daily-habits", "03-app-first"):
            for kind in FORMATS:
                im = self.image_ad(theme, kind)
                self.save_image(im, f"images/{theme}-{kind}-{im.width}x{im.height}.png",
                                concept=theme, recommended_first=theme == "01-transformation")

    def build_videos(self):
        if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
            raise RuntimeError("Install FFmpeg and ffprobe to export video")
        for kind, (w, h) in VIDEOS.items():
            work = self.output / "video-frames" / kind
            work.mkdir(parents=True, exist_ok=True)
            for scene in range(4):
                self.video_frame(scene, kind).save(work / f"{scene}.png")
            args = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-filter_complex_threads", "1"]
            for scene, duration in enumerate((5.5, 5.5, 5.5, 5.0)):
                args += ["-loop", "1", "-framerate", "30", "-t", str(duration), "-i", str(work / f"{scene}.png")]
            filters = ";".join([f"[{i}:v]format=yuv420p,settb=1/30,setpts=PTS-STARTPTS,fps=30[v{i}]" for i in range(4)])
            filters += ";[v0][v1]xfade=transition=fade:duration=0.5:offset=5,fps=30[x1]"
            filters += ";[x1][v2]xfade=transition=fade:duration=0.5:offset=10,fps=30[x2]"
            filters += ";[x2][v3]xfade=transition=fade:duration=0.5:offset=15,fps=30[out]"
            p = self.output / f"videos/soulbuddy-faithful-habits-{kind}-{w}x{h}-20s.mp4"
            p.parent.mkdir(parents=True, exist_ok=True)
            args += ["-filter_complex", filters, "-map", "[out]", "-an", "-c:v", "libx264", "-preset", "medium",
                     "-crf", "19", "-pix_fmt", "yuv420p", "-r", "30", "-t", "20", "-threads", "2",
                     "-movflags", "+faststart", str(p)]
            run(args, timeout=360)
            report = json.loads(run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(p)]))
            stream = report["streams"][0]
            if (stream["width"], stream["height"]) != (w, h) or stream["codec_name"] != "h264":
                raise ValueError("Video export mismatch")
            if abs(float(report["format"]["duration"])-20) > .05:
                raise ValueError("Video duration mismatch")
            self.records.append({"file": str(p.relative_to(self.output)), "width": w, "height": h,
                                 "duration_seconds": 20, "fps": 30, "audio": False, "codec": "h264",
                                 "bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()})
            print(f"Exported {p.name}", flush=True)

    def preview(self):
        board = Image.new("RGB", (1560, 1900), (236, 234, 226))
        self.text(board, ["SoulBuddy / Google Ads media"], 48, 32, 36, 1450, DARK)
        for row, theme in enumerate(("01-transformation", "02-daily-habits", "03-app-first")):
            for col, kind in enumerate(("landscape", "square", "portrait")):
                w, h = FORMATS[kind]
                p = self.output / f"images/{theme}-{kind}-{w}x{h}.png"
                im = ImageOps.contain(Image.open(p), (472, 490), Image.Resampling.LANCZOS)
                x, y = 40+col*510, 106+row*580
                board.paste(im, (x, y))
                self.text(board, [f"{theme} / {kind}"], x, y+512, 16, 474, DARK, serif=False)
        board.save(self.output / "preview.jpg", quality=92)
        for kind in VIDEOS:
            work = self.output / "video-frames" / kind
            if not work.is_dir():
                continue
            proof = Image.new("RGB", (1560, 720), (236, 234, 226))
            for scene in range(4):
                im = ImageOps.contain(Image.open(work / f"{scene}.png"), (366, 624), Image.Resampling.LANCZOS)
                proof.paste(im, (16+scene*390, 30))
                self.text(proof, [f"{scene*5:02d}s - {(scene+1)*5:02d}s"], 22+scene*390, 673, 20, 355, DARK, serif=False)
            proof.save(self.output / f"storyboard-{kind}.jpg", quality=92)

    def manifest(self):
        data = {"source_capture_date": "2026-09-09", "prepared": "2026-09-17",
                "source_git_blob_sha1": SOURCE_GIT_SHA,
                "device_crop": {"left": 0, "top": 158, "width": 1280, "height": 2505},
                "video_type": "Sound-off motion ad from actual still captures, not a live screen recording",
                "assets": self.records}
        (self.output / "manifest.json").write_text(json.dumps(data, indent=2)+"\n")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--sources", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--images-only", action="store_true")
    args = p.parse_args()
    r = Renderer(args.sources, args.output)
    r.build_images()
    if not args.images_only:
        r.build_videos()
    r.preview()
    r.manifest()
    print(f"Validated {len(r.records)} exported assets")


if __name__ == "__main__":
    main()
