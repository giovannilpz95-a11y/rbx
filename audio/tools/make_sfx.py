"""Builds the game's original sound effects from code.

Every sound here is synthesized from sine waves, filtered noise and simple
envelopes, so the set is our own and has no outside source. Run from the
audio/ folder:

    python3 tools/make_sfx.py            # writes sfx/*.ogg (needs numpy and ffmpeg)
    python3 tools/make_sfx.py --wav      # also keeps the .wav files

The output is deterministic (each sound seeds its own noise from its name), so a
file only changes when its own function does. Upload the .ogg files to Roblox and
put the asset ids in src/shared/Sounds.luau.
"""

import subprocess
import sys
import wave
import zlib
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "sfx"
rng = np.random.default_rng(0)  # reseeded per sound in main(), so sounds don't affect each other


# Building blocks ---------------------------------------------------------------


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def silence(seconds):
    return np.zeros(int(RATE * seconds))


def note(name):
    """Frequency of a note like 'C5' or 'F#4' (A4 = 440 Hz)."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        semis += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        semis -= 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semis + (octave - 4) * 12) / 12)


def glide(f0, f1, seconds, curve=1.0):
    """Phase-continuous sine sweeping from f0 to f1."""
    t = t_axis(seconds)
    x = (t / seconds) ** curve
    freq = f0 + (f1 - f0) * x
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def decay(seconds, rate):
    return np.exp(-t_axis(seconds) * rate)


def attack_decay(seconds, attack, rate):
    t = t_axis(seconds)
    env = np.exp(-np.maximum(t - attack, 0) * rate)
    ramp = np.clip(t / max(attack, 1e-4), 0, 1)
    return env * ramp


def one_pole_lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def bandpass(x, center, q):
    """RBJ biquad band-pass (constant peak gain); center may be an array to sweep."""
    n = len(x)
    centers = np.broadcast_to(np.asarray(center, dtype=float), (n,))
    y = np.zeros(n)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(n):
        w0 = 2 * np.pi * centers[i] / RATE
        alpha = np.sin(w0) / (2 * q)
        b0, b2 = alpha, -alpha
        a0, a1, a2 = 1 + alpha, -2 * np.cos(w0), 1 - alpha
        out = (b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x[i]
        y2, y1 = y1, out
        y[i] = out
    return y


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def bell(freq, seconds, rate=6.0, ratio=2.76, index=1.2):
    """Small FM bell: bright at the start, mellow as it rings out."""
    t = t_axis(seconds)
    env = decay(seconds, rate)
    mod = np.sin(2 * np.pi * freq * ratio * t) * index * env
    return np.sin(2 * np.pi * freq * t + mod) * env


def marimba(freq, seconds=0.5):
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t) * decay(seconds, 9)
    overtone = np.sin(2 * np.pi * freq * 4 * t) * decay(seconds, 30) * 0.35
    click = np.sin(2 * np.pi * freq * 10 * t) * decay(seconds, 200) * 0.2
    return body + overtone + click


def pluck(freq, seconds=0.4, brightness=0.6):
    """Karplus-Strong string, for the ukulele-like jingles."""
    n = int(RATE * seconds)
    period = max(2, int(RATE / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % period]
        nxt = buf[(i + 1) % period]
        buf[i % period] = (brightness * buf[i % period] + (1 - brightness) * nxt) * 0.996
    return out * attack_decay(seconds, 0.002, 3)


def soft_brass(freq, seconds, attack=0.03):
    """Rounded brass-like tone: a few odd and even harmonics through a lowpass."""
    t = t_axis(seconds)
    tone = sum(np.sin(2 * np.pi * freq * k * t) / k ** 1.3 for k in range(1, 7))
    vibrato = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
    tone = tone * vibrato
    env = np.clip(t / attack, 0, 1) * np.exp(-np.maximum(t - attack, 0) * 1.6)
    return one_pole_lowpass(tone * env, 3200)


def place(base, sound, at):
    """Mix `sound` into `base` starting at `at` seconds, growing base if needed."""
    start = int(RATE * at)
    end = start + len(sound)
    if end > len(base):
        base = np.concatenate([base, np.zeros(end - len(base))])
    base[start:end] += sound
    return base


def sequence(parts):
    """parts: list of (time, sound)."""
    out = np.zeros(1)
    for at, sound in parts:
        out = place(out, sound, at)
    return out


def finish(x, peak=0.89, fade=0.01):
    x = np.asarray(x, dtype=float)
    x = x - np.mean(x)  # no DC offset
    n = min(len(x), int(RATE * fade))
    if n > 0:
        x[-n:] *= np.linspace(1, 0, n)
        x[:16] *= np.linspace(0, 1, 16)
    top = np.max(np.abs(x))
    if top > 0:
        x = x / top * peak
    return x


# The sounds -------------------------------------------------------------------
# Character: small, round and toy-like. Short tonal blips for UI, cute
# "real-ish" foley for farm actions, bright bells for rewards. See the vault's
# Design/26 Audio Style Guide.


def ui_tap():
    s = 0.07
    return glide(1250, 850, s, 0.5) * decay(s, 70) + noise(s) * decay(s, 400) * 0.15


def ui_open():
    return sequence([(0, glide(note("G5"), note("G5"), 0.09) * decay(0.09, 40)),
                     (0.055, glide(note("C6"), note("C6"), 0.12) * decay(0.12, 30))])


def ui_close():
    return sequence([(0, glide(note("C6"), note("C6"), 0.09) * decay(0.09, 40)),
                     (0.055, glide(note("G5"), note("G5"), 0.12) * decay(0.12, 30))])


def ui_error():
    tone = lambda f: (np.sin(2 * np.pi * f * t_axis(0.13)) + 0.3 * np.sin(4 * np.pi * f * t_axis(0.13))) * decay(0.13, 22)
    return one_pole_lowpass(sequence([(0, tone(note("E4"))), (0.12, tone(note("C4")))]), 2500)


def notify():
    return sequence([(0, glide(500, 1100, 0.06) * decay(0.06, 30)), (0.04, bell(note("E6"), 0.35, 9) * 0.6)])


def coin():
    hit = lambda f: bell(f, 0.3, 14, ratio=2.4, index=0.9)
    return sequence([(0, hit(2350)), (0.055, hit(3150) * 0.8)])


def coin_big():
    parts = []
    for i in range(7):
        f = rng.uniform(2100, 3400)
        parts.append((i * 0.045 + rng.uniform(0, 0.015), bell(f, 0.3, 13, ratio=2.4, index=0.9) * rng.uniform(0.5, 0.9)))
    parts.append((0.33, bell(note("E7"), 0.4, 8) * 0.5))
    return sequence(parts)


def gem():
    notes = ["C7", "E7", "G7", "C8"]
    parts = [(i * 0.06, np.sin(2 * np.pi * note(n) * t_axis(0.45)) * decay(0.45, 9) * 0.7) for i, n in enumerate(notes)]
    return sequence(parts)


def xp():
    s = 0.35
    sweep = np.linspace(600, 4200, int(RATE * s))
    air = bandpass(noise(s), sweep, 2.5) * attack_decay(s, 0.2, 10)
    return air * 1.6 + glide(note("C6"), note("C7"), s, 2) * attack_decay(s, 0.25, 14) * 0.35


def level_up():
    # Original rising fanfare: C major arpeggio, then a held chord with bells on top.
    arp = [("C5", 0.0), ("E5", 0.12), ("G5", 0.24)]
    parts = [(at, soft_brass(note(n), 0.3) * 0.7) for n, at in arp]
    for n in ["C5", "E5", "G5", "C6"]:
        parts.append((0.38, soft_brass(note(n), 1.5, 0.04) * 0.45))
    parts += [(0.40 + i * 0.07, bell(note(n), 0.8, 5) * 0.25) for i, n in enumerate(["C7", "G6", "E7", "C8"])]
    return sequence(parts)


def order_complete():
    melody = [("C5", 0.0), ("E5", 0.1), ("G5", 0.2), ("E5", 0.3), ("C6", 0.42)]
    parts = [(at, marimba(note(n), 0.55 if i == 4 else 0.3)) for i, (n, at) in enumerate(melody)]
    parts.append((0.42, marimba(note("G5"), 0.55) * 0.6))
    return sequence(parts)


def unlock():
    parts = [(i * 0.05, bell(note(n), 0.7, 6) * 0.6) for i, n in enumerate(["G6", "C7", "D7", "G7"])]
    return sequence(parts)


def plant():
    s = 0.16
    puff = one_pole_lowpass(noise(s), 900) * attack_decay(s, 0.01, 30) * 3
    thump = glide(150, 70, 0.1) * decay(0.1, 35)
    seeds = sequence([(0.0, noise(0.012) * 0.25), (0.03, noise(0.01) * 0.2), (0.055, noise(0.01) * 0.15)])
    return sequence([(0, puff), (0, thump), (0.005, bandpass(seeds, 5000, 3))])


def harvest():
    s = 0.15
    sweep = np.linspace(1800, 4500, int(RATE * s))
    swish = bandpass(noise(s), sweep, 1.5) * attack_decay(s, 0.05, 25) * 1.8
    pop = glide(500, 950, 0.06) * decay(0.06, 40)
    return sequence([(0, swish), (0.07, pop * 0.8)])


def feed():
    # A scoop of grain poured into a trough: a short rattle of tiny grains, then a soft thump.
    grains = sequence([(rng.uniform(0, 0.16), noise(0.004) * rng.uniform(0.3, 1.0)) for _ in range(40)])
    grains = bandpass(grains, 4200, 1.5) * 2
    trough = glide(220, 160, 0.08) * decay(0.08, 40) * 0.5
    return sequence([(0, grains), (0.15, trough)])


def ready():
    return sequence([(0, bell(note("E6"), 0.4, 8) * 0.7), (0.09, bell(note("A6"), 0.5, 7) * 0.6)])


def build_hammer():
    def knock(f):
        wood = bandpass(noise(0.08), f, 6) * decay(0.08, 50) * 4
        return place(wood, glide(f / 3, f / 4, 0.05) * decay(0.05, 60) * 0.4, 0)

    return sequence([(0, knock(950)), (0.16, knock(1050)), (0.30, knock(900))])


def build_done():
    pop = glide(300, 900, 0.07) * decay(0.07, 30)
    chord = sum(bell(note(n), 0.9, 4.5) for n in ["C6", "E6", "G6"]) / 2
    return sequence([(0, pop), (0.06, chord), (0.12, bell(note("C7"), 0.8, 5) * 0.4)])


def factory_start():
    s = 0.4
    t = t_axis(s)
    freq = np.linspace(110, 230, len(t))
    hum = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * (1 + 0.35 * np.sin(2 * np.pi * 18 * t))
    return one_pole_lowpass(hum * attack_decay(s, 0.1, 6), 1200)


def factory_collect():
    return sequence([(0, glide(400, 1000, 0.07) * decay(0.07, 30)), (0.05, bell(note("A6"), 0.4, 9) * 0.6)])


def sell():
    return sequence([(0, marimba(note("G5"), 0.2)), (0.06, coin() * 0.8)])


def pop_swap():
    s = 0.11
    sweep = np.linspace(900, 2600, int(RATE * s))
    return bandpass(noise(s), sweep, 2) * attack_decay(s, 0.04, 30) * 2


def pop_bad():
    s = 0.22
    t = t_axis(s)
    wobble = np.sin(2 * np.pi * np.cumsum(260 + 40 * np.sin(2 * np.pi * 14 * t) - 120 * t / s) / RATE)
    return wobble * attack_decay(s, 0.01, 12)


def pop_match():
    # Base pitch; the game raises PlaybackSpeed for each cascade step.
    s = 0.12
    body = glide(1100, 520, s, 0.5) * decay(s, 28)
    click = noise(0.01) * 0.3
    return sequence([(0, click), (0, body)])


def pop_power_made():
    parts = [(i * 0.045, bell(note(n), 0.35, 10) * 0.55) for i, n in enumerate(["C6", "E6", "G6", "C7", "E7"])]
    return sequence(parts)


def pop_sprayer():
    s = 0.32
    sweep = np.linspace(700, 6000, int(RATE * s))
    zip_ = bandpass(noise(s), sweep, 4) * attack_decay(s, 0.02, 9) * 3
    return zip_ + glide(note("C6"), note("C7"), s) * decay(s, 10) * 0.25


def pop_bomb():
    s = 0.45
    boom = one_pole_lowpass(one_pole_lowpass(noise(s), 400), 400) * attack_decay(s, 0.005, 9) * 8
    thump = glide(130, 45, 0.3) * decay(0.3, 9)
    sparkle = bell(note("G6"), 0.35, 10) * 0.2
    return sequence([(0, boom), (0, thump), (0.05, sparkle)])


def pop_bee():
    s = 0.38
    t = t_axis(s)
    freq = 230 + 25 * np.sin(2 * np.pi * 9 * t)
    phase = np.cumsum(freq) / RATE
    saw = 2 * (phase % 1) - 1
    return one_pole_lowpass(saw, 1800) * attack_decay(s, 0.04, 6) * (0.7 + 0.3 * np.sin(2 * np.pi * 30 * t))


def pop_sun():
    chord = sum(bell(note(n), 0.8, 4, ratio=3.0, index=0.8) for n in ["C6", "E6", "G6", "B6"]) / 2.5
    s = 0.6
    shimmer = bandpass(noise(s), 7000, 3) * attack_decay(s, 0.15, 6) * 0.8
    return sequence([(0, chord), (0, shimmer)])


def pop_bale():
    s = 0.16
    crunch = bandpass(noise(s), 2200, 1.2) * attack_decay(s, 0.003, 22)
    crackle = sequence([(rng.uniform(0, 0.1), noise(0.006) * rng.uniform(0.3, 0.8)) for _ in range(8)])
    return sequence([(0, crunch * 1.5), (0, bandpass(crackle, 3500, 2))])


def pop_mud():
    s = 0.18
    squish = one_pole_lowpass(one_pole_lowpass(noise(s), 700), 700) * attack_decay(s, 0.02, 18) * 5
    blub = glide(380, 160, 0.12, 0.6) * decay(0.12, 22) * 0.7
    return sequence([(0, squish), (0.02, blub)])


def pop_frost():
    # A thin ice layer cracking: a bright tick, a short crackle, then a little glassy ring.
    s = 0.25
    crack = bandpass(noise(0.03), 5200, 2) * decay(0.03, 120) * 3
    crackle = sequence([(rng.uniform(0.01, 0.09), noise(0.004) * rng.uniform(0.3, 0.9)) for _ in range(10)])
    ring = sum(bell(f, s, 14, ratio=2.9, index=0.6) for f in (3100, 4300)) * 0.35
    return sequence([(0, crack), (0.005, bandpass(crackle, 6500, 2) * 1.5), (0.02, ring)])


def pop_weed():
    # Pulling a weed: a quick rip of roots and a soft "plup" as it comes free.
    s = 0.14
    rip = bandpass(noise(s), np.linspace(900, 2600, int(RATE * s)), 1.2) * attack_decay(s, 0.02, 20) * 2
    plup = glide(320, 700, 0.07) * decay(0.07, 35) * 0.8
    return sequence([(0, rip), (0.09, plup)])


def pop_weed_grow():
    # A weed creeping onto a tile: a low rustle that swells, then a soft downward boing.
    s = 0.3
    rustle = bandpass(noise(s), 1400, 1.5) * attack_decay(s, 0.18, 14) * 1.6
    boing = glide(420, 230, 0.16, 0.7) * decay(0.16, 16) * 0.5
    return sequence([(0, rustle), (0.16, boing)])


def decor_place():
    # Setting a decoration down: a wooden thunk and a small sparkle.
    thunk = bandpass(noise(0.07), 600, 4) * decay(0.07, 45) * 3
    thump = glide(160, 90, 0.08) * decay(0.08, 30) * 0.6
    sparkle = bell(note("E7"), 0.35, 10) * 0.3
    return sequence([(0, thunk), (0, thump), (0.06, sparkle)])


def decor_rotate():
    # Turning a decoration: a short swish and a click.
    s = 0.12
    swish = bandpass(noise(s), np.linspace(1500, 3500, int(RATE * s)), 2) * attack_decay(s, 0.05, 25) * 1.5
    click = glide(1800, 1400, 0.02) * decay(0.02, 150) * 0.6
    return sequence([(0, swish), (0.09, click)])


def pop_shuffle():
    return sequence([(i * 0.09, pop_swap() * (1 - i * 0.12)) for i in range(5)])


def pop_booster():
    clink = bell(note("A6"), 0.25, 18, ratio=3.5, index=1.5) * 0.6
    return sequence([(0, pop_swap()), (0.05, clink)])


def pop_more_moves():
    parts = [(i * 0.09, marimba(note(n), 0.35)) for i, n in enumerate(["G5", "C6", "E6"])]
    return sequence(parts)


def pop_goal():
    return bell(note("A6"), 0.25, 14) * 0.7


def pop_win():
    melody = [("G4", 0.0), ("C5", 0.12), ("E5", 0.24), ("G5", 0.36), ("E5", 0.52), ("G5", 0.64)]
    parts = [(at, pluck(note(n), 0.5)) for n, at in melody]
    for n in ["C5", "E5", "G5", "C6"]:
        parts.append((0.8, pluck(note(n), 1.0) * 0.6))
    parts += [(0.82 + i * 0.06, bell(note(n), 0.7, 5) * 0.2) for i, n in enumerate(["C7", "E7", "G7"])]
    return sequence(parts)


def pop_lose():
    melody = [("E5", 0.0), ("D5", 0.22), ("B4", 0.44), ("C5", 0.7)]
    return sequence([(at, marimba(note(n), 0.7 if i == 3 else 0.4) * (0.9 - i * 0.1)) for i, (n, at) in enumerate(melody)])


SOUNDS = {
    "ui_tap": ui_tap,
    "ui_open": ui_open,
    "ui_close": ui_close,
    "ui_error": ui_error,
    "notify": notify,
    "coin": coin,
    "coin_big": coin_big,
    "gem": gem,
    "xp": xp,
    "level_up": level_up,
    "order_complete": order_complete,
    "unlock": unlock,
    "plant": plant,
    "harvest": harvest,
    "feed": feed,
    "ready": ready,
    "build_hammer": build_hammer,
    "build_done": build_done,
    "factory_start": factory_start,
    "factory_collect": factory_collect,
    "sell": sell,
    "decor_place": decor_place,
    "decor_rotate": decor_rotate,
    "pop_swap": pop_swap,
    "pop_bad": pop_bad,
    "pop_match": pop_match,
    "pop_power_made": pop_power_made,
    "pop_sprayer": pop_sprayer,
    "pop_bomb": pop_bomb,
    "pop_bee": pop_bee,
    "pop_sun": pop_sun,
    "pop_bale": pop_bale,
    "pop_mud": pop_mud,
    "pop_frost": pop_frost,
    "pop_weed": pop_weed,
    "pop_weed_grow": pop_weed_grow,
    "pop_shuffle": pop_shuffle,
    "pop_booster": pop_booster,
    "pop_more_moves": pop_more_moves,
    "pop_goal": pop_goal,
    "pop_win": pop_win,
    "pop_lose": pop_lose,
}


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main():
    keep_wav = "--wav" in sys.argv
    OUT.mkdir(exist_ok=True)
    global rng
    for name, make in SOUNDS.items():
        rng = np.random.default_rng(zlib.crc32(name.encode()))
        x = finish(make())
        wav = OUT / f"{name}.wav"
        write_wav(wav, x)
        ogg = OUT / f"{name}.ogg"
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5",
             "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(ogg)],
            check=True,
        )
        if not keep_wav:
            wav.unlink()
        print(f"{name:18s} {len(x) / RATE:5.2f}s")


if __name__ == "__main__":
    main()
