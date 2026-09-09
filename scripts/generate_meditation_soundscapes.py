"""Generate deterministic, seamless meditation ambience for SoulBuddy."""

from __future__ import annotations

import math
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np


RATE = 32_000
DURATION = 60
COUNT = RATE * DURATION
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "apps" / "soulbuddy" / "assets" / "audio" / "meditation"


def smooth(values: np.ndarray, width: int) -> np.ndarray:
    kernel = np.ones(width, dtype=np.float64) / width
    return np.convolve(values, kernel, mode="same")


def loop_fade(values: np.ndarray, seconds: float = 2.0) -> np.ndarray:
    width = int(RATE * seconds)
    blend = np.linspace(0.0, 1.0, width)
    start = values[:width].copy()
    end = values[-width:].copy()
    shared = end * (1 - blend) + start * blend
    values[:width] = shared
    values[-width:] = shared
    return values


def rain(rng: np.random.Generator) -> np.ndarray:
    noise = rng.normal(size=COUNT)
    base = noise - smooth(noise, 110)
    envelope = 0.72 + 0.16 * np.sin(np.linspace(0, 10 * math.pi, COUNT))
    return base * envelope


def ocean(rng: np.random.Generator) -> np.ndarray:
    noise = smooth(rng.normal(size=COUNT), 600)
    phase = np.linspace(0, 12 * math.pi, COUNT)
    swell = 0.12 + np.power((np.sin(phase) + 1) / 2, 2.4)
    foam = rng.normal(size=COUNT) - smooth(rng.normal(size=COUNT), 70)
    return noise * 9 * swell + foam * 0.075 * swell


def forest(rng: np.random.Generator) -> np.ndarray:
    sound = smooth(rng.normal(size=COUNT), 750) * 8
    t = np.arange(COUNT) / RATE
    for start in np.arange(2.0, DURATION - 1, 3.7):
        start += rng.uniform(-0.7, 0.7)
        mask = (t >= start) & (t < start + 0.5)
        local = t[mask] - start
        frequency = rng.uniform(1450, 2600) + local * rng.uniform(500, 1100)
        sound[mask] += 0.11 * np.sin(2 * math.pi * frequency * local) * np.sin(
            math.pi * local / 0.5
        )
    return sound


def wind(rng: np.random.Generator) -> np.ndarray:
    broad = smooth(rng.normal(size=COUNT), 320) * 12
    t = np.arange(COUNT) / RATE
    breath = 0.35 + 0.28 * np.sin(2 * math.pi * t / 11) + 0.17 * np.sin(
        2 * math.pi * t / 5.3
    )
    return broad * np.maximum(0.08, breath)


def fire(rng: np.random.Generator) -> np.ndarray:
    sound = smooth(rng.normal(size=COUNT), 260) * 5
    impulses = np.zeros(COUNT)
    positions = rng.integers(0, COUNT - 1500, size=360)
    for position in positions:
        length = int(rng.integers(80, 900))
        decay = np.exp(-np.linspace(0, 8, length))
        impulses[position : position + length] += (
            rng.normal(size=length) * decay * rng.uniform(0.25, 0.8)
        )
    return sound + impulses


def crickets(rng: np.random.Generator) -> np.ndarray:
    sound = smooth(rng.normal(size=COUNT), 650) * 3
    t = np.arange(COUNT) / RATE
    for start in np.arange(0.5, DURATION - 0.5, 1.25):
        start += rng.uniform(-0.18, 0.18)
        for pulse in range(4):
            pulse_start = start + pulse * 0.12
            mask = (t >= pulse_start) & (t < pulse_start + 0.07)
            local = t[mask] - pulse_start
            sound[mask] += 0.12 * np.sin(2 * math.pi * 4200 * local) * np.sin(
                math.pi * local / 0.07
            )
    return sound


def instrumental(
    rng: np.random.Generator,
    *,
    root: float,
    tempo: float,
    brightness: float,
) -> np.ndarray:
    """Create a restrained original pad-and-piano loop beneath narration."""
    t = np.arange(COUNT) / RATE
    sound = np.zeros(COUNT, dtype=np.float64)
    progression = ((0, 4, 7), (7, 11, 14), (9, 12, 16), (5, 9, 12))
    bar_seconds = 60.0 / tempo * 4
    for bar, chord in enumerate(progression * 4):
        start = bar * bar_seconds
        if start >= DURATION:
            break
        stop = min(DURATION, start + bar_seconds)
        mask = (t >= start) & (t < stop)
        local = t[mask] - start
        attack = np.minimum(1.0, local / 0.9)
        release = np.minimum(1.0, (stop - t[mask]) / 1.2)
        envelope = attack * release
        for semitones in chord:
            frequency = root * 2 ** (semitones / 12)
            sound[mask] += envelope * (
                0.055 * np.sin(2 * math.pi * frequency * local)
                + brightness
                * 0.018
                * np.sin(2 * math.pi * frequency * 2 * local)
            )
        note = chord[bar % len(chord)] + 12
        frequency = root * 2 ** (note / 12)
        pulse = np.exp(-local * 2.4) * np.sin(2 * math.pi * frequency * local)
        sound[mask] += pulse * 0.045
    air = smooth(rng.normal(size=COUNT), 1200) * 0.16
    return sound + air


def write_mp3(name: str, values: np.ndarray) -> None:
    values = loop_fade(values)
    values -= values.mean()
    peak = np.percentile(np.abs(values), 99.9)
    values = np.tanh(values / max(peak, 1e-8)) * 0.42
    pcm = (values * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = Path(tmp.name)
    try:
        with wave.open(str(wav_path), "wb") as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(RATE)
            wav_file.writeframes(pcm.tobytes())
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-i",
                str(wav_path),
                "-codec:a",
                "libmp3lame",
                "-b:a",
                "96k",
                str(OUTPUT / f"{name}.mp3"),
            ],
            check=True,
        )
    finally:
        wav_path.unlink(missing_ok=True)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    generators = {
        "gentle_rain": rain,
        "ocean_waves": ocean,
        "forest_morning": forest,
        "soft_wind": wind,
        "warm_fireplace": fire,
        "night_crickets": crickets,
        "hopeful_piano": lambda rng: instrumental(
            rng, root=220.0, tempo=66.0, brightness=0.45
        ),
        "cinematic_rise": lambda rng: instrumental(
            rng, root=164.81, tempo=72.0, brightness=0.72
        ),
        "steady_resolve": lambda rng: instrumental(
            rng, root=196.0, tempo=64.0, brightness=0.38
        ),
        "warm_strings": lambda rng: instrumental(
            rng, root=174.61, tempo=58.0, brightness=0.25
        ),
        "victorious_calm": lambda rng: instrumental(
            rng, root=246.94, tempo=70.0, brightness=0.55
        ),
    }
    for index, (name, generator) in enumerate(generators.items()):
        write_mp3(name, generator(np.random.default_rng(20260909 + index)))


if __name__ == "__main__":
    main()
