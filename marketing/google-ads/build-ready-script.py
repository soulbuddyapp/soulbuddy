"""Bundle existing SoulBuddy image ads into installer and Preview-only diagnostic.

No network, credentials, new artwork or video uploads. Run with Python 3.10+ and
Pillow 10 or newer. JPEG conversion preserves the existing layout and exact dimensions.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
from PIL import Image

MARKER = 'const EMBEDDED_IMAGES = []; // @SOULBUDDY_IMAGES@'
PREVIEW_MARKER = 'const PREVIEW_CHECK_ONLY = false; // @SOULBUDDY_PREVIEW_CHECK@'
FORMATS = (('landscape', 1200, 628), ('square', 1200, 1200), ('portrait', 1200, 1500))


def build(source_root: Path, output: Path) -> None:
    source = (source_root / 'setup-google-ads.js').read_text(encoding='utf-8')
    if source.count(MARKER) != 1 or source.count(PREVIEW_MARKER) != 1:
        raise ValueError('Expected one image-bundle marker and one diagnostic-mode marker')
    images, manifest = [], []
    for shape, width, height in FORMATS:
        path = source_root / 'media' / 'export' / 'images' / f'01-transformation-{shape}-{width}x{height}.png'
        original = path.read_bytes()
        with Image.open(io.BytesIO(original)) as image:
            if image.format != 'PNG' or image.size != (width, height):
                raise ValueError(f'Unexpected source format/dimensions: {path.name}')
            encoded = io.BytesIO()
            image.convert('RGB').save(encoded, format='JPEG', quality=88, subsampling=0, optimize=True)
        data = encoded.getvalue()
        if len(data) > 5 * 1024 * 1024:
            raise ValueError(f'Image exceeds 5 MB: {path.name}')
        with Image.open(io.BytesIO(data)) as check:
            check.load()
            if check.size != (width, height) or check.mode != 'RGB':
                raise ValueError(f'JPEG round-trip failed: {path.name}')
        digest = hashlib.sha256(data).hexdigest()
        record = dict(name=f'SoulBuddy transformation {shape} {digest[:16]}',
                      width=width, height=height, bytes=len(data), sha256=digest)
        images.append({**record, 'data': base64.b64encode(data).decode('ascii')})
        manifest.append({**record, 'source': f'media/export/images/{path.name}',
                         'sourceSha256': hashlib.sha256(original).hexdigest()})
    bundled = source.replace(MARKER, 'const EMBEDDED_IMAGES = ' + json.dumps(images, separators=(',', ':')) + ';')
    if len(bundled.encode('utf-8')) > 1024 * 1024:
        raise ValueError('Bundle exceeds this project\'s conservative 1 MiB size limit')
    output.mkdir(parents=True, exist_ok=True)
    target = output / 'SoulBuddy-Ready-to-Run.js'
    target.write_text(bundled, encoding='utf-8', newline='\n')
    diagnostic = output / 'SoulBuddy-Preview-Check.js'
    diagnostic.write_text(bundled.replace(PREVIEW_MARKER,
        'const PREVIEW_CHECK_ONLY = true; // @SOULBUDDY_PREVIEW_CHECK@'), encoding='utf-8', newline='\n')
    summary = {'script': target.name, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
               'bytes': target.stat().st_size, 'imageCount': 3, 'uploadedVideoCount': 0, 'images': manifest,
               'diagnostic': {'script': diagnostic.name, 'previewOnly': True,
                              'sha256': hashlib.sha256(diagnostic.read_bytes()).hexdigest(),
                              'bytes': diagnostic.stat().st_size}}
    (output / 'manifest.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print(f'Built installer and Preview-only diagnostic: three embedded images each, zero video uploads')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    build(args.source_root, args.output or args.source_root / 'ready')


if __name__ == '__main__':
    main()
