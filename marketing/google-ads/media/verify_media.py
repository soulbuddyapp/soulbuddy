#!/usr/bin/env python3
"""Independently verify exports, checksums and unchanged screenshot pixels."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageChops


def verify(root: Path, sources: Path):
    data = json.loads((root / 'manifest.json').read_text())
    assets = data['assets']
    if len(assets) != 12 or len({a['file'] for a in assets}) != 12:
        raise ValueError('Expected exactly nine distinct PNGs and three MP4s')
    for record in assets:
        p = root / record['file']
        raw = p.read_bytes()
        assert len(raw) == record['bytes'], p
        assert hashlib.sha256(raw).hexdigest() == record['sha256'], p
        if p.suffix == '.png':
            with Image.open(p) as im:
                assert im.mode == 'RGB' and im.size == (record['width'], record['height']), p
                assert len(raw) < 5_000_000, p
        else:
            report = json.loads(subprocess.check_output([
                'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(p)
            ], text=True))
            assert len(report['streams']) == 1, 'Silent by design: video stream only'
            s = report['streams'][0]
            assert s['codec_name'] == 'h264' and s['pix_fmt'] == 'yuv420p', p
            assert (s['width'], s['height']) == (record['width'], record['height']), p
            assert s['r_frame_rate'] == '30/1' and abs(float(report['format']['duration'])-20) < .05, p
    # Compare every foreground screenshot pixel in both headline treatments.
    positions = {'landscape': (842,48,282,1200,628), 'square': (676,192,436,1200,1200),
                 'portrait': (686,550,420,1200,1500)}
    for theme, source in [('01-transformation','today-device.png'), ('02-daily-habits','orientation-device.png')]:
        p = sources / source
        if not p.is_file():
            p = sources / 'sources' / source
        original = Image.open(p).convert('RGB').crop((0,158,1280,2663))
        for kind, (x,y,w,cw,ch) in positions.items():
            h = round(w * original.height / original.width)
            exported = Image.open(root / f'images/{theme}-{kind}-{cw}x{ch}.png')
            expected = original.resize((w,h), Image.Resampling.LANCZOS)
            assert ImageChops.difference(exported.crop((x,y,x+w,y+h)), expected).getbbox() is None
    print('PASS: 12 media exports; dimensions, codecs, duration, file hashes and six unchanged screenshot regions.')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Usage: verify_media.py OUTPUT SOURCE_ROOT')
    verify(Path(sys.argv[1]), Path(sys.argv[2]))
