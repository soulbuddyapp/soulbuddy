"""Build the narrated Kingdom Life nuggets and synchronized transcripts.

Run: python scripts/orientation/build_kingdom_course.py
Requires edge-tts and FFmpeg. Audio is generated once and committed as an asset.
"""

import asyncio
import argparse
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
# Original parables informed by the cooperation, attentiveness, surrender,
# and service themes in:
# http://www.soulprogress.com/html/ArticlesFolder/Articles/CooperatingWithGod.shtml
# Prayer impressions remain subject to Scripture, love, and wise counsel.
LESSONS = [
    (
        '01-the-old-life', 'Lay Down the Old Life', 'Let the flesh lose its rule',
        "What keeps choosing for you when you mean to choose Christ?\n\n"
        "A boy watched his father repair the gate beside their small garden. Each morning it stood open again, and hungry animals wandered through the seedlings. The boy wanted to chase the animals farther away. His father showed him the bent latch. Together they straightened it and fastened the gate. The next morning the boy checked it himself. Soon checking the gate became part of caring for the garden.\n\n"
        "The flesh is like that old rule within us: the reflex to grasp, hide, retaliate, or take the easier pleasure. The body is not our enemy, and a person is never a ruined garden. But an impulse becomes a master when we obey it without asking where it leads. Jesus invites us to bring that impulse into the light, receive mercy, and learn a different response. Grace does not leave us standing outside the gate. It gives us strength to take hold of the latch. What desire has been deciding for you lately? Name it honestly in prayer. Then choose one small act of self control today. Check the gate again tomorrow."
    ),
    (
        '02-the-new-adam', 'Life in the New Adam', 'Become more like Christ',
        "What if your past no longer gets the final word in your next decision?\n\n"
        "A girl had learned to protect herself by winning every argument. When her friend spoke sharply, she gathered the perfect reply and carried it all day. That evening she found the friend sitting alone outside. The reply was still ready. So was a quieter question: What happened? She sat down and asked it. Her friend began to cry. Nothing about the hurt vanished, but the old pattern lost its turn to speak.\n\n"
        "Adam's old pattern is familiar: grasp, blame, and hide. Christ, the new Adam, opens another way. He does not erase our personality or ask us to pretend that pain is harmless. He offers mercy that makes truth and love possible together. We cooperate with that grace whenever we pause, repent, listen, and choose as he would choose. We may need to make the choice again tomorrow. That is how a new life is trained, not how God's love is earned. Where do you usually defend yourself before you understand another person? Bring that moment to Jesus. Ask for the courage to tell the truth and the gentleness to hear it. Let your next response carry his likeness."
    ),
    (
        '03-kingdom-citizens', 'Citizens of the Kingdom', 'Live by its righteousness',
        "If the Kingdom of God became visible on your street, what would your neighbors notice?\n\n"
        "A boy helped his mother sell grain in the market. Near closing time, an older customer handed him too much money. His mother was busy, and no one else had seen. The boy counted again, then ran after the customer and returned the extra coins. The next week the customer came back with a friend. He trusted the hands that had measured his grain.\n\n"
        "Citizens carry the ways of their homeland into ordinary streets. In God's Kingdom, righteousness has a shape: honest work, mercy toward the weak, justice when no one is watching, and faithfulness when a shortcut would pay. These are not fees for entering the Kingdom. Christ welcomes us by grace and teaches us how its citizens live. Joy and peace may grow in such a life; spiritual gifts may equip us to serve. Neither is a benefit we can demand for good behavior. Where is your conduct out of step with your prayer? Return what is not yours. Repair an unfair choice. Speak truth with mercy. Let someone glimpse the Kingdom through the way you treat them today."
    ),
    (
        '04-gifts-for-service', 'Gifts for the Common Good', 'Receive and serve',
        "Who is meant to receive the good God has placed in your hands?\n\n"
        "A young woman carried warm bread to a neighbor whose husband had died. On the walk over, she rehearsed a speech about hope. At the door she saw the neighbor's tired face. She put the bread down, sat beside her, and listened. Only much later did she speak. The bread mattered. So did the hour of silence. Love had changed not only what she gave, but how she gave it.\n\n"
        "The Spirit gives gifts for the good of others: discernment, faith, healing, prophecy, and strength to serve. We may ask for them, but cannot claim them as wages or turn another person's suffering into our stage. Even an ordinary gift needs humility, timing, and tenderness. The Spirit also grows patience, peace, and joy in people who keep walking with Christ. A strong impression in prayer still needs to be tested by Scripture, love, and wise counsel. Whose need is before you today? Ask God what would truly help. Perhaps it is a prayer, a meal, a truthful word, or quiet company. Offer what you have, and leave the outcome in his hands."
    ),
    (
        '05-love-creation', 'Love Your Neighbor and Creation', 'Care for what God has entrusted',
        "What would love change in the place you pass every day?\n\n"
        "A girl walked past an empty lot on her way to school. Rubbish gathered around a struggling tree. She complained that somebody ought to clear it. Then she noticed an older neighbor who had begun carrying water to the tree each morning. The next day she brought a bag and cleared one small patch. Her friend joined her. Months later, children rested in the shade, and the neighbor picked herbs from a bed they had planted together. No one person had rescued the whole place. Each had answered for a part of it.\n\n"
        "To follow the new Adam is to love people and care for the creation entrusted to us. A life turned toward God cannot remain turned away from hungry neighbors, lonely friends, damaged streets, or needless waste. We do not serve to be seen. We serve because love takes responsibility for what is within reach. What person or living place has become easy for you to overlook? Listen, share, repair, protect, or plant one good thing today. Invite someone to work beside you. Repeat the small act when nobody applauds. Plant something good in the garden each day. Aim for a plentiful harvest."
    ),
    (
        '06-listen-and-write', 'Listen, Write, and Act', 'Offer your goals to God',
        "What if the next answer to your prayer begins with a step you would rather postpone?\n\n"
        "A woman came to prayer with a goal she cared deeply about. She wanted to begin work that would help her neighborhood. She opened a notebook and asked God for mercy and guidance. In the quiet she remembered a colleague she had dismissed too quickly. She wrote the thought down, then waited. Later she tested it against Scripture, love, and the counsel of someone she trusted. She did not call every thought a message from God. But she knew an honest apology would be good. The next day she made it. Their conversation became the first small step toward the work she hoped to do.\n\n"
        "Cooperation with grace has room for listening and for action. Name a goal that matters. Set a daily or weekly period and bring a notebook. Begin by entrusting the time to God. Sit, listen, and write what arises without forcing an answer. Then discern patiently: does it agree with Christ's love and with wise counsel? Choose one faithful action within your reach. If the page stays blank, the time is still prayer. Return at the next appointed time. A willing heart is formed through attention, truth, and service."
    ),
    (
        '07-open-hands', 'Open Hands', 'Train the heart in detachment',
        "Can you hear God clearly while gripping the answer you already want?\n\n"
        "A young woman prayed that God would use her voice. She pictured a crowded room listening. Then her choir leader asked her to visit an older singer who could no longer leave home. She felt the sting of being unseen. A friend asked, Would your voice still be a gift if only one person heard it? The question stayed with her. She prayed for a willing heart, visited the woman, and sang beside her chair. The song was quieter than she had imagined. Its love was no smaller.\n\n"
        "Detachment does not mean having no hopes. It means entrusting our hopes and their outcome to God, so that pride, fear, and preference do not choose for us. This takes training. Each day, name what you desire, and notice what you refuse to consider. Ask whether you would still do the good if it brought no credit. Offer the goal again in prayer. Take one small action that loosens your grip: listen before defending yourself, serve without being seen, or accept a correction. To abandon ourselves to God is not to despise the self. It is to trust his care more than our own control. Open your hands, then keep them open."
    ),
    (
        '08-discern-and-carry', 'Discern and Carry', 'Test the prompting; act in love',
        "What if the first thought after prayer is gentle, inconvenient, and easy to edit?\n\n"
        "A man prayed about a quarrel with his friend. The first thought that came was simple: call him, listen, and apologize for your part. A quiet sense of rightness accompanied it. Then another thought arrived: wait until he admits everything, and tell others how patient you have been. The man wrote down the first thought before his pride could dress it in better clothes. He prayed again, weighed it against Christ's call to truth and love, and made the call. His friend did not say everything he hoped to hear. Still, the conversation began to heal.\n\n"
        "Often the first thought after sincere prayer arrives before self protection has time to edit it. Attend to it, especially when it brings a steady peace and asks for love rather than applause. That feeling is a signal to discern, not proof that every thought comes from God. Bias can enter as we interpret or carry out an insight. Ask: would I hear the same thing if it cost me comfort or credit? Confirm it in prayer. Test it with Scripture and wise counsel, especially when a decision could seriously affect someone. Then do not let endless hesitation replace a safe, faithful act. Carry the good without letting ego rewrite it."
    ),
    (
        '09-forgive-the-neighbor', 'Forgive Without Denying the Wound', 'Leave justice with God; practice mercy',
        "What if forgiving a wrong did not require you to call it right?\n\n"
        "A girl lent her neighbor a lamp for an evening gathering. He broke it, hid the pieces, and told her it had already been cracked. She was hurt more by the lie than by the glass. For days she imagined a way to embarrass him. Then she told him plainly what she knew and asked him to make it right. He offered to repair the lamp. She accepted the repair, but did not lend him another precious thing while trust was being rebuilt. She stopped rehearsing revenge. Her boundaries stayed.\n\n"
        "God called creation very good, yet the world we inhabit bears real wounds. No wrong is beneath God's notice, but we cannot promise when or how another person's choices will meet their consequences. Justice belongs to God; safety and truthful repair still matter to us. When a neighbor sins against you, forgiveness is an opportunity to receive and extend mercy, not a bargain for a reward. It does not excuse abuse or demand unsafe closeness. What hurt have you been carrying into every new day? Name the wrong without minimizing it. Ask God for freedom from revenge. Seek protection, accountability, and repair where needed. Then take one step toward a heart no longer ruled by the injury."
    ),
    (
        '10-guard-the-temple', 'Guard What God Entrusted', 'Honor God in body and mind',
        "What do you protect when nobody else can see the cost?\n\n"
        "A young man kept a small lamp beside the notebook where he wrote his hopes. Each night he meant to pray and plan the next day. Instead he stayed awake chasing a pleasure that left him restless. One morning the glass was dark with soot, and he could scarcely read the page. His sister helped him clean it. The lamp was not worthless; its light had been obscured. He moved it, made room for sleep, and asked a trusted friend to help him keep the new rhythm.\n\n"
        "We can wrong a neighbor. When we sin against ourselves, we also sin against God, who entrusted this life to us. Scripture calls the body a temple of the Holy Spirit. Flee sexual immorality and anything that treats another person as an object. Resist drunkenness and chronic laziness when they become patterns that steal attention from love and work. If weariness, illness, or dependence is involved, seek care rather than hiding in shame. Sin does not erase your worth or place you beyond God's mercy. It can cloud the witness and freedom God wants to grow in you. Ask daily for grace to guard your body and purify your mind. Put one goal you prayed for before your eyes, and make one choice that serves it today."
    ),
    (
        '11-close-the-door', 'Close the Door, Begin Again', 'Repent, repair, and guard the way forward',
        "Which door keeps opening after you have asked God to close it?\n\n"
        "A man prayed each morning to leave a destructive habit behind. Each evening he walked the same route, passed the same doorway, and told himself he would only look inside. When he fell again, he thought repentance meant saying better words the next morning. An older friend listened, then walked home with him by a different street. Together they removed the easy access and planned whom he would call when the urge returned. The man still needed mercy. He also needed a new path.\n\n"
        "True repentance is neither denial nor a life of shame. Confess the wrong; God is faithful to forgive and cleanse. Make repair where you can. Learn the hour, place, feeling, or excuse that leads you back, and seal that door with a practical boundary. Ask for support when the pattern is hard to control; some struggles need skilled care as well as prayer. Do not leave the cleared space empty. Return to the goals you have offered God. Fill your mind each day with Scripture, prayer, honest work, and service. If you stumble, come into the light again. Mercy is not exhausted, and a guarded path can be walked one faithful step at a time."
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


async def build(only: set[str] | None = None) -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    catalog = []
    for lesson_id, title, tenet, text in LESSONS:
        if only is not None and lesson_id not in only:
            existing = json.loads((ASSETS / f'{lesson_id}.json').read_text(encoding='utf-8'))
            catalog.append({key: existing[key] for key in (
                'id', 'title', 'tenet', 'durationMs', 'audioAsset', 'transcriptAsset')})
            continue
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
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', nargs='*', metavar='ID', help='Regenerate only these lesson IDs')
    args = parser.parse_args()
    asyncio.run(build(set(args.only) if args.only is not None else None))
