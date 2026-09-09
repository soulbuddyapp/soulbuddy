import asyncio
import json
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / '.artifacts' / 'orientation' / 'follow-along' / '00-welcome'


async def main() -> None:
    segment = json.loads((FOLDER / 'speech-segments.json').read_text(encoding='utf-8'))[2]
    words = []
    with (FOLDER / 'voice-02.mp3').open('wb') as output:
        speech = edge_tts.Communicate(
            segment['text'],
            'en-US-GuyNeural',
            rate=segment['rate'],
            boundary='WordBoundary',
        )
        async for chunk in speech.stream():
            if chunk['type'] == 'audio':
                output.write(chunk['data'])
            elif chunk['type'] == 'WordBoundary':
                words.append({key: chunk[key] for key in ['offset', 'duration', 'text']})
    (FOLDER / 'voice-02.words.json').write_text(json.dumps(words, indent=2), encoding='utf-8')


asyncio.run(main())
