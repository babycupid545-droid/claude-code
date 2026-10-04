"""Synthesizes every sound in the game.

Outputs (in assets/audio/):
  Sfx.ogg               all sound effects back to back (one upload); regions in SoundSprites.luau
  MusicLobby.ogg        chill, bouncy lobby loop
  MusicRound.ogg        energetic round loop
  MusicSuddenDeath.ogg  intense loop for sudden death

Run: python3 tools/audio/make_audio.py   (needs numpy, scipy and ffmpeg)
"""

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "audio")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "SoundSprites.luau")

SR = 44100
rng = np.random.default_rng(1234)


# --- building blocks -----------------------------------------------------------------------

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_adsr(n, a=0.005, d=0.05, s=0.6, r=0.1):
    total = n / SR
    r = min(r, total * 0.5)
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1), endpoint=False),
        np.linspace(1, s, max(d_n, 1), endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR / decay)


def phase_of(freq):
    """Integrates a frequency curve (Hz per sample) into phase."""
    if np.isscalar(freq):
        return None
    return 2 * np.pi * np.cumsum(freq) / SR


def osc(kind, freq, dur, duty=0.5):
    n = int(dur * SR)
    if np.isscalar(freq):
        ph = 2 * np.pi * freq * np.arange(n) / SR
    else:
        ph = 2 * np.pi * np.cumsum(freq[:n]) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "square":
        return np.where((ph / (2 * np.pi)) % 1 < duty, 1.0, -1.0)
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if kind == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1
    raise ValueError(kind)


def sweep(f0, f1, dur, curve="exp"):
    n = int(dur * SR)
    if curve == "exp":
        return f0 * (f1 / f0) ** np.linspace(0, 1, n)
    return np.linspace(f0, f1, n)


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, SR / 2 - 100) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def sweep_filter(x, f0, f1, kind="low", q_steps=64):
    """Time-varying filter by processing short blocks with interpolated cutoffs."""
    out = np.zeros_like(x)
    blocks = np.array_split(np.arange(len(x)), q_steps)
    zi = None
    for i, idx in enumerate(blocks):
        f = f0 * (f1 / f0) ** (i / max(1, q_steps - 1))
        b, a = signal.butter(2, min(f, SR / 2 - 200) / (SR / 2), kind)
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        out[idx], zi = signal.lfilter(b, a, x[idx], zi=zi)
    return out


def reverb(x, mix=0.25, size=1.0):
    """Small Schroeder reverb."""
    out = np.zeros(len(x) + int(SR * 1.5 * size))
    xp = np.pad(x, (0, len(out) - len(x)))
    wet = np.zeros_like(out)
    for delay_ms, g in ((29.7, 0.77), (37.1, 0.75), (41.1, 0.73), (43.7, 0.71)):
        d = int(delay_ms * size * SR / 1000)
        a = np.zeros(d + 1)
        a[0], a[d] = 1, -g
        wet += signal.lfilter([1], a, xp)
    for delay_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(delay_ms * SR / 1000)
        b = np.zeros(d + 1)
        b[0], b[d] = -g, 1
        a = np.zeros(d + 1)
        a[0], a[d] = 1, -g
        wet = signal.lfilter(b, a, wet)
    out = xp * (1 - mix) + wet * mix * 0.25
    return out


def place(buf, x, start):
    i = int(start * SR)
    end = min(len(buf), i + len(x))
    if end > i:
        buf[i:end] += x[: end - i]


def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x if m == 0 else x / m * peak


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# --- sound effects -------------------------------------------------------------------------

def sfx_ui_click():
    d = 0.09
    x = osc("sine", sweep(1100, 520, d), d) * env_exp(int(d * SR), 0.025)
    x += 0.3 * highpass(noise(d), 3000) * env_exp(int(d * SR), 0.006)
    return x


def sfx_ui_hover():
    d = 0.05
    return 0.5 * osc("sine", 1700, d) * env_exp(int(d * SR), 0.012)


def sfx_ui_open():
    d = 0.32
    w = sweep_filter(noise(d), 300, 5000, "low") * env_adsr(int(d * SR), 0.02, 0.1, 0.5, 0.15)
    p = osc("sine", sweep(500, 1100, 0.12), 0.12) * env_exp(int(0.12 * SR), 0.04)
    out = np.zeros(int(d * SR))
    place(out, w * 0.5, 0)
    place(out, p, 0.18)
    return out


