"""Build the optional long teaching with engine-emitted word timestamps."""

import asyncio
import json
import re
import subprocess
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / ".artifacts" / "orientation"
WORK = SOURCE_DIR / "full-course-production"
ASSETS = ROOT / "apps" / "soulbuddy" / "assets" / "orientation"
VOICE = "en-US-GuyNeural"
RATE = "+10%"


def duration(path: Path) -> float:
    result = subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nk=1:nw=1", str(path)], text=True,
    )
    return float(result.strip())


def corrected_source() -> str:
    text = (SOURCE_DIR / "the-garden-must-bear-fruit.txt").read_text(
        encoding="utf-8-sig"
    )
    text = text.replace("The garden must bear fruit.", "Aim for a plentiful harvest.")
    text = re.sub(
        r"But whatever you do,\s*do not return the garden empty\.",
        "Plant something good in the garden each day.",
        text,
        flags=re.IGNORECASE,
    )
    return text.strip()


async def synthesize(text: str, audio_path: Path) -> list[dict]:
    boundaries = []
    communicate = edge_tts.Communicate(
        text, VOICE, rate=RATE, boundary="WordBoundary"
    )
    with audio_path.open("wb") as audio:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio.write(chunk["data"])
            elif chunk["type"] == "WordBoundary":
                boundaries.append(chunk)
    if not boundaries:
        raise RuntimeError("The speech engine returned no word boundaries")
    return boundaries


def transcript_words(text: str, boundaries: list[dict]) -> list[dict]:
    source_tokens = list(re.finditer(r"[\w’']+", text, flags=re.UNICODE))
    if len(source_tokens) != len(boundaries):
        raise RuntimeError(
            f"Speech/source word count differs: {len(boundaries)} / {len(source_tokens)}"
        )
    words = []
    previous_start = 0
    for token, boundary in zip(source_tokens, boundaries, strict=True):
        spoken = re.sub(r"[^\w]+", "", boundary["text"].casefold())
        written = re.sub(r"[^\w]+", "", token.group().casefold())
        if spoken != written:
            raise RuntimeError(
                f"Speech/source mismatch at {token.start()}: "
                f"{boundary['text']!r} / {token.group()!r}"
            )
        start_ms = max(previous_start, round(boundary["offset"] / 10_000))
        end_ms = max(
            start_ms + 1,
            round((boundary["offset"] + boundary["duration"]) / 10_000),
        )
        words.append({
            "startMs": start_ms,
            "endMs": end_ms,
            "charStart": token.start(),
            "charEnd": token.end(),
        })
        previous_start = start_ms
    return words


def transcript_sentences(text: str, words: list[dict]) -> list[dict]:
    sentences = []
    for match in re.finditer(r"[^\n]+", text):
        line_words = [
            word for word in words
            if word["charStart"] >= match.start() and word["charEnd"] <= match.end()
        ]
        if not line_words:
            continue
        sentences.append({
            "startMs": line_words[0]["startMs"],
            "endMs": line_words[-1]["endMs"],
            "charStart": match.start(),
            "charEnd": match.end(),
        })
    return sentences


def run() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    text = corrected_source()
    raw_voice = WORK / "engine-timed-voice.mp3"
    boundaries = asyncio.run(synthesize(text, raw_voice))
    words = transcript_words(text, boundaries)
    final = ASSETS / "full-course.mp3"
    subprocess.run(
        [
            "ffmpeg", "-y", "-i", str(raw_voice), "-stream_loop", "-1",
            "-i", str(SOURCE_DIR / "production" / "score.wav"),
            "-filter_complex",
            "[0:a]volume=1.0[voice];"
            "[1:a]volume=0.075,afade=t=in:st=0:d=3[music];"
            "[voice][music]amix=inputs=2:duration=first:dropout_transition=2[out]",
            "-map", "[out]", "-b:a", "160k", str(final),
        ],
        check=True,
    )
    duration_ms = round(duration(final) * 1000)
    words[-1]["endMs"] = min(words[-1]["endMs"], duration_ms)
    transcript = {
        "id": "full-course",
        "title": "Aim for a Plentiful Harvest — Full Teaching",
        "tenet": "The complete seven-tenet teaching",
        "durationMs": duration_ms,
        "text": text,
        "words": words,
        "sentences": transcript_sentences(text, words),
        "timingSource": "speech-engine-word-boundaries",
    }
    (ASSETS / "full-course.json").write_text(
        json.dumps(transcript, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (SOURCE_DIR / "aim-for-a-plentiful-harvest-corrected.txt").write_text(
        text + "\n", encoding="utf-8"
    )
    print(json.dumps({
        "durationMs": duration_ms,
        "words": len(words),
        "timingSource": transcript["timingSource"],
        "audio": str(final),
    }, indent=2))


if __name__ == "__main__":
    run()
