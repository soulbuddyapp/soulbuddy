"""Verify licensed meditation recordings, provenance, levels and repeat boundaries.

Requires Python 3, NumPy, FFmpeg and FFprobe. Does not download or modify files.
The pinned asset hashes establish provenance; signal tests alone cannot prove
authorship or whether an instrument was recorded acoustically.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'apps/soulbuddy/assets/audio/meditation'
LICENSE_URL = 'https://creativecommons.org/licenses/by/4.0/'
RECORDINGS = {
    'hopeful_piano.mp3': ('Resolutions', 'resolutions', '2022/01/Resolutions.mp3'),
    'cinematic_rise.mp3': ('Aurora', 'aurora', '2021/10/Aurora.mp3'),
    'steady_resolve.mp3': ('Affirmations', 'affirmations', '2021/06/sb_affirmations.mp3'),
    'warm_strings.mp3': ('First Snow', 'first-snow', '2022/12/FirstSnow.mp3'),
    'victorious_calm.mp3': ('A Kind Of Hope', 'a-kind-of-hope', '2022/10/AKindOfHope.mp3'),
}


def load_manifest() -> list[dict]:
    text = (ASSETS / 'ASSETS.md').read_text(encoding='utf-8')
    return json.loads(text.split('<!-- licensed-music-manifest -->')[1].split('```json')[1].split('```')[0])


def validate_manifest(rows: list[dict]) -> None:
    if len(rows) != 5 or {row['file'] for row in rows} != set(RECORDINGS):
        raise ValueError('five curated recordings required')
    for row in rows:
        title, slug, download = RECORDINGS[row['file']]
        required = {
            'title': title, 'artist': 'Scott Buckley', 'license': 'CC BY 4.0',
            'license_url': LICENSE_URL,
            'source_page': 'https://www.scottbuckley.com.au/library/' + slug + '/',
            'source_url': 'https://www.scottbuckley.com.au/library/wp-content/uploads/' + download,
            'credit': f'“{title}” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au',
        }
        if any(row.get(key) != value for key, value in required.items()):
            raise ValueError('official source, attribution and license required')
        if not row.get('changes') or not row.get('retrieved'):
            raise ValueError('adaptation and retrieval provenance required')
        for field in ['sha256', 'source_sha256']:
            if len(row.get(field, '')) != 64 or any(c not in '0123456789abcdef' for c in row[field]):
                raise ValueError('SHA-256 provenance required')
        if not 90 <= row['duration_seconds'] <= 120:
            raise ValueError('duration')
        if row['excerpt_end_seconds'] - row['excerpt_start_seconds'] - row['crossfade_seconds'] != row['duration_seconds']:
            raise ValueError('edit duration')
        if row['excerpt_end_seconds'] > row['source_duration_seconds']:
            raise ValueError('source excerpt bounds')
    if len({row['source_sha256'] for row in rows}) != 5 or len({row['sha256'] for row in rows}) != 5:
        raise ValueError('distinct recordings required')


def signal_metrics(pcm: np.ndarray, rate: int) -> dict:
    if not np.isfinite(pcm).all() or pcm.ndim != 2 or pcm.shape[1] != 2:
        raise ValueError('decoded stereo signal')
    rms = float(np.sqrt(np.mean(pcm ** 2)))
    if rms < 0.001:
        raise ValueError('silent placeholder')
    seam = float(np.max(np.abs(pcm[0] - pcm[-1])))
    # A continuous waveform still changes between adjacent samples. Compare
    # the join with ordinary sample steps instead of incorrectly requiring zero.
    step_rms = float(np.sqrt(np.mean(np.diff(pcm, axis=0) ** 2)))
    if seam > 0.02 or seam > 5 * max(step_rms, 1e-7):
        raise ValueError('loop seam discontinuity')
    side = float(np.sqrt(np.mean((pcm[:, 0] - pcm[:, 1]) ** 2)))
    if side / rms < 0.01:
        raise ValueError('mono/tone placeholder')
    mono = pcm.mean(axis=1)
    frames = mono[:len(mono) // rate * rate].reshape(-1, rate)
    frame_rms = np.sqrt(np.mean(frames ** 2, axis=1))
    if float(np.mean(frame_rms < 0.001)) > 0.1:
        raise ValueError('inactive music')
    spectrum = (abs(np.fft.rfft(frames * np.hanning(rate), axis=1)) ** 2).mean(axis=0)
    concentration = float(spectrum.max() / spectrum.sum())
    if concentration > 0.35:
        raise ValueError('single-tone placeholder')
    return {'rms_dbfs': round(20 * np.log10(rms), 3),
            'seam_step_dbfs': round(20 * np.log10(max(seam, 1e-12)), 3),
            'stereo_side_ratio': round(side / rms, 4),
            'spectral_peak_fraction': round(concentration, 4)}


def command(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, check=True, timeout=90)


def verify() -> list[dict]:
    rows = load_manifest()
    validate_manifest(rows)
    reports = []
    for row in rows:
        path = ASSETS / row['file']
        if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
            raise ValueError(row['file'] + ': checksum/provenance mismatch')
        info = json.loads(command(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)]).stdout)
        stream = info['streams'][0]
        tags = info['format'].get('tags', {})
        if stream['codec_name'] != 'mp3' or stream['channels'] != 2 or int(stream['sample_rate']) != 44100:
            raise ValueError(row['file'] + ': audio format')
        if tags.get('artist') != 'Scott Buckley' or LICENSE_URL not in tags.get('copyright', ''):
            raise ValueError(row['file'] + ': embedded attribution')
        decoded = command(['ffmpeg', '-v', 'error', '-xerror', '-i', str(path), '-f', 'f32le', '-ac', '2', '-ar', '44100', '-']).stdout
        pcm = np.frombuffer(decoded, dtype='<f4').reshape(-1, 2)
        duration = len(pcm) / 44100
        if abs(duration - row['duration_seconds']) > 0.05:
            raise ValueError(row['file'] + ': decoded duration')
        signal = signal_metrics(pcm, 44100)
        measured = command(['ffmpeg', '-v', 'info', '-i', str(path), '-af', 'loudnorm=I=-20:TP=-2:LRA=7:print_format=json', '-f', 'null', '-']).stderr.decode()
        levels = json.JSONDecoder().raw_decode(measured[measured.rfind('{'):])[0]
        loudness, peak = float(levels['input_i']), float(levels['input_tp'])
        if not -21 <= loudness <= -19 or peak > -1.5:
            raise ValueError(row['file'] + ': narration bed level')
        reports.append({'file': row['file'], 'duration_seconds': duration,
                        'integrated_lufs': loudness, 'true_peak_dbtp': peak, **signal})
    return reports


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