def sfx_ui_close():
    d = 0.25
    w = sweep_filter(noise(d), 4000, 300, "low") * env_adsr(int(d * SR), 0.01, 0.1, 0.5, 0.12)
    p = osc("sine", sweep(900, 450, 0.1), 0.1) * env_exp(int(0.1 * SR), 0.035)
    out = np.zeros(int(d * SR))
    place(out, w * 0.5, 0)
    place(out, p, 0.02)
    return out


def bell(freq, dur, bright=2.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * freq * 3.5 * t) * bright * env_exp(n, dur * 0.3)
    return np.sin(2 * np.pi * freq * t + mod) * env_exp(n, dur * 0.35)


def sfx_vote():
    out = np.zeros(int(0.6 * SR))
    place(out, bell(1046.5, 0.4), 0)
    place(out, bell(1568, 0.5), 0.1)
    return out


def sfx_tick():
    d = 0.14
    x = osc("square", 880, d, 0.3) * env_adsr(int(d * SR), 0.002, 0.03, 0.4, 0.06)
    return lowpass(x, 4000) * 0.6


def sfx_go():
    d = 0.9
    out = np.zeros(int(d * SR))
    for m in (72, 76, 79, 84):
        x = osc("saw", mtof(m), d) * env_adsr(int(d * SR), 0.005, 0.2, 0.3, 0.4)
        place(out, lowpass(x, 3500) * 0.25, 0)
    place(out, 0.4 * sweep_filter(noise(0.5), 400, 8000, "low") * env_adsr(int(0.5 * SR), 0.2, 0.1, 0.4, 0.2), 0)
    return out


def sfx_whistle():
    d = 0.7
    t = t_axis(d)
    f = 2900 + 120 * np.sin(2 * np.pi * 28 * t)
    x = osc("sine", f, d) * env_adsr(int(d * SR), 0.02, 0.05, 0.9, 0.12)
    x += 0.15 * bandpass(noise(d), 2500, 3500) * env_adsr(int(d * SR), 0.02, 0.05, 0.9, 0.12)
    return x * 0.6


def sfx_coin():
    out = np.zeros(int(0.45 * SR))
    a = osc("square", 988, 0.07, 0.25) * env_adsr(int(0.07 * SR), 0.001, 0.02, 0.7, 0.01)
    b = osc("square", 1319, 0.35, 0.25) * env_exp(int(0.35 * SR), 0.12)
    place(out, a, 0)
    place(out, b, 0.07)
    return lowpass(out, 6000) * 0.45


def sfx_purchase():
    out = np.zeros(int(1.0 * SR))
    place(out, sfx_coin(), 0)
    for i, m in enumerate((84, 88, 91, 96)):
        place(out, bell(mtof(m), 0.5, 1.2) * 0.5, 0.12 + i * 0.07)
    return out


def sfx_equip():
    d = 0.3
    out = np.zeros(int(d * SR))
    place(out, 0.4 * bandpass(noise(0.2), 800, 4000) * env_adsr(int(0.2 * SR), 0.05, 0.05, 0.4, 0.1), 0)
    place(out, osc("sine", sweep(600, 1200, 0.08), 0.08) * env_exp(int(0.08 * SR), 0.03), 0.12)
    return out


def sfx_error():
    out = np.zeros(int(0.4 * SR))
    for i, f in enumerate((220, 175)):
        x = osc("square", f, 0.15, 0.5) * env_adsr(int(0.15 * SR), 0.003, 0.03, 0.6, 0.04)
        place(out, lowpass(x, 1800) * 0.5, i * 0.16)
    return out


def sfx_toast():
    d = 0.16
    return osc("sine", sweep(700, 1300, d), d) * env_exp(int(d * SR), 0.05) * 0.6


def sfx_egg_shoot():
    d = 0.25
    out = np.zeros(int(d * SR))
    # A comedic "pfft" followed by a pop.
    pf = bandpass(noise(0.12), 300, 1400) * env_adsr(int(0.12 * SR), 0.005, 0.03, 0.5, 0.05)
    pop = osc("sine", sweep(520, 180, 0.12), 0.12) * env_exp(int(0.12 * SR), 0.04)
    place(out, pf * 0.6, 0)
    place(out, pop, 0.05)
    return out


