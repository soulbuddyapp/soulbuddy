param([string]$Voice = 'en-US-JennyNeural')
$ErrorActionPreference = 'Stop'
# Public, reviewed copy only. This script never reads a user database or prayer.
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
foreach ($command in @('python', 'ffmpeg', 'ffprobe', 'curl.exe')) { Get-Command $command -ErrorAction Stop | Out-Null }
# The current production voice deliberately supersedes the prototype Zira voice.
# Do not silently switch voices: provenance must describe the actual recording.
if ($Voice -ne 'en-US-JennyNeural') { throw 'The reviewed voice is en-US-JennyNeural.' }
$generator = @'
import asyncio, hashlib, json, math, os, re, shutil, subprocess, sys, tempfile, urllib.request, wave
from datetime import datetime, timezone
from pathlib import Path
import edge_tts

ROOT = Path(sys.argv[1])
VOICE = sys.argv[2]
OUT = ROOT / 'apps/soulbuddy/assets/audio/commitments'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = 'https://www.scottbuckley.com.au/library/wp-content/uploads/2026/04/Aphelion.mp3'
PAGE = 'https://www.scottbuckley.com.au/library/aphelion/'
CREDIT = '\u201cAphelion\u201d by Scott Buckley \u2014 released under CC BY 4.0. www.scottbuckley.com.au'
PLAN = 'docs/superpowers/plans/2026-09-24-commitment-formation-journey.md'
plan = (ROOT / PLAN).read_text(encoding='utf-8')
block = plan.split('Use these canonical text constants in `catalog_v1.json`:')[1].split('```text')[1].split('```')[0]
texts = dict(re.findall(r'^([A-Z ]+):\n(.+?)(?=\n\n[A-Z ]+:|\Z)', block.strip(), re.S | re.M))
texts = {k:v.strip() for k,v in texts.items()}
# The approved design is authoritative for this one-word plan discrepancy.
texts['INVITATION'] = texts['INVITATION'].replace('You do not carry it alone.', 'You do not carry this alone.')
opening = texts['COMMON GUIDE OPENING'].removesuffix(' Now listen.')
scripts = {
    'readiness_v1': texts['READINESS'],
    'invitation_v1': texts['INVITATION'],
    'guide_surrender_v1': opening + ' ' + texts['SURRENDER'] + ' Now listen.',
    'guide_direction_v1': opening + ' ' + texts['DIRECTION'] + ' Now listen.',
    'guide_peace_v1': opening + ' ' + texts['PEACE'] + ' Now listen.',
    'listening_v1': texts['LISTENING'],
    'spoken_invitation_v1': texts['SPOKEN INVITATION'],
}

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def probe(path):
    return json.loads(run('ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(path)))
def duration(path):
    return float(probe(path)['format']['duration'])
def vtt_stamp(ms):
    h, ms = divmod(ms, 3600000); m, ms = divmod(ms, 60000); s, ms = divmod(ms, 1000)
    return f'{h:02}:{m:02}:{s:02}.{ms:03}'
def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

async def main():
    assets = []
    with tempfile.TemporaryDirectory(prefix='soulbuddy-commitment-media-') as scratch:
        temp = Path(scratch)
        for asset_id, transcript in scripts.items():
            raw = temp / (asset_id + '.mp3')
            cues = []
            with raw.open('wb') as recording:
                async for chunk in edge_tts.Communicate(transcript, VOICE, rate='-5%', boundary='SentenceBoundary').stream():
                    if chunk['type'] == 'audio': recording.write(chunk['data'])
                    elif chunk['type'] == 'SentenceBoundary':
                        cues.append({'startMs': round(chunk['offset'] / 10000), 'endMs': round((chunk['offset'] + chunk['duration']) / 10000), 'text': chunk['text']})
            source_duration = duration(raw)
            target = max(source_duration, 55.0) if asset_id.startswith('guide_') or asset_id == 'listening_v1' else source_duration
            tempo = source_duration / target
            if tempo < 0.5: raise RuntimeError('Unexpected narration duration: ' + asset_id)
            filename = ('commitment_invitation_v1' if asset_id == 'spoken_invitation_v1' else asset_id) + '.wav'
            path = OUT / filename
            run('ffmpeg', '-v', 'error', '-y', '-i', str(raw), '-af', f'atempo={tempo:.9f},loudnorm=I=-19:TP=-2:LRA=7', '-ar', '24000', '-ac', '1', '-c:a', 'pcm_s16le', str(path))
            total_ms = round(duration(path) * 1000)
            for cue in cues:
                cue['startMs'] = round(cue['startMs'] / tempo)
                cue['endMs'] = min(total_ms, round(cue['endMs'] / tempo))
            # Provider sentence durations may overlap the next onset by ~50 ms.
            # Captions switch at the next actual onset; never display two cues.
            for cue, following in zip(cues, cues[1:]):
                cue['endMs'] = min(cue['endMs'], following['startMs'])
            if not cues: raise RuntimeError('Missing measured captions: ' + asset_id)
            txt = OUT / (asset_id + '.txt'); txt.write_text(transcript + '\n', encoding='utf-8')
            vtt = OUT / (asset_id + '.vtt')
            vtt.write_text('WEBVTT\n\n' + '\n\n'.join(f"{vtt_stamp(c['startMs'])} --> {vtt_stamp(c['endMs'])}\n{c['text']}" for c in cues) + '\n', encoding='utf-8')
            asset = {'id': asset_id, 'path': 'assets/audio/commitments/' + filename, 'format': 'wav', 'codec': 'pcm_s16le', 'sampleRate': 24000, 'channels': 1, 'durationMs': total_ms, 'durationBoundsMs': [max(1000,total_ms - 100), total_ms + 100], 'sha256': sha(path), 'transcript': transcript, 'transcriptPath': 'assets/audio/commitments/' + txt.name, 'transcriptSha256': sha(txt), 'captionsPath': 'assets/audio/commitments/' + vtt.name, 'captionsSha256': sha(vtt), 'captions': cues, 'required': False, 'fallback': 'transcript', 'defaultPlaybackRate': 1.0 if asset_id == 'spoken_invitation_v1' else 0.85, 'provenance': {'kind': 'reviewed-static-tts', 'provider': 'Microsoft Edge neural TTS', 'voice': VOICE, 'tool': 'edge-tts ' + edge_tts.__version__, 'synthesisRate': '-5%', 'postprocessTempo': round(tempo,9), 'captionTiming': 'Provider sentence boundaries from the generated audio stream, scaled by the measured postprocess tempo; source media milliseconds.', 'textSource': PLAN, 'privateContent': False}, 'license': {'identifier': 'SoulBuddy-reviewed-copy', 'text': 'SoulBuddy editorial guidance; bundled synthetic narration. Microsoft neural voice via Edge TTS; no claim of ownership of the voice or transfer of Microsoft service rights.', 'attribution': ''}, 'review': {'content': 'approved-design-and-plan', 'signal': 'verified-by-verify_assets.py', 'humanListening': 'pending'}}
            if asset_id.startswith('guide_'):
                asset['scripture'] = {'reference': 'Psalm 46:10', 'translation': 'RSVCE', 'quotation': 'Be still, and know that I am God.', 'provenance': 'Existing SoulBuddy RSVCE Scripture source; passage quotation retains existing distribution conditions.'}
            if asset_id == 'spoken_invitation_v1':
                asset['platformCopies'] = ['apps/soulbuddy/android/app/src/main/res/raw/commitment_invitation_v1.wav', 'apps/soulbuddy/ios/Runner/Sounds/commitment_invitation_v1.wav']
                for copy in asset['platformCopies']:
                    destination = ROOT / copy; destination.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(path, destination)
            assets.append(asset)
            print(asset_id + ': ' + str(total_ms) + ' ms', flush=True)
        source = temp / 'Aphelion.mp3'
        # The official server rejects urllib's TLS/client handshake with HTTP 406.
        # curl's standard HTTPS client succeeds against the same public URL.
        run('curl.exe', '--fail', '--location', '--silent', '--show-error', '--output', str(source), SOURCE)
        if sha(source) != '57ae03dbc122f0859e0f9a273e59503e34883728ddb5b06761fbf8244b0eb23e':
            raise RuntimeError('The official source changed; review the source before regenerating.')
        music = OUT / 'aphelion_excerpt_v1.mp3'
        run('ffmpeg', '-v', 'error', '-y', '-i', str(source), '-af', 'atrim=start=105:end=135,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.8,afade=t=out:st=28.5:d=1.5', '-ar', '44100', '-ac', '2', '-codec:a', 'libmp3lame', '-b:a', '192k', '-map_metadata', '-1', str(music))
        assets.append({'id':'aphelion_excerpt_v1', 'path':'assets/audio/commitments/aphelion_excerpt_v1.mp3', 'format':'mp3', 'codec':'mp3', 'sampleRate':44100, 'channels':2, 'durationMs':round(duration(music)*1000), 'durationBoundsMs':[29950,30100], 'sha256':sha(music), 'transcript':None, 'captions':[], 'required':False, 'fallback':'silent', 'defaultPlaybackRate':1.0, 'provenance':{'kind':'licensed-music-excerpt', 'sourceUrl':SOURCE, 'sourcePage':PAGE, 'sourceSha256':sha(source), 'sourceDurationMs':round(duration(source)*1000), 'sourceIntervalSeconds':[105,135], 'sourceInterval':'00:01:45-00:02:15', 'processing':'Exact decoded source interval; 0.8-second fade in, 1.5-second fade out; 192 kbps stereo MP3; no other music substituted.', 'licenseVerifiedAt':datetime.now(timezone.utc).date().isoformat(), 'privateContent':False}, 'license':{'identifier':'CC-BY-4.0', 'url':'https://creativecommons.org/licenses/by/4.0/', 'text':'Creative Commons Attribution 4.0 International. Redistribution and adaptation, including commercial use, are permitted with attribution, a license link, and an indication of changes.', 'attribution':CREDIT}, 'review':{'content':'approved-exact-source-interval', 'signal':'verified-by-verify_assets.py', 'humanListening':'pending'}})
    catalog = {'schemaVersion':1, 'defaultPlaybackRate':0.85, 'captionTimebase':'sourceMediaMilliseconds', 'invitationTimelineMs':45000, 'musicStartMs':8000, 'bellAtMs':41000, 'assets':assets}
    write_json(OUT / 'catalog_v1.json', catalog)
    lines = ['# Commitment media manifest', '', 'All spoken words are static public copy from the approved Commitment design and plan. No personal prayer, calling, need, practice, declaration, or other private user content was read or sent to a provider.', '', 'Regenerate with `powershell -NoProfile -ExecutionPolicy Bypass -File tools/audio/generate_commitment_assets.ps1`. Requires Python, edge-tts, ffmpeg, ffprobe, curl.exe, internet access, and the explicitly selected Microsoft en-US-JennyNeural voice. A failed voice request aborts; there is no substitute or silent placeholder.', '', '## Playback and captions', '', 'WAV masters are mono PCM16 at 24 kHz. Generic foreground narration defaults to 0.85x; notification playback and music use 1.0x. Sentence cues use source media milliseconds, so players use reported media position directly. Guides end with \u201cNow listen.\u201d The common opening\u2019s closing sentence is moved after the guide-specific paragraph to preserve the guide/bell/timer handoff. The design\u2019s \u201cYou do not carry this alone\u201d supersedes the plan\u2019s one-word invitation discrepancy.', '', 'Narration is normalized to -19 LUFS with a -2 dBTP target. Guides and Listening have approximately 55 seconds of source media (64.7 seconds at 0.85x). Microsoft neural TTS is the production voice, replacing the plan\u2019s optional/prototype desktop Zira voice. Provider sentence boundaries are scaled by the exact tempo used for the finished recording. No artificial silence is used to imitate a spoken guide.', '', 'Signal verification checks decoding, duration, format, measured loudness, clipping, transcript coverage, and platform-copy identity. Human listening review remains pending; automated checks do not establish aesthetic quality or editorial approval of a recording.', '', '## Music rights and changes', '', CREDIT, '', 'Official source: ' + PAGE, '', 'Official MP3: ' + SOURCE, '', 'License: https://creativecommons.org/licenses/by/4.0/', '', 'Exact source interval: **00:01:45\u201300:02:15** (105\u2013135 seconds). Changes: extract this interval, apply an 0.8-second fade in and a 1.5-second fade out, encode stereo MP3 at 192 kbps. The downloaded full track is kept only in a temporary directory and removed automatically. Include the credit and a link to the official source in app credits.', '', '## Narration and Scripture provenance', '', 'SoulBuddy owns its editorial guidance; the synthetic recordings use Microsoft Edge neural TTS through edge-tts. This manifest does not grant additional Microsoft service rights or assert ownership of Microsoft voices. Psalm 46:10 is quoted from the existing SoulBuddy RSVCE Scripture source and retains its existing distribution conditions. Source text: `' + PLAN + '` and the approved design.', '', '## Files', '', '| Asset ID | File | Duration (s) | Format | SHA-256 |', '|---|---|---:|---|---|']
    for a in assets: lines.append(f"| {a['id']} | {Path(a['path']).name} | {a['durationMs']/1000:.3f} | {a['codec']} | `{a['sha256']}` |")
    lines += ['', 'Every media file is optional at runtime: narration falls back to its complete transcript; music falls back to silence. Notification fallback is a silent generic notification. Platform sound copies are byte-identical to the master and use the versioned name `commitment_invitation_v1.wav`. The catalog contains full caption/transcript checksums, source checksum, detailed provenance, and per-asset duration bounds.', '']
    (OUT / 'ASSET-MANIFEST.md').write_text('\n'.join(lines), encoding='utf-8')

asyncio.run(main())
'@
$generator | python - $repoRoot $Voice
if ($LASTEXITCODE -ne 0) { throw 'Commitment media generation failed; do not ship incomplete output.' }
