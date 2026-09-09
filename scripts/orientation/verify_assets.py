"""Verify the shipped orientation catalog, complete MP3 decodes and exact text coverage.

Run: python scripts/orientation/verify_assets.py
Requires FFmpeg/FFprobe in PATH. Does not require synthesis services or source audio.
"""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'apps/soulbuddy/assets/orientation'
RETIRED = ('the garden must bear fruit', 'do not return the garden empty', 'do not leave the garden empty')

def normalized(text):
    return ''.join(c.lower() for c in text if c.isalnum())

def verify():
    catalog = json.loads((ASSETS / 'catalog.json').read_text(encoding='utf-8'))
    assert len(catalog) == 8
    assert len({c['id'] for c in catalog}) == 8
    results = []
    for course in catalog:
        cid = course['id']
        assert course['audioAsset'] == f'orientation/{cid}.mp3'
        assert course['transcriptAsset'] == f'assets/orientation/{cid}.json'
        audio = ASSETS / f'{cid}.mp3'
        transcript = json.loads((ASSETS / f'{cid}.json').read_text(encoding='utf-8'))
        for field in ('id', 'title', 'tenet', 'durationMs'):
            assert transcript[field] == course[field], (cid, field)
        text = transcript['text']
        assert not any(old in (text + ' ' + course['title']).lower() for old in RETIRED)
        duration = course['durationMs']
        for kind in ('words', 'sentences'):
            entries = transcript[kind]
            assert entries, (cid, kind)
            previous_end = 0
            previous_time = 0
            for entry in entries:
                a, b = entry['charStart'], entry['charEnd']
                assert 0 <= previous_end <= a < b <= len(text), (cid, kind, entry)
                assert not normalized(text[previous_end:a]), (cid, kind, text[previous_end:a])
                assert 0 <= previous_time <= entry['startMs'] < entry['endMs'] <= duration, (cid, kind, entry)
                previous_end = b
                previous_time = entry['startMs']
            assert not normalized(text[previous_end:]), (cid, kind)
            assert normalized(text) == normalized(''.join(text[e['charStart']:e['charEnd']] for e in entries)), (cid, kind)
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'json', str(audio)]))
        assert round(float(probe['format']['duration']) * 1000) == duration
        # Decode the entire stream; -xerror makes decoder errors fail verification.
        subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-i', str(audio), '-f', 'null', '-'], check=True, capture_output=True)
        results.append(dict(id=cid, durationMs=duration, words=len(transcript['words']), sentences=len(transcript['sentences']), fullAudioDecode=True, exactTextCoverage=True, timingBounds=True, sha256=hashlib.sha256(audio.read_bytes()).hexdigest()))
    assert 'continue from where you stopped' in json.loads((ASSETS / '00-welcome.json').read_text(encoding='utf-8'))['text']
    assert catalog[0]['title'] == 'Welcome — Aim for a plentiful harvest'
    full_audio = ASSETS / 'full-course.mp3'
    full = json.loads((ASSETS / 'full-course.json').read_text(encoding='utf-8'))
    assert full['timingSource'] == 'speech-engine-word-boundaries'
    assert not any(old in full['text'].lower() for old in RETIRED)
    assert 'Plant something good in the garden each day.' in full['text']
    assert 'Aim for a plentiful harvest.' in full['text']
    assert len(full['words']) > 1000
    assert full['words'][-1]['endMs'] <= full['durationMs']
    probe = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
        '-of', 'json', str(full_audio),
    ]))
    assert round(float(probe['format']['duration']) * 1000) == full['durationMs']
    subprocess.run(
        ['ffmpeg', '-v', 'error', '-xerror', '-i', str(full_audio), '-f', 'null', '-'],
        check=True,
        capture_output=True,
    )
    print(json.dumps(results, indent=2))
    return results

if __name__ == '__main__':
    verify()
