"""Validate public Commitment media. Diagnostics contain fixed IDs/reasons only."""
from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
from functools import lru_cache

ROOT = Path(__file__).resolve().parents[2]
IDS = {
    'readiness_v1', 'invitation_v1', 'guide_surrender_v1',
    'guide_direction_v1', 'guide_peace_v1', 'listening_v1',
    'spoken_invitation_v1', 'aphelion_excerpt_v1',
}
CREDIT = '“Aphelion” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au'
SOURCE = 'https://www.scottbuckley.com.au/library/wp-content/uploads/2026/04/Aphelion.mp3'
PAGE = 'https://www.scottbuckley.com.au/library/aphelion/'
COPIES = {
    'apps/soulbuddy/android/app/src/main/res/raw/commitment_invitation_v1.wav',
    'apps/soulbuddy/ios/Runner/Sounds/commitment_invitation_v1.wav',
}


def checksum(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_path(base: Path, value: object) -> Path:
    if not isinstance(value, str) or not value or '\\' in value:
        raise ValueError('path')
    rel = Path(value)
    if rel.is_absolute() or '..' in rel.parts or ':' in value:
        raise ValueError('path')
    result = (base / rel).resolve()
    if not result.is_relative_to(base.resolve()):
        raise ValueError('path')
    return result


def normalized_words(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", text.lower())


def approved_transcripts(root: Path) -> dict[str, str]:
    plan = (root / 'docs/superpowers/plans/2026-09-24-commitment-formation-journey.md').read_text(encoding='utf-8')
    block = plan.split('Use these canonical text constants in `catalog_v1.json`:')[1].split('```text')[1].split('```')[0]
    sections = {k: v.strip() for k, v in re.findall(r'^([A-Z ]+):\n(.+?)(?=\n\n[A-Z ]+:|\Z)', block.strip(), re.S | re.M)}
    common = sections['COMMON GUIDE OPENING'].removesuffix(' Now listen.')
    return {
        'readiness_v1': sections['READINESS'],
        'invitation_v1': sections['INVITATION'],
        'listening_v1': sections['LISTENING'],
        'spoken_invitation_v1': sections['SPOKEN INVITATION'],
        **{f'guide_{kind}_v1': common + ' ' + sections[kind.upper()] + ' Now listen.'
           for kind in ['surrender', 'direction', 'peace']},
    }


@lru_cache(maxsize=64)
def media_info(filename: str, modified: int, size: int) -> dict:
    del modified, size  # Included in the cache key to prevent stale file evidence.
    path = Path(filename)
    result = subprocess.run(
        ['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', filename],
        capture_output=True, text=True, check=True, timeout=30,
    )
    data = json.loads(result.stdout)
    stream = data['streams'][0]
    # Decoding every sample rejects damaged containers and disguised empty files.
    decoded = subprocess.run(
        ['ffmpeg', '-v', 'error', '-xerror', '-i', filename, '-f', 's16le',
         '-acodec', 'pcm_s16le', '-ac', '1', '-ar', '24000', '-'],
        capture_output=True, check=True, timeout=60,
    ).stdout
    samples = array.array('h', decoded)
    if sys.byteorder != 'little':
        samples.byteswap()
    if not samples:
        raise ValueError('decode')
    peak = max(abs(s) for s in samples) / 32768
    rms = math.sqrt(sum(s*s for s in samples) / len(samples)) / 32768
    active = sum(abs(s) > 100 for s in samples) / len(samples)
    return {
        'durationMs': round(float(data['format']['duration']) * 1000),
        'codec': stream['codec_name'], 'sampleRate': int(stream['sample_rate']),
        'channels': stream['channels'], 'peak': round(peak, 5),
        'rmsDbfs': round(20 * math.log10(max(rms, 1e-12)), 2),
        'activeFraction': round(active, 4),
    }


def verify_catalog(catalog: dict, root: Path) -> dict:
    errors: list[str] = []
    checked = []
    app = root / 'apps/soulbuddy'
    expected_transcripts = approved_transcripts(root)
    if catalog.get('schemaVersion') != 1 or catalog.get('captionTimebase') != 'sourceMediaMilliseconds':
        errors.append('catalog: schema')
    if catalog.get('defaultPlaybackRate') != 0.85:
        errors.append('catalog: playback rate')
    assets = catalog.get('assets', [])
    if not isinstance(assets, list):
        return {'ok': False, 'assets': [], 'errors': ['catalog: assets']}
    if len(assets) != len(IDS) or {a.get('id') for a in assets if isinstance(a, dict)} != IDS:
        errors.append('catalog: required IDs')
    for asset in assets:
        if not isinstance(asset, dict):
            errors.append('catalog: asset'); continue
        asset_id = asset.get('id')
        name = asset_id if asset_id in IDS else 'unknown_asset'

        def fail(reason):
            errors.append(f'{name}: {reason}')

        try:
            path = safe_path(app, asset.get('path'))
        except ValueError:
            fail('path'); continue
        if not path.is_file():
            fail('missing file'); continue
        digest = checksum(path)
        if digest != asset.get('sha256'):
            fail('checksum')
        try:
            stat = path.stat()
            info = media_info(str(path), stat.st_mtime_ns, stat.st_size)
        except (OSError, ValueError, KeyError, subprocess.SubprocessError):
            fail('decode'); continue
        music = name == 'aphelion_excerpt_v1'
        expected = ('mp3', 44100, 2) if music else ('pcm_s16le', 24000, 1)
        if (info['codec'], info['sampleRate'], info['channels']) != expected:
            fail('format')
        if asset.get('format') != ('mp3' if music else 'wav') or path.suffix != ('.mp3' if music else '.wav'):
            fail('format')
        if any(asset.get(key) != info[key] for key in ('codec', 'sampleRate', 'channels')):
            fail('format metadata')
        duration = asset.get('durationMs')
        bounds = asset.get('durationBoundsMs')
        if not isinstance(duration, int) or abs(info['durationMs'] - duration) > 50:
            fail('duration')
        if not isinstance(bounds, list) or len(bounds) != 2 or not bounds[0] <= info['durationMs'] <= bounds[1]:
            fail('duration bounds')
        if info['peak'] > 0.99 or info['rmsDbfs'] < -38 or info['activeFraction'] < 0.25:
            fail('signal')
        if name.startswith('guide_') or name == 'listening_v1':
            if not 60_000 <= info['durationMs'] / 0.85 <= 90_000:
                fail('guide duration')
        if name == 'invitation_v1' and info['durationMs'] / 0.85 > 41_000:
            fail('invitation duration')
        if name == 'spoken_invitation_v1' and info['durationMs'] >= 30_000:
            fail('notification duration')
        provenance = asset.get('provenance', {})
        license_info = asset.get('license', {})
        if not provenance.get('kind') or provenance.get('privateContent') is not False:
            fail('provenance')
        if not license_info.get('identifier') or not license_info.get('text'):
            fail('license')
        if asset.get('required') is not False or asset.get('fallback') != ('silent' if music else 'transcript'):
            fail('fallback')
        if music:
            if provenance.get('sourceIntervalSeconds') != [105, 135] or provenance.get('sourceInterval') != '00:01:45-00:02:15':
                fail('source interval')
            if provenance.get('sourceUrl') != SOURCE or provenance.get('sourcePage') != PAGE or provenance.get('sourceSha256') != '57ae03dbc122f0859e0f9a273e59503e34883728ddb5b06761fbf8244b0eb23e':
                fail('music source')
            if license_info.get('identifier') != 'CC-BY-4.0' or license_info.get('attribution') != CREDIT or license_info.get('url') != 'https://creativecommons.org/licenses/by/4.0/':
                fail('music license')
            if not 29950 <= info['durationMs'] <= 30100:
                fail('excerpt duration')
        else:
            transcript = asset.get('transcript', '')
            if transcript != expected_transcripts.get(name):
                fail('approved text')
            cues = asset.get('captions', [])
            if not transcript or not cues:
                fail('transcript')
            for field, sha_field in [('transcriptPath', 'transcriptSha256'), ('captionsPath', 'captionsSha256')]:
                try:
                    text_path = safe_path(app, asset.get(field))
                    if not text_path.is_file() or checksum(text_path) != asset.get(sha_field):
                        fail('transcript file')
                    elif field == 'transcriptPath' and text_path.read_text(encoding='utf-8').strip() != transcript:
                        fail('transcript content')
                except (ValueError, OSError):
                    fail('transcript path')
            previous_end = -1
            valid_cues = True
            for cue in cues:
                start, end = cue.get('startMs'), cue.get('endMs')
                if not isinstance(start, int) or not isinstance(end, int) or not 0 <= start < end <= info['durationMs'] or start < previous_end or not cue.get('text'):
                    valid_cues = False; break
                previous_end = end
            if not valid_cues:
                fail('captions')
            if normalized_words(' '.join(c.get('text', '') for c in cues)) != normalized_words(transcript):
                fail('caption coverage')
            if provenance.get('voice') != 'en-US-JennyNeural' or not provenance.get('captionTiming'):
                fail('voice provenance')
            if name.startswith('guide_'):
                if not transcript.startswith('Be still, and know that I am God.') or not transcript.endswith('Now listen.') or asset.get('scripture', {}).get('translation') != 'RSVCE':
                    fail('guide content')
            if name == 'spoken_invitation_v1':
                if transcript != 'This is a time to be with God, if you can. Open SoulBuddy when you are ready.':
                    fail('notification content')
                copies = asset.get('platformCopies', [])
                if set(copies) != COPIES:
                    fail('platform identity')
                for copy in copies:
                    try:
                        copy_path = safe_path(root, copy)
                        if not copy_path.is_file() or checksum(copy_path) != digest:
                            fail('platform identity')
                    except (ValueError, OSError):
                        fail('platform identity')
        checked.append({'id': name, 'sha256': digest, **info, 'transcript': not music,
                        **({'sourceIntervalSeconds': [105, 135]} if music else {})})
    return {'ok': not errors, 'assets': checked, 'errors': sorted(set(errors))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        catalog = json.loads((args.root / 'apps/soulbuddy/assets/audio/commitments/catalog_v1.json').read_text(encoding='utf-8'))
        result = verify_catalog(catalog, args.root)
    except (OSError, ValueError, TypeError, KeyError, AttributeError, IndexError):
        result = {'ok': False, 'assets': [], 'errors': ['catalog: invalid or unavailable']}
    print(json.dumps(result, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