def sfx_egg_hit():
    d = 0.45
    n = int(d * SR)
    crack = highpass(noise(0.03), 2500) * env_exp(int(0.03 * SR), 0.006)
    squelch = sweep_filter(noise(d), 2500, 300, "low") * env_exp(n, 0.12)
    wet = osc("sine", sweep(300, 90, 0.2), 0.2) * env_exp(int(0.2 * SR), 0.06)
    out = np.zeros(n)
    place(out, crack * 0.8, 0)
    place(out, squelch * 0.7, 0.01)
    place(out, wet * 0.6, 0.02)
    return out


def sfx_squash():
    d = 0.8
    n = int(d * SR)
    thump = osc("sine", sweep(140, 40, 0.35), 0.35) * env_exp(int(0.35 * SR), 0.12)
    crunch = lowpass(noise(0.3), 2500) * env_exp(int(0.3 * SR), 0.08)
    honk = lowpass(osc("square", 330, 0.25, 0.4) + osc("square", 415, 0.25, 0.4), 2500) * env_adsr(
        int(0.25 * SR), 0.01, 0.05, 0.7, 0.05)
    out = np.zeros(n)
    place(out, honk * 0.2, 0)
    place(out, thump * 1.0, 0.05)
    place(out, crunch * 0.6, 0.05)
    return soft_clip(out, 1.5)


def sfx_feathers():
    d = 0.6
    return bandpass(noise(d), 1500, 7000) * env_adsr(int(d * SR), 0.01, 0.1, 0.3, 0.4) * 0.5


def sfx_jump():
    d = 0.18
    return osc("sine", sweep(280, 720, d), d) * env_adsr(int(d * SR), 0.003, 0.05, 0.6, 0.08) * 0.5


def sfx_land():
    d = 0.15
    return lowpass(noise(d), 600) * env_exp(int(d * SR), 0.03) * 0.8


def sfx_glide():
    d = 0.5
    return sweep_filter(noise(d), 300, 3000, "low") * env_adsr(int(d * SR), 0.1, 0.1, 0.5, 0.25) * 0.5


def sfx_wind_loop():
    d = 4.0
    n = int(d * SR)
    t = t_axis(d)
    base = lowpass(noise(d + 0.5), 900)[int(0.5 * SR):][:n]
    gust = 0.6 + 0.4 * np.sin(2 * np.pi * t / d) ** 2
    x = base * gust
    # Crossfade the end into the start for a seamless loop.
    fade = int(0.4 * SR)
    x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
    return x[: n - fade]


def sfx_boing():
    d = 0.5
    t = t_axis(d)
    f = 220 * (1 + 0.6 * np.exp(-t * 6) * np.sin(2 * np.pi * 14 * t)) * (1 + t)
    return osc("sine", f, d) * env_exp(int(d * SR), 0.18) * 0.8


def sfx_bawk(long=False):
    """A cartoon chicken cluck: a buzzy voice through two formants."""
    d = 0.55 if long else 0.24
    t = t_axis(d)
    if long:
        f0 = 520 + 260 * np.clip(t / 0.08, 0, 1) - 160 * np.clip((t - 0.1) / 0.4, 0, 1)
    else:
        f0 = 620 - 200 * t / d
    f0 = f0 * (1 + 0.03 * np.sin(2 * np.pi * 30 * t))
    voice = osc("saw", f0, d) + 0.3 * noise(d)
    x = bandpass(voice, 900, 1500) * 1.0 + bandpass(voice, 2200, 3200) * 0.6
    e = env_adsr(len(x), 0.008, 0.04, 0.7, 0.08 if not long else 0.15)
    click = highpass(noise(0.01), 2000) * env_exp(int(0.01 * SR), 0.002)
    out = np.zeros(len(x))
    place(out, click * 0.5, 0)
    out += x * e
    return soft_clip(normalize(out) * 1.4, 1.2)


def sfx_car_engine_loop():
    """One second of engine; a whole number of cycles of every partial so it loops seamlessly."""
    d = 1.0
    t = t_axis(d)
    f = 60.0
    x = np.zeros_like(t)
    for h, amp in ((1, 1.0), (2, 0.6), (3, 0.35), (4, 0.2), (6, 0.1)):
        x += amp * np.sin(2 * np.pi * f * h * t + h)
    rumble = 0.4 * np.sin(2 * np.pi * 8 * t) + 0.2 * np.sin(2 * np.pi * 15 * t)
    x = x * (1 + 0.3 * rumble)
    x = soft_clip(x * 0.6, 2.0)
    return lowpass(np.tile(x, 3), 1600)[len(x):2 * len(x)]


