"""Build the six narrated Kingdom Life nuggets and synchronized transcripts.

Run: python scripts/orientation/build_kingdom_course.py
Requires edge-tts and FFmpeg. Audio is generated once and committed as an asset.
"""

import asyncio
import json
import re
import subprocess
import tempfile
from pathlib import Path

import edge_tts


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'apps' / 'soulbuddy' / 'assets' / 'kingdom'
MUSIC = ROOT / 'apps' / 'soulbuddy' / 'assets' / 'audio' / 'meditation' / 'hopeful_piano.mp3'
VOICE = 'en-US-ChristopherNeural'
LESSONS = [
    (
        '01-the-old-life', 'Lay Down the Old Life', 'Let the flesh lose its rule',
        "A child once watched his father mend a broken gate. The father did not paint over the rust. He took away the damaged hinge, set a new one in place, and taught his son how to keep it strong. Our habits can be like that gate. The animal impulses in us demand comfort, control, and the last word. Jesus calls us to lay down that old rule. Dying to the flesh is not hatred of the body. It is refusing to let appetite, fear, or pride command the heart. Bring one stubborn impulse into the light today. Ask Christ for mercy. Then practice one concrete act of self control, with help when you need it. The new life begins in surrender, and grows through faithful choices."
    ),
    (
        '02-the-new-adam', 'Life in the New Adam', 'Become more like Christ',
        "A girl heard her friend say, I thought I could never change. Then she saw that friend forgive someone who had hurt her. The change was not a performance. It was a new way of living. Christ is the new Adam. In him, we are invited beyond the old pattern of hiding, blaming, and grasping. We receive mercy, and learn to tell the truth. We receive love, and learn to give it. We are not made new by a single impressive moment. We abide in Jesus, repent when we fall, and begin again. Name a pattern you want to leave behind. Name the Christlike response you want to practice instead. Today, choose that response for one real person."
    ),
    (
        '03-kingdom-citizens', 'Citizens of the Kingdom', 'Live by its righteousness',
        "Imagine entering a city where every neighbor protects the weak and speaks the truth. You would know its way of life by how people treat one another. Jesus speaks of a Kingdom with a deeper righteousness. Its citizens learn mercy, honesty, justice, humility, and faithfulness. These are not rules for earning God's love. They are the shape of a life growing under his reign. We cannot claim the life of the Kingdom while refusing its love for our neighbor. Ask where your daily conduct needs to agree with your prayer. Make one honest repair. Choose one fair action. Let the way you speak, spend, work, and serve show whose Kingdom you seek."
    ),
    (
        '04-gifts-for-service', 'Gifts for the Common Good', 'Receive and serve',
        "A boy saw his father share a basket of fruit with the whole street. The gift was real because it reached someone hungry. In the Kingdom, the Spirit gives gifts for the good of others. We may pray for discernment, faith, healing, prophecy, and strength to serve. We receive every gift with humility, test what we believe we hear, and never use another person's need as a stage. The Spirit also grows joy, peace, patience, and love in ordinary life. These blessings are grace, not a prize we can demand. Ask God which person needs your attention. Ask for the gift that would help you serve faithfully. Then give what you have, even if it seems small."
    ),
    (
        '05-love-creation', 'Love Your Neighbor and Creation', 'Care for what God has entrusted',
        "One morning, a girl noticed that the garden beside her street had become a place for rubbish. She could not restore it in a day. She began by clearing one small patch and inviting a friend to help. Love takes responsibility for what is within reach. Following Jesus turns us toward people and toward the world God has entrusted to our care. Feed, listen, forgive, protect, repair, and share. Refuse waste when a better choice is possible. Care for a person without expecting applause. Care for a living place without waiting for someone else to begin. A life of service grows through repeated small acts. Plant something good in the garden each day. Aim for a plentiful harvest."
    ),
    (
        '06-listen-and-write', 'Listen, Write, and Act', 'Offer your goals to God',
        "A woman brought a notebook to prayer because she did not want a good thought to disappear. She first asked for mercy and guidance. Then she sat in quiet attention. She wrote down what came to mind, without treating every thought as a command from God. Later, she weighed those notes against Scripture, love, wisdom, and the counsel of trusted people. You can practice this with an important goal. Name it clearly. Set a daily or weekly time. Begin by committing the period to God. Keep a notebook ready. Listen, write, and discern. End by choosing one faithful step. If nothing comes, the time is not wasted. Remaining with God can train the heart to hear, to love, and to serve."
    ),
]


