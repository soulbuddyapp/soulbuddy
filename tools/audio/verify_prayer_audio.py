import hashlib
import json
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'apps/soulbuddy'
ASSETS = APP / 'assets/audio/prayers'
CATALOG = json.loads((APP / 'assets/content/prayer_library.json').read_text(encoding='utf-8'))['prayers']
MANIFEST = json.loads((ASSETS / 'manifest.json').read_text(encoding='utf-8'))['prayers']
if len(CATALOG) != 9 or len(MANIFEST) != len(CATALOG):
    raise SystemExit('Prayer audio coverage is incomplete')
for index, (prayer, entry) in enumerate(zip(CATALOG, MANIFEST), 1):
    if prayer['id'] != entry['id'] or entry['body_sha256'] != hashlib.sha256(prayer['body'].encode('utf-8')).hexdigest():
        raise SystemExit('Prayer audio text mismatch')
    source = ASSETS / entry['file']
    native = APP / f'android/app/src/main/res/raw/builtin_prayer_{index:02d}.mp3'
    if not source.is_file() or source.stat().st_size < 1000 or source.read_bytes() != native.read_bytes():
        raise SystemExit(f'Android audio mismatch: {index}')
    if index < 9:
        target = APP / f'ios/Runner/Sounds/builtin_prayer_{index:02d}.wav'
        with wave.open(str(target), 'rb') as audio:
            if audio.getnchannels() != 1 or audio.getsampwidth() != 2 or audio.getframerate() != 24000 or audio.getnframes() / audio.getframerate() >= 30:
                raise SystemExit(f'Invalid iOS notification audio: {index}')
            actual = audio.readframes(audio.getnframes())
        expected = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(source), '-ar', '24000', '-ac', '1', '-f', 's16le', '-'], check=True, capture_output=True).stdout
        if actual != expected:
            raise SystemExit(f'iOS audio mismatch: {index}')
android = APP / 'android/app/src/main/res/raw/prayer_reflection_v1.wav'
ios = APP / 'ios/Runner/Sounds/prayer_reflection_v1.wav'
if android.read_bytes() != ios.read_bytes():
    raise SystemExit('Reminder cue copies differ')
with wave.open(str(ios), 'rb') as audio:
    if audio.getnframes() / audio.getframerate() >= 30:
        raise SystemExit('Reminder cue exceeds the iOS limit')
print('Verified 9 prayers, Android recordings, 8 iOS recordings and reminder cue')
