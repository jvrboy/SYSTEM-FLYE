import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "SYSTEMFLYE" / "Resources" / "SampleBank"
OUT.mkdir(parents=True, exist_ok=True)
SAMPLE_RATE = 48_000
DURATION_SECONDS = 60
FRAMES = SAMPLE_RATE * DURATION_SECONDS
CHANNELS = 2

# Five 60-second stereo production sample beds. They combine tonal layers with
# seeded low-level texture so they remain useful audio assets and do not
# collapse to a tiny compressed representation inside the IPA.
profiles = [
    (55.0, 0.17, 0.06),
    (82.41, 0.14, 0.08),
    (110.0, 0.12, 0.10),
    (164.81, 0.10, 0.12),
    (220.0, 0.08, 0.14),
]

for index, (base, level, texture) in enumerate(profiles, start=1):
    path = OUT / f"sample_bed_{index:02d}.wav"
    rng = random.Random(20260818 + index)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(CHANNELS)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        block = bytearray()
        for frame in range(FRAMES):
            t = frame / SAMPLE_RATE
            envelope = 0.72 + 0.28 * math.sin(2.0 * math.pi * 0.031 * t) ** 2
            left = (
                math.sin(2.0 * math.pi * base * t)
                + 0.42 * math.sin(2.0 * math.pi * base * 1.5 * t)
                + 0.18 * math.sin(2.0 * math.pi * base * 2.01 * t)
                + texture * (2.0 * rng.random() - 1.0)
            ) * level * envelope
            right = (
                math.sin(2.0 * math.pi * base * 1.003 * t + 0.35)
                + 0.42 * math.sin(2.0 * math.pi * base * 1.497 * t)
                + 0.18 * math.sin(2.0 * math.pi * base * 2.013 * t + 0.2)
                + texture * (2.0 * rng.random() - 1.0)
            ) * level * envelope
            block.extend(struct.pack("<hh", int(max(-1.0, min(1.0, left)) * 32767), int(max(-1.0, min(1.0, right)) * 32767)))
            if len(block) >= 262144:
                wav.writeframes(block)
                block.clear()
        if block:
            wav.writeframes(block)

print(f"Generated {len(profiles)} stereo WAV assets in {OUT}")
