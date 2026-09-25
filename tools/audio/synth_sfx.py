#!/usr/bin/env python3
"""Процедурный синтез звуков Glow in the Dark (DS §06) → src/assets/audio/{sfx,music}/*.ogg.

Звуки воспроизводимы: одинаковый seed даёт одинаковый результат. Это рабочие звуки V1, пока их не заменит
саунд-дизайнер; имена файлов — контракт configs/audio.json, так что замена — просто подмена .ogg.

Запуск: python3 tools/audio/synth_sfx.py   (нужны numpy и ffmpeg с libvorbis)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_SFX = os.path.join(ROOT, "src", "assets", "audio", "sfx")
OUT_MUSIC = os.path.join(ROOT, "src", "assets", "audio", "music")
rng = np.random.default_rng(7)


# --- примитивы -----------------------------------------------------------------

def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.005, decay=None, release_pow=3.0):
    """Атака + экспоненциальный спад до конца."""
    n = int(SR * dur)
    x = np.linspace(0, 1, n)
    a = np.clip(np.arange(n) / max(1, int(SR * attack)), 0, 1)
    d = (1 - x) ** release_pow if decay is None else np.exp(-np.arange(n) / (SR * decay))
    return a * d


def sine(freq, dur, phase=0.0):
    tt = t(dur)
    f = np.broadcast_to(freq, tt.shape) if np.ndim(freq) else np.full(tt.shape, float(freq))
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    """Одно-полюсный ФНЧ; cutoff может быть массивом (развёртка)."""
    c = np.broadcast_to(cutoff, x.shape) if np.ndim(cutoff) else np.full(x.shape, float(cutoff))
    a = 1 - np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bell(freq, dur, decay=0.25):
    """Колокольчик: основной тон + негармонические обертоны."""
    s = sine(freq, dur) + 0.5 * sine(freq * 2.76, dur) * env(dur, decay=decay * 0.5) + 0.25 * sine(freq * 5.4, dur) * env(dur, decay=decay * 0.25)
    return s * env(dur, attack=0.002, decay=decay)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, offset_s, total_s=None):
    pad = np.zeros(int(SR * offset_s))
    y = np.concatenate([pad, x])
    if total_s is not None:
        y = np.pad(y, (0, max(0, int(SR * total_s) - len(y))))
    return y


def norm(x, peak=0.89):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def save(x, name, folder=OUT_SFX, fade_ms=4, loop=False):
    os.makedirs(folder, exist_ok=True)
    x = norm(x)
    if not loop:
        f = int(SR * fade_ms / 1000)
        x[-f:] *= np.linspace(1, 0, f)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = os.path.join(folder, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    os.remove(path)
    print("wrote", os.path.relpath(out, ROOT), f"{len(x) / SR:.2f}s")


# --- SFX (DS §06) ----------------------------------------------------------------

def spark():
    # «дзынь»; серия +1 полутон за искру делает движок (pitch_scale).
    return bell(midi(81), 0.35, decay=0.12)


def fuel():
    # вдох → низкий бум + блестящий хвост
    inhale = lowpass(noise(0.28), np.linspace(400, 3000, int(SR * 0.28))) * np.linspace(0, 1, int(SR * 0.28)) ** 2
    boom = sine(np.linspace(90, 38, int(SR * 0.7)), 0.7) * env(0.7, attack=0.004, decay=0.22)
    tail = mix(*[at(bell(midi(n), 0.6, decay=0.2) * 0.25, 0.3 + i * 0.05) for i, n in enumerate([88, 91, 95, 100])])
    return mix(inhale * 0.5, at(boom, 0.26), at(tail, 0.0))


def light_burst():
    whoosh = highpass(noise(0.5), 800) * env(0.5, attack=0.02, decay=0.15)
    boom = sine(np.linspace(120, 30, int(SR * 0.9)), 0.9) * env(0.9, attack=0.003, decay=0.3)
    sparkle = mix(*[at(bell(midi(n), 0.5, decay=0.15) * 0.2, 0.05 + i * 0.03) for i, n in enumerate([84, 88, 91, 96, 100])])
    return mix(boom, whoosh * 0.6, sparkle)


def burn():
    # короткое «пшш»; высота по размеру врага — pitch_scale в движке
    x = highpass(noise(0.22), 1500)
    return lowpass(x, np.linspace(9000, 2500, len(x))) * env(0.22, attack=0.004, decay=0.06)


def player_hit():
    thud = sine(np.linspace(110, 45, int(SR * 0.25)), 0.25) * env(0.25, attack=0.002, decay=0.07)
    click = lowpass(noise(0.03), 3000) * env(0.03, decay=0.008)
    return mix(thud, click * 0.5)


def heartbeat():
    beat = sine(np.linspace(70, 40, int(SR * 0.16)), 0.16) * env(0.16, attack=0.003, decay=0.05)
    return mix(beat, at(beat * 0.7, 0.24), np.zeros(int(SR * 1.2)))


def level_up():
    notes = [60, 64, 67, 72]
    arp = mix(*[at(bell(midi(n + 12), 0.9, decay=0.35) * 0.6, i * 0.06) for i, n in enumerate(notes)])
    pad = sum(sine(midi(n), 1.0) for n in notes) * env(1.0, attack=0.05, decay=0.4) * 0.15
    flip = sine(np.linspace(600, 2400, int(SR * 0.15)), 0.15) * env(0.15, decay=0.05) * 0.3
    return mix(arp, pad, flip)


def card_pick():
    return mix(bell(midi(76), 0.3, decay=0.08), at(bell(midi(83), 0.3, decay=0.08) * 0.6, 0.04))


def beacon_tick():
    return bell(midi(88), 0.18, decay=0.05)


def beacon_tier():
    gliss = sine(np.linspace(midi(60), midi(84), int(SR * 0.8)), 0.8) * env(0.8, attack=0.05, decay=0.5) * 0.4
    bells = mix(at(bell(midi(84), 1.6, decay=0.6), 0.7), at(bell(midi(79), 1.4, decay=0.5) * 0.5, 0.75))
    return mix(gliss, bells)


def beacon_milestone():
    chord = [57, 64, 69, 72, 76]
    choir = np.zeros(int(SR * 3.0))
    for n in chord:
        for det in (-0.12, 0.0, 0.11):
            f = midi(n + det)
            saw = 2 * ((np.arange(len(choir)) * f / SR) % 1) - 1
            choir += saw
    choir = lowpass(choir, 1400) * env(3.0, attack=0.6, decay=1.2) * 0.12
    return mix(choir, at(bell(midi(81), 2.5, decay=0.9), 0.4), at(bell(midi(88), 2.0, decay=0.7) * 0.4, 0.55))


def iap_crystal():
    # уникальный «хрустальный» аккорд — только покупки за деньги
    notes = [84, 88, 91, 95, 98]
    return mix(*[at(bell(midi(n), 1.6, decay=0.7) * (0.8 - i * 0.1), i * 0.035) for i, n in enumerate(notes)])


def ui_click():
    return lowpass(noise(0.03), 5000) * env(0.03, decay=0.006) * 0.6 + sine(1800, 0.03) * env(0.03, decay=0.005) * 0.3


def ui_disabled():
    return sine(np.linspace(180, 120, int(SR * 0.08)), 0.08) * env(0.08, attack=0.002, decay=0.02)


def whisper_eyes():
    x = lowpass(noise(0.9), 1200) * env(0.9, attack=0.4, decay=0.2)
    return x + sine(np.linspace(220, 180, int(SR * 0.9)), 0.9) * env(0.9, attack=0.4, decay=0.2) * 0.05


def reaper_windup():
    f = np.linspace(200, 700, int(SR * 0.7))
    scrape = highpass(noise(0.7), 1200) * np.linspace(0.2, 1, int(SR * 0.7))
    return mix(sine(f, 0.7) * 0.3 * np.linspace(0, 1, len(f)), scrape * 0.4)


def devourer_bite():
    crunch = lowpass(noise(0.18), 2500) * env(0.18, decay=0.04)
    low = sine(np.linspace(80, 40, int(SR * 0.2)), 0.2) * env(0.2, decay=0.06)
    return mix(crunch, low)


def extinguisher_hum():
    dur = 1.2
    f = np.linspace(55, 110, int(SR * dur))
    x = sine(f, dur) + 0.5 * sine(f * 2, dur) + 0.3 * sine(f * 3.01, dur)
    return x * np.linspace(0.05, 1, int(SR * dur)) ** 1.5


def chest_open():
    thunk = mix(sine(np.linspace(160, 70, int(SR * 0.2)), 0.2) * env(0.2, decay=0.05), lowpass(noise(0.05), 2000) * env(0.05, decay=0.01))
    sparkle = mix(*[at(bell(midi(n), 0.6, decay=0.2) * 0.3, 0.12 + i * 0.05) for i, n in enumerate([79, 84, 88, 91])])
    return mix(thunk, sparkle)


def item_merge():
    whoosh = lowpass(noise(0.6), np.linspace(300, 6000, int(SR * 0.6))) * np.linspace(0, 1, int(SR * 0.6)) ** 2 * 0.5
    return mix(whoosh, at(bell(midi(84), 1.0, decay=0.4), 0.58), at(bell(midi(91), 1.0, decay=0.35) * 0.5, 0.6))


def revive():
    swell = sum(sine(midi(n), 1.2) for n in (60, 67, 72, 76)) * env(1.2, attack=0.5, decay=0.4) * 0.2
    return mix(swell, at(bell(midi(84), 1.0, decay=0.4), 0.45))


# --- музыка (циклы 16 долей, 90 BPM) ---------------------------------------------

BEAT = 60 / 90
LOOP = BEAT * 16


def pad(notes, dur, cutoff):
    x = np.zeros(int(SR * dur))
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * np.arange(len(x)) / SR)
    for n in notes:
        for det in (-0.08, 0.07):
            f = midi(n + det)
            x += 2 * ((np.arange(len(x)) * f / SR) % 1) - 1
    x = lowpass(x, cutoff) * (0.7 + 0.3 * lfo)
    return x


def seamless(x, xfade=0.5):
    """Бесшовный луп: хвост подмешивается в начало."""
    f = int(SR * xfade)
    head = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    return np.concatenate([head, x[f:-f]])


def music_run_base():
    # Am — F — C — G, по 4 доли; тёмный пэд + пульсирующий бас
    chords = [[45, 57, 60, 64], [41, 57, 60, 65], [48, 55, 60, 64], [43, 55, 59, 62]]
    out = np.zeros(int(SR * (LOOP + 0.5)))
    for i, ch in enumerate(chords):
        seg = pad(ch[1:], BEAT * 4 + 0.5, 900) * 0.25
        bass = np.zeros(len(seg))
        for b in range(8):
            hit = sine(midi(ch[0]), BEAT / 2) * env(BEAT / 2, attack=0.01, decay=0.12) * 0.5
            bass[int(b * BEAT / 2 * SR): int(b * BEAT / 2 * SR) + len(hit)] += hit[: len(bass) - int(b * BEAT / 2 * SR)]
        seg = seg + bass
        s = int(i * BEAT * 4 * SR)
        out[s: s + len(seg)] += seg[: len(out) - s]
    return seamless(out)


def music_run_drums():
    out = np.zeros(int(SR * (LOOP + 0.5)))
    kick = sine(np.linspace(120, 45, int(SR * 0.2)), 0.2) * env(0.2, decay=0.06)
    hat = highpass(noise(0.05), 6000) * env(0.05, decay=0.01) * 0.3
    snare = (highpass(noise(0.15), 1500) * 0.6 + sine(190, 0.15) * 0.4) * env(0.15, decay=0.04)
    for b in range(16):
        s = int(b * BEAT * SR)
        out[s: s + len(kick)] += kick if b % 2 == 0 else 0
        if b % 4 == 2:
            out[s: s + len(snare)] += snare * 0.6
        h = int((b + 0.5) * BEAT * SR)
        out[h: h + len(hat)] += hat
    return seamless(out)


def music_reward_resolve():
    # разрешение аккордом на фазе Награды
    return mix(pad([57, 61, 64, 69], 3.0, 1800) * env(3.0, attack=0.3, decay=1.0) * 0.3, at(bell(midi(81), 2.5, decay=0.9) * 0.5, 0.2))


def music_hub():
    chords = [[48, 60, 64, 67], [45, 57, 60, 64], [41, 57, 60, 65], [43, 55, 59, 62]]
    out = np.zeros(int(SR * (LOOP * 2 + 0.5)))
    for i, ch in enumerate(chords):
        seg = pad(ch, BEAT * 8 + 0.5, 1200) * 0.3
        s = int(i * BEAT * 8 * SR)
        out[s: s + len(seg)] += seg[: len(out) - s]
        for k in range(4):
            note = ch[1 + (k % 3)] + 24
            b = at(bell(midi(note), 2.0, decay=0.8) * 0.12, BEAT * 2 * k)
            e = min(len(out) - s, len(b))
            out[s: s + e] += b[:e]
    return seamless(out)


SFX = {
    "spark": spark, "fuel": fuel, "light_burst": light_burst, "burn": burn, "player_hit": player_hit,
    "heartbeat": heartbeat, "level_up": level_up, "card_pick": card_pick, "beacon_tick": beacon_tick,
    "beacon_tier": beacon_tier, "beacon_milestone": beacon_milestone, "iap_crystal": iap_crystal,
    "ui_click": ui_click, "ui_disabled": ui_disabled, "whisper_eyes": whisper_eyes, "reaper_windup": reaper_windup,
    "devourer_bite": devourer_bite, "extinguisher_hum": extinguisher_hum, "chest_open": chest_open,
    "item_merge": item_merge, "revive": revive,
}
MUSIC = {
    "run_base": music_run_base, "run_drums": music_run_drums, "reward_resolve": music_reward_resolve, "hub": music_hub,
}

if __name__ == "__main__":
    for name, fn in SFX.items():
        save(fn(), name)
    for name, fn in MUSIC.items():
        save(fn(), name, OUT_MUSIC, loop=name != "reward_resolve")