def sfx_car_whoosh():
    d = 1.1
    n = int(d * SR)
    t = t_axis(d)
    center = 0.45
    amp = np.exp(-((t - center) / 0.18) ** 2)
    whoosh = sweep_filter(noise(d), 4500, 600, "low") * amp
    tone_f = np.where(t < center, 420, 300) * (1 + 0.15 * np.tanh((center - t) * 10))
    tone = lowpass(osc("saw", tone_f, d), 1200) * amp * 0.35
    return (whoosh + tone)[:n]


def horn(f1, f2, dur, grit=1.0):
    x = osc("square", f1, dur, 0.45) + osc("square", f2, dur, 0.45)
    x = lowpass(x, 2200) * env_adsr(int(dur * SR), 0.01, 0.05, 0.85, 0.05)
    return soft_clip(x * grit, 1.5) * 0.5


def sfx_lane_warning():
    out = np.zeros(int(0.32 * SR))
    for i in range(2):
        b = osc("square", 1320, 0.09, 0.5) * env_adsr(int(0.09 * SR), 0.002, 0.02, 0.8, 0.02)
        place(out, lowpass(b, 5000) * 0.35, i * 0.15)
    return out


def sfx_alarm():
    d = 1.2
    t = t_axis(d)
    f = 700 + 300 * np.sin(2 * np.pi * 2.5 * t)
    x = osc("saw", f, d) * env_adsr(int(d * SR), 0.02, 0.05, 0.9, 0.1)
    return lowpass(x, 3000) * 0.45


def sfx_crumble():
    d = 1.3
    out = np.zeros(int(d * SR))
    for _ in range(45):
        start = rng.uniform(0, d - 0.15)
        g = lowpass(noise(0.08), rng.uniform(600, 2500)) * env_exp(int(0.08 * SR), rng.uniform(0.01, 0.03))
        place(out, g * rng.uniform(0.3, 1.0), start)
    rumble = lowpass(noise(d), 150) * env_adsr(int(d * SR), 0.05, 0.3, 0.6, 0.6)
    return out * 0.7 + rumble * 1.5


def brass(freq, dur, vib=0.0, bright=2500):
    t = t_axis(dur)
    f = freq * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.3, 0, 1))
    x = osc("saw", f, dur) + 0.5 * osc("saw", f * 1.005, dur)
    x = sweep_filter(x, 600, bright, "low", 16) * env_adsr(int(dur * SR), 0.03, 0.1, 0.8, 0.12)
    return x


def sfx_sad_trombone():
    out = np.zeros(int(2.4 * SR))
    notes = [(0.0, 0.35, 59), (0.4, 0.35, 58), (0.8, 0.35, 57), (1.2, 1.1, 56)]
    for start, dur, m in notes:
        place(out, brass(mtof(m - 12), dur, vib=0.025 if dur > 1 else 0, bright=1500) * 0.5, start)
    return reverb(out, 0.2)[: len(out)]


def sfx_fanfare():
    out = np.zeros(int(2.8 * SR))
    seq = [(0.0, 0.14, 72), (0.15, 0.14, 76), (0.3, 0.14, 79), (0.45, 0.5, 84), (1.0, 0.14, 79), (1.15, 1.3, 84)]
    for start, dur, m in seq:
        place(out, brass(mtof(m), dur, vib=0.01, bright=4000) * 0.35, start)
    for m in (60, 64, 67):
        place(out, brass(mtof(m), 1.4, bright=2000) * 0.25, 1.15)
    for i in range(6):
        place(out, bell(mtof(96 + (i % 3) * 4), 0.6, 1.0) * 0.15, 1.15 + i * 0.08)
    return reverb(out, 0.25)[: len(out)]


def sfx_knockout():
    out = np.zeros(int(0.8 * SR))
    place(out, bell(1318.5, 0.6) * 0.6, 0)
    place(out, bell(1975.5, 0.7) * 0.6, 0.08)
    place(out, 0.3 * sweep_filter(noise(0.4), 500, 6000, "low") * env_adsr(int(0.4 * SR), 0.1, 0.1, 0.4, 0.2), 0)
    return out


