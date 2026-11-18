import asyncio
import hashlib
import json
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'apps/soulbuddy'
CATALOG = APP / 'assets/content/prayer_library.json'
OUTPUT = APP / 'assets/audio/prayers'
VOICE = 'en-US-JennyNeural'
CUE = 'Be still. Give thanks, and bring this moment to God.'


def convert_to_wav(source: Path, target: Path) -> None:
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-ar', '24000', '-ac', '1', '-c:a', 'pcm_s16le', str(target)], check=True)
    with wave.open(str(target), 'rb') as audio:
        if audio.getnframes() / audio.getframerate() >= 30:
            raise ValueError(f'iOS notification audio exceeds 30 seconds: {target.name}')


async def main() -> None:
    prayers = json.loads(CATALOG.read_text(encoding='utf-8'))['prayers']
    expected_ids = ['0198a100-0000-7000-8000-00000000000' + str(i) for i in range(1, 10)]
    if [prayer['id'] for prayer in prayers] != expected_ids:
        raise ValueError('Prayer IDs or ordering changed; update the notification mapping')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='soulbuddy-prayer-voice-') as scratch:
        temp = Path(scratch)
        semaphore = asyncio.Semaphore(2)
        async def generate(prayer):
            name = prayer['id'] + '.mp3'
            async with semaphore:
                await edge_tts.Communicate(prayer['body'], VOICE, rate='-8%').save(str(temp / name))
            if (temp / name).stat().st_size < 1000:
                raise ValueError(f'Empty narration: {prayer["id"]}')
            return {'id': prayer['id'], 'file': name, 'body_sha256': hashlib.sha256(prayer['body'].encode('utf-8')).hexdigest()}
        entries = await asyncio.gather(*(generate(p) for p in prayers))
        for index, entry in enumerate(entries, 1):
            if index < 9:
                convert_to_wav(temp / entry['file'], temp / f'builtin_prayer_{index:02d}.wav')
        await edge_tts.Communicate(CUE, VOICE, rate='-8%').save(str(temp / 'cue.mp3'))
        convert_to_wav(temp / 'cue.mp3', temp / 'prayer_reflection_v1.wav')
        for index, entry in enumerate(entries, 1):
            name = f'builtin_prayer_{index:02d}'
            shutil.copyfile(temp / entry['file'], OUTPUT / entry['file'])
            shutil.copyfile(temp / entry['file'], APP / 'android/app/src/main/res/raw' / (name + '.mp3'))
            if index < 9:
                shutil.copyfile(temp / (name + '.wav'), APP / 'ios/Runner/Sounds' / (name + '.wav'))
        for destination in [APP / 'android/app/src/main/res/raw', APP / 'ios/Runner/Sounds']:
            shutil.copyfile(temp / 'prayer_reflection_v1.wav', destination / 'prayer_reflection_v1.wav')
        (OUTPUT / 'manifest.json').write_text(json.dumps({'version': 1, 'voice': VOICE, 'prayers': entries}, indent=2) + '\n', encoding='utf-8')
    print(f'Generated {len(entries)} prayers and notification audio')


if __name__ == '__main__':
    asyncio.run(main())