def _probe_duration(path: Path) -> int:
    result = subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1', str(path),
    ], text=True).strip()
    return round(float(result) * 1000)


def _cues(text: str, boundaries: list[dict], duration: int) -> tuple[list[dict], list[dict]]:
    tokens = list(re.finditer(r"[A-Za-z]+(?:'[A-Za-z]+)?", text))
    if len(tokens) != len(boundaries):
        raise ValueError(f'Word count differs: {len(tokens)} text, {len(boundaries)} audio')
    words = []
    for token, boundary in zip(tokens, boundaries):
        spoken = re.sub(r'[^a-z]', '', boundary['text'].lower())
        written = re.sub(r'[^a-z]', '', token.group().lower())
        if spoken != written:
            raise ValueError(f'Word mismatch: {token.group()} / {boundary["text"]}')
        start = round(boundary['offset'] / 10000)
        end = min(duration, round((boundary['offset'] + boundary['duration']) / 10000))
        words.append(dict(startMs=start, endMs=max(start + 1, end),
                          charStart=token.start(), charEnd=token.end()))
    sentences = []
    for match in re.finditer(r'[^.!?]+[.!?]', text):
        start, end = match.span()
        while start < end and text[start].isspace():
            start += 1
        sentence_words = [word for word in words if start <= word['charStart'] < end]
        if not sentence_words:
            continue
        sentences.append(dict(startMs=sentence_words[0]['startMs'],
                              endMs=sentence_words[-1]['endMs'],
                              charStart=start, charEnd=end))
    return words, sentences


async def build() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    catalog = []
    for lesson_id, title, tenet, text in LESSONS:
        boundaries = []
        with tempfile.TemporaryDirectory() as directory:
            voice = Path(directory) / 'voice.mp3'
            with voice.open('wb') as output:
                speech = edge_tts.Communicate(text, VOICE, rate='+8%', boundary='WordBoundary')
                async for chunk in speech.stream():
                    if chunk['type'] == 'audio':
                        output.write(chunk['data'])
                    elif chunk['type'] == 'WordBoundary':
                        boundaries.append(chunk)
            audio = ASSETS / f'{lesson_id}.mp3'
            subprocess.run([
                'ffmpeg', '-loglevel', 'error', '-y', '-i', str(voice),
                '-stream_loop', '-1', '-i', str(MUSIC),
                '-filter_complex', '[1:a]volume=0.08[bed];[0:a][bed]amix=inputs=2:duration=first:dropout_transition=0[mix]',
                '-map', '[mix]', '-codec:a', 'libmp3lame', '-q:a', '3', str(audio),
            ], check=True)
        duration = _probe_duration(audio)
        words, sentences = _cues(text, boundaries, duration)
        metadata = dict(id=lesson_id, title=title, tenet=tenet, durationMs=duration,
                        audioAsset=f'kingdom/{lesson_id}.mp3',
                        transcriptAsset=f'assets/kingdom/{lesson_id}.json')
        (ASSETS / f'{lesson_id}.json').write_text(
            json.dumps({**metadata, 'text': text, 'words': words, 'sentences': sentences},
                       ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        catalog.append(metadata)
        print(f'{lesson_id}: {duration / 1000:.1f}s, {len(words)} words')
    (ASSETS / 'catalog.json').write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    asyncio.run(build())