def sfx_sudden_death():
    d = 1.6
    out = np.zeros(int(d * SR))
    hit = osc("sine", sweep(90, 35, 1.0), 1.0) * env_exp(int(1.0 * SR), 0.4)
    place(out, hit, 0)
    place(out, lowpass(noise(0.6), 1200) * env_exp(int(0.6 * SR), 0.15) * 0.6, 0)
    for m in (38, 45, 50):
        place(out, lowpass(osc("saw", mtof(m), 1.4), 900) * env_adsr(int(1.4 * SR), 0.01, 0.3, 0.5, 0.6) * 0.25, 0)
    return soft_clip(reverb(out, 0.3)[: len(out)], 1.3)


def sfx_sparkle():
    out = np.zeros(int(0.9 * SR))
    for i, m in enumerate((88, 91, 95, 100, 103)):
        place(out, bell(mtof(m), 0.45, 0.8) * 0.35, i * 0.05)
    return reverb(out, 0.3)[: len(out)]


def sfx_plop():
    d = 0.25
    return osc("sine", sweep(900, 150, d), d) * env_exp(int(d * SR), 0.06)


def sfx_firework():
    out = np.zeros(int(1.6 * SR))
    whistle = osc("sine", sweep(900, 2200, 0.6), 0.6) * env_adsr(int(0.6 * SR), 0.05, 0.1, 0.6, 0.1) * 0.25
    place(out, whistle, 0)
    bang = lowpass(noise(0.4), 3000) * env_exp(int(0.4 * SR), 0.08)
    place(out, bang, 0.62)
    for _ in range(25):
        c = highpass(noise(0.02), 3000) * env_exp(int(0.02 * SR), 0.004)
        place(out, c * rng.uniform(0.1, 0.4), rng.uniform(0.75, 1.5))
    return out


def sfx_confetti():
    out = np.zeros(int(1.0 * SR))
    place(out, osc("sine", sweep(600, 200, 0.08), 0.08) * env_exp(int(0.08 * SR), 0.03), 0)
    place(out, highpass(noise(0.05), 1500) * env_exp(int(0.05 * SR), 0.01), 0)
    for _ in range(30):
        c = highpass(noise(0.015), 4000) * env_exp(int(0.015 * SR), 0.003)
        place(out, c * rng.uniform(0.05, 0.3), rng.uniform(0.05, 0.9))
    return out


def sfx_countdown_final():
    d = 0.3
    x = osc("square", 1320, d, 0.3) * env_adsr(int(d * SR), 0.002, 0.05, 0.5, 0.15)
    return lowpass(x, 5000) * 0.6


SFX = [
    # name, function, volume, looped
    ("UiClick", sfx_ui_click, 0.6, False),
    ("UiHover", sfx_ui_hover, 0.25, False),
    ("UiOpen", sfx_ui_open, 0.5, False),
    ("UiClose", sfx_ui_close, 0.5, False),
    ("Vote", sfx_vote, 0.5, False),
    ("Tick", sfx_tick, 0.5, False),
    ("TickFinal", sfx_countdown_final, 0.6, False),
    ("Go", sfx_go, 0.6, False),
    ("Whistle", sfx_whistle, 0.5, False),
    ("Coin", sfx_coin, 0.5, False),
    ("Purchase", sfx_purchase, 0.6, False),
    ("Equip", sfx_equip, 0.5, False),
    ("Error", sfx_error, 0.5, False),
    ("Toast", sfx_toast, 0.35, False),
    ("EggShoot", sfx_egg_shoot, 0.6, False),
    ("EggHit", sfx_egg_hit, 0.7, False),
    ("Squash", sfx_squash, 0.9, False),
    ("Feathers", sfx_feathers, 0.5, False),
    ("Jump", sfx_jump, 0.3, False),
    ("Land", sfx_land, 0.3, False),
    ("Glide", sfx_glide, 0.4, False),
    ("Wind", sfx_wind_loop, 0.25, True),
    ("Boing", sfx_boing, 0.6, False),
    ("Bawk", lambda: sfx_bawk(False), 0.7, False),
    ("BawkLong", lambda: sfx_bawk(True), 0.7, False),
    ("CarEngine", sfx_car_engine_loop, 0.5, True),
    ("CarWhoosh", sfx_car_whoosh, 0.8, False),
    ("CarHorn", lambda: horn(392, 494, 0.45), 0.5, False),
    ("RageHorn", lambda: horn(311, 370, 0.9, 2.5), 0.7, False),
    ("LaneWarning", sfx_lane_warning, 0.3, False),
    ("Alarm", sfx_alarm, 0.5, False),
    ("Crumble", sfx_crumble, 0.7, False),
    ("Eliminated", sfx_sad_trombone, 0.6, False),
    ("Fanfare", sfx_fanfare, 0.7, False),
    ("Knockout", sfx_knockout, 0.6, False),
    ("SuddenDeath", sfx_sudden_death, 0.8, False),
    ("Sparkle", sfx_sparkle, 0.5, False),
    ("Plop", sfx_plop, 0.6, False),
    ("Firework", sfx_firework, 0.6, False),
    ("Confetti", sfx_confetti, 0.6, False),
]


