import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / '.artifacts' / 'orientation' / 'follow-along' / '00-welcome'
ASSET = ROOT / 'apps' / 'soulbuddy' / 'assets' / 'orientation' / '00-welcome.mp3'
TIMELINE = FOLDER / 'timeline.json'


def probe(path: Path) -> float:
    return float(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
        '-of', 'default=nk=1:nw=1', str(path)
    ], text=True).strip())


timeline = json.loads(TIMELINE.read_text(encoding='utf-8'))
old = timeline[2]
new_voice = FOLDER / 'voice-02.mp3'
new_duration = probe(new_voice)
prefix_end = old['start']
suffix_start = timeline[3]['start']
replacement_end = prefix_end + new_duration
next_start = replacement_end + 0.32
shift = next_start - suffix_start
output = FOLDER / 'narration-with-music.mp3'
temporary = FOLDER / 'narration-with-music-new.mp3'
filter_graph = (
    f'[0:a]atrim=0:{prefix_end},asetpts=PTS-STARTPTS[prefix];'
    f'[0:a]atrim={suffix_start},asetpts=PTS-STARTPTS[suffix];'
    '[1:a]loudnorm=I=-16:TP=-1.5:LRA=9,aresample=44100,pan=stereo|c0=c0|c1=c0[voice];'
    'anullsrc=r=44100:cl=stereo,atrim=0:0.32[pause];'
    '[prefix][voice][pause][suffix]concat=n=4:v=0:a=1[out]'
)
subprocess.run([
    'ffmpeg', '-y', '-v', 'error', '-i', str(ASSET), '-i', str(new_voice),
    '-filter_complex', filter_graph, '-map', '[out]', '-b:a', '192k', str(temporary)
], check=True)
temporary.replace(output)
old['end'] = replacement_end
old['trimStart'] = 0
old['text'] = 'Welcome to SoulBuddy. Eight memorable Nuggets, seven tenets, and stories that help you carry the lessons into everyday life.'
for item in timeline[3:]:
    item['start'] += shift
    item['end'] += shift
TIMELINE.write_text(json.dumps(timeline, indent=2), encoding='utf-8')
print(json.dumps({'newDuration': probe(output), 'timelineShift': shift}, indent=2))