# --- music ---------------------------------------------------------------------------------

def kick(dur=0.35):
    x = osc("sine", sweep(150, 45, dur), dur) * env_exp(int(dur * SR), 0.12)
    x[: int(0.003 * SR)] += highpass(noise(0.003), 3000) * 0.5
    return x


def snare(dur=0.22):
    n = int(dur * SR)
    body = osc("tri", sweep(240, 160, dur), dur) * env_exp(n, 0.05)
    rattle = bandpass(noise(dur), 1500, 9000) * env_exp(n, 0.07)
    return body * 0.6 + rattle * 0.8


def clap(dur=0.25):
    out = np.zeros(int(dur * SR))
    for i in range(3):
        place(out, bandpass(noise(0.02), 900, 4000) * env_exp(int(0.02 * SR), 0.006), i * 0.01)
    place(out, bandpass(noise(0.2), 900, 4000) * env_exp(int(0.2 * SR), 0.05), 0.03)
    return out


def hat(dur=0.05, open_=False):
    d = 0.25 if open_ else dur
    return highpass(noise(d), 7000) * env_exp(int(d * SR), 0.08 if open_ else 0.015)


def pluck(freq, dur, bright=3000):
    x = osc("square", freq, dur, 0.25) * 0.6 + osc("tri", freq * 2, dur) * 0.4
    return lowpass(x, bright) * env_exp(int(dur * SR), dur * 0.35)


def lead(freq, dur, kind="square"):
    t = t_axis(dur)
    f = freq * (1 + 0.006 * np.sin(2 * np.pi * 5 * t) * np.clip(t / 0.2, 0, 1))
    x = osc(kind, f, dur, 0.35) * 0.5 + osc(kind, f * 1.004, dur, 0.35) * 0.5
    return lowpass(x, 3500) * env_adsr(int(dur * SR), 0.01, 0.08, 0.7, min(0.08, dur * 0.4))


def bass(freq, dur, kind="saw", cutoff=700):
    x = osc(kind, freq, dur) * 0.7 + osc("sine", freq / 2, dur) * 0.5
    return lowpass(x, cutoff) * env_adsr(int(dur * SR), 0.005, 0.06, 0.8, 0.03)


def pad(freqs, dur):
    x = sum(osc("saw", f, dur) + osc("saw", f * 1.007, dur) for f in freqs) / len(freqs)
    return lowpass(x, 1400) * env_adsr(int(dur * SR), 0.15, 0.2, 0.7, 0.3) * 0.5


CHORDS = {
    "C": (60, 64, 67), "Am": (57, 60, 64), "F": (53, 57, 60), "G": (55, 59, 62),
    "Dm": (50, 53, 57), "Em": (52, 55, 59), "E": (52, 56, 59), "Bb": (58, 62, 65),
    "A": (57, 61, 64), "Gm": (55, 58, 62),
}


def render_song(bpm, bars, chords, melody, style, seconds_tail=2.0):
    """chords: chord name per bar. melody: list of (beat, length_in_beats, midi)."""
    beat = 60 / bpm
    loop_len = bars * 4 * beat
    total = loop_len + seconds_tail
    drums = np.zeros(int(total * SR))
    bassline = np.zeros_like(drums)
    harmony = np.zeros_like(drums)
    mel = np.zeros_like(drums)

    for bar in range(bars):
        t0 = bar * 4 * beat
        chord = CHORDS[chords[bar % len(chords)]]
        root = chord[0] - 24
        if style == "lobby":
            for b in range(4):
                place(drums, kick() * (0.9 if b % 2 == 0 else 0.0), t0 + b * beat)
                if b % 2 == 1:
                    place(drums, clap() * 0.55, t0 + b * beat)
            for e in range(8):
                swing = 0.08 * beat if e % 2 == 1 else 0
                place(drums, hat() * (0.25 if e % 2 else 0.18), t0 + e * beat / 2 + swing)
            for e, off in enumerate((0, 1.5, 2, 3, 3.5)):
                note = root + (12 if e in (2, 4) else 0)
                place(bassline, bass(mtof(note), beat * 0.45, "tri", 500), t0 + off * beat)
            for e in range(4):  # off-beat chord plucks
                for m in chord:
                    place(harmony, pluck(mtof(m + 12), beat * 0.5, 2500) * 0.18, t0 + (e + 0.5) * beat)
        elif style == "round":
            for b in range(4):
                place(drums, kick(), t0 + b * beat)
                if b % 2 == 1:
                    place(drums, snare() * 0.8, t0 + b * beat)
            for s in range(16):
                place(drums, hat(open_=(s % 4 == 2)) * (0.3 if s % 2 else 0.2), t0 + s * beat / 4)
            for e in range(8):
                note = root + (12 if e % 2 else 0)
                place(bassline, bass(mtof(note), beat * 0.45, "saw", 900), t0 + e * beat / 2)
            place(harmony, pad([mtof(m) for m in chord], 4 * beat) * 0.6, t0)
        else:  # sudden death
            for b in range(4):
                place(drums, kick(), t0 + b * beat)
                place(drums, kick() * 0.6, t0 + (b + 0.75) * beat)
                if b % 2 == 1:
                    place(drums, snare(), t0 + b * beat)
            for s in range(16):
                place(drums, hat() * 0.35, t0 + s * beat / 4)
            for s in range(16):
                note = root + (12 if s % 4 == 3 else 0)
                place(bassline, bass(mtof(note), beat * 0.22, "saw", 1300), t0 + s * beat / 4)
            place(harmony, pad([mtof(m) for m in chord], 4 * beat) * 0.5, t0)

    for b, length, m in melody:
        if style == "lobby":
            place(mel, pluck(mtof(m), length * beat + 0.2, 3500) * 0.5, b * beat)
        else:
            place(mel, lead(mtof(m), length * beat * 0.95, "square") * 0.35, b * beat)

    mel = reverb(mel, 0.3)[: len(drums)]
    harmony = reverb(harmony, 0.25)[: len(drums)]
    mix = drums * 0.8 + bassline * 0.9 + harmony + mel
    # Wrap the tail into the start so the loop point is seamless.
    n_loop = int(loop_len * SR)
    out = mix[:n_loop].copy()
    tail = mix[n_loop:]
    out[: len(tail)] += tail
    return normalize(soft_clip(normalize(out) * 1.3, 1.1), 0.9)


def song_lobby():
    chords = ["C", "Am", "F", "G"]
    phrase_a = [(0, 0.5, 76), (0.5, 0.5, 79), (1, 1, 81), (2.5, 0.5, 79), (3, 1, 76),
                (4, 0.5, 74), (4.5, 0.5, 76), (5, 1, 72), (6.5, 1.5, 69),
                (8, 0.5, 72), (8.5, 0.5, 74), (9, 1, 77), (10.5, 0.5, 76), (11, 1, 74),
                (12, 1, 71), (13, 0.5, 74), (13.5, 0.5, 76), (14, 2, 79)]
    phrase_b = [(0, 0.5, 79), (0.5, 0.5, 81), (1, 1, 84), (2, 0.5, 83), (2.5, 0.5, 81), (3, 1, 79),
                (4, 0.5, 76), (4.5, 0.5, 79), (5, 1, 81), (6, 2, 76),
                (8, 0.5, 77), (8.5, 0.5, 79), (9, 1, 81), (10, 0.5, 79), (10.5, 0.5, 77), (11, 1, 76),
                (12, 0.5, 74), (12.5, 0.5, 76), (13, 1, 74), (14, 2, 72)]
    melody = [(b, l, m) for b, l, m in phrase_a] + [(b + 16, l, m) for b, l, m in phrase_b]
    melody += [(b + 32, l, m) for b, l, m in phrase_a] + [(b + 48, l, m) for b, l, m in phrase_b]
    return render_song(108, 16, chords, melody, "lobby")


def song_round():
    chords = ["Am", "F", "C", "G"]
    riff = [(0, 0.5, 69), (0.5, 0.5, 72), (1, 0.5, 76), (1.5, 0.5, 74), (2, 0.5, 72), (2.5, 0.5, 69),
            (3, 1, 71),
            (4, 0.5, 72), (4.5, 0.5, 74), (5, 0.5, 77), (5.5, 0.5, 76), (6, 1, 74), (7, 1, 72),
            (8, 0.5, 72), (8.5, 0.5, 76), (9, 0.5, 79), (9.5, 0.5, 76), (10, 0.5, 74), (10.5, 0.5, 72),
            (11, 1, 76),
            (12, 0.5, 74), (12.5, 0.5, 71), (13, 0.5, 67), (13.5, 0.5, 71), (14, 2, 74)]
    hook = [(0, 1, 81), (1, 0.5, 79), (1.5, 0.5, 76), (2, 1, 77), (3, 1, 76),
            (4, 1, 77), (5, 0.5, 76), (5.5, 0.5, 74), (6, 2, 72),
            (8, 1, 76), (9, 0.5, 77), (9.5, 0.5, 79), (10, 1, 84), (11, 1, 83),
            (12, 1, 79), (13, 1, 74), (14, 2, 71)]
    melody = riff + [(b + 16, l, m) for b, l, m in riff]
    melody += [(b + 32, l, m) for b, l, m in hook] + [(b + 48, l, m) for b, l, m in hook]
    return render_song(150, 16, chords, melody, "round")


def song_sudden_death():
    chords = ["Dm", "Bb", "Gm", "A"]
    motif = [(0, 0.5, 74), (0.5, 0.5, 74), (1, 0.5, 77), (1.5, 0.5, 74), (2, 0.5, 81), (2.5, 0.5, 79),
             (3, 1, 77),
             (4, 0.5, 74), (4.5, 0.5, 74), (5, 0.5, 77), (5.5, 0.5, 74), (6, 0.5, 82), (6.5, 0.5, 81),
             (7, 1, 77),
             (8, 0.5, 79), (8.5, 0.5, 79), (9, 0.5, 82), (9.5, 0.5, 79), (10, 1, 86), (11, 1, 82),
             (12, 0.5, 81), (12.5, 0.5, 79), (13, 0.5, 77), (13.5, 0.5, 76), (14, 2, 73)]
    melody = motif + [(b + 16, l, m + (0 if b < 12 else 0)) for b, l, m in motif]
    return render_song(172, 8, chords, melody, "suddendeath")


# --- output --------------------------------------------------------------------------------

def write_ogg(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "6", path],
                   check=True)
    os.remove(wav_path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    gap = 0.35
    pieces, regions = [], []
    cursor = 0.25
    pieces.append(np.zeros(int(cursor * SR)))
    for name, fn, volume, looped in SFX:
        x = normalize(fn(), 0.9)
        # Fade the very end so regions never click when they stop.
        if not looped:
            fade = min(len(x), int(0.01 * SR))
            x[-fade:] *= np.linspace(1, 0, fade)
        regions.append((name, cursor, len(x) / SR, volume, looped))
        pieces.append(x)
        pieces.append(np.zeros(int(gap * SR)))
        cursor += len(x) / SR + gap
    sfx = np.concatenate(pieces)
    write_ogg(os.path.join(OUT_DIR, "Sfx.ogg"), sfx)

    songs = [("MusicLobby", song_lobby), ("MusicRound", song_round), ("MusicSuddenDeath", song_sudden_death)]
    lengths = {}
    for name, fn in songs:
        x = fn()
        lengths[name] = len(x) / SR
        write_ogg(os.path.join(OUT_DIR, name + ".ogg"), x)
        print(f"{name}: {len(x) / SR:.1f}s")

    lines = [
        "--!strict",
        "-- GENERATED by tools/audio/make_audio.py - do not edit by hand.",
        "-- Where each sound effect sits inside assets/audio/Sfx.ogg (seconds).",
        "",
        "export type Region = { start: number, length: number, volume: number, looped: boolean }",
        "",
        "local regions: { [string]: Region } = {",
    ]
    for name, start, length, volume, looped in regions:
        lines.append(
            f"\t{name} = {{ start = {start:.3f}, length = {length:.3f}, volume = {volume}, looped = {str(looped).lower()} }},")
    lines += ["}", "", "return regions", ""]
    with open(OUT_LUAU, "w") as f:
        f.write("\n".join(lines))
    print(f"Sfx.ogg: {len(sfx) / SR:.1f}s, {len(regions)} sounds")


if __name__ == "__main__":
    main()
