#!/usr/bin/env python3
"""Звук Glow in the Dark V1 (DS §06) → src/assets/audio/{sfx,music}/*.ogg.

Всё процедурное и воспроизводимое (фиксированный seed). Имена файлов — контракт configs/audio.json.

Инструменты: band-limited суперпила (polyBLEP), FM-колокола, струна Karplus–Strong («войлочное пианино»),
формантный хор, шумовые текстуры через фильтры; пространство — свёрточный ревер на синтетическом IR.

Мастеринг (tools/audio/README в docstring):
  • срез DC / инфранизов (ВЧ-фильтр 25 Гц), фейды 3 мс / 15 мс — без щелчков на старте и в конце;
  • SFX — нормализация по «активному» RMS к -16 dBFS (смесь задают volume_db в configs/audio.json);
  • музыка — интегральная громкость -18 LUFS (ffmpeg ebur128), стингер -16 LUFS;
  • true-peak ≤ -1 dBTP (пик по 4× передискретизации, мягкий лимитер);
  • лупы бесшовные: хвост реверба за точкой лупа заворачивается в начало (круговая свёртка);
  • тональность — ре: хаб в ре мажоре (лидийская окраска), забег в ре миноре.

Запуск: python3 tools/audio/synth_sfx.py [имя ...]   (нужны numpy, scipy и ffmpeg с libvorbis)
"""
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_SFX = os.path.join(ROOT, "src", "assets", "audio", "sfx")
OUT_MUSIC = os.path.join(ROOT, "src", "assets", "audio", "music")
rng = np.random.default_rng(7)

SFX_RMS_DB = -16.0
MUSIC_LUFS = -18.0
STINGER_LUFS = -16.0
TRUE_PEAK_DB = -1.0


# --- базовые примитивы ------------------------------------------------------------

def n_of(dur):
    return int(round(SR * dur))


def tt(dur):
    return np.arange(n_of(dur)) / SR


def midi(n):
    return 440.0 * 2 ** ((np.asarray(n, dtype=float) - 69) / 12)


def stereo(x, pan=0.0):
    """Моно → стерео с равномощной панорамой (-1 … 1)."""
    if x.ndim == 2:
        return x
    a = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def place(out, x, at_s, gain=1.0):
    """Кладёт x (моно или стерео) в out со сдвигом at_s (обрезая по концу)."""
    x = stereo(x) if out.ndim == 2 else x
    # Страховка от щелчков: конец каждого фрагмента мягко гасится (6 мс), начало — 1 мс.
    x = x.copy()
    fo, fi = min(len(x), n_of(0.006)), min(len(x), n_of(0.001))
    ramp_o, ramp_i = np.linspace(1, 0, fo) ** 2, np.linspace(0, 1, fi)
    x[-fo:] *= ramp_o[:, None] if x.ndim == 2 else ramp_o
    x[:fi] *= ramp_i[:, None] if x.ndim == 2 else ramp_i
    s = n_of(at_s)
    if s >= len(out):
        return out
    e = min(len(out), s + len(x))
    out[s:e] += x[: e - s] * gain
    return out


def canvas(dur, ch=2):
    return np.zeros((n_of(dur), ch)) if ch == 2 else np.zeros(n_of(dur))


def adsr(dur, a=0.005, d=0.1, s=0.0, r=0.05, curve=3.0):
    """Огибающая с экспоненциальным спадом; s — уровень сустейна (0 — перкуссия)."""
    n = n_of(dur)
    t = np.arange(n) / SR
    env = np.where(t < a, (t / max(a, 1e-6)), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6) * curve / 3.0))
    rel = n_of(r)
    if rel > 0 and rel < n:
        env[-rel:] *= np.linspace(1, 0, rel) ** 1.5
    return env


def exp_env(dur, decay, attack=0.002, release=0.012):
    """Атака + экспоненциальный спад; релиз в конце доводит до нуля — нота не обрывается щелчком."""
    t = tt(dur)
    env = np.clip(t / attack, 0, 1) * np.exp(-t / decay)
    r = min(len(env), n_of(release))
    if r > 0:
        env[-r:] *= np.linspace(1, 0, r) ** 2
    return env


def noise(dur, color="white"):
    x = rng.standard_normal(n_of(dur))
    if color == "pink":
        # Фильтр Пола Келлета (приближение 1/f)
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        x = signal.lfilter(b, a, x) * 4
    return x


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, min(hi, SR / 2 - 100)], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def lp(x, fc, order=2):
    sos = signal.butter(order, min(fc, SR / 2 - 100), btype="lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def hp(x, fc, order=2):
    sos = signal.butter(order, fc, btype="highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def sweep_lp(x, f0, f1, q=0.7):
    """ФНЧ с экспоненциальной развёрткой среза f0 → f1: state-variable фильтр Чемберлина, посэмплово."""
    n = len(x)
    fc = np.geomspace(max(f0, 20), max(f1, 20), n)
    f = 2 * np.sin(np.pi * np.minimum(fc, SR / 6) / SR)
    damp = 1 / max(q, 0.5)
    low = band = 0.0
    y = np.empty(n)
    for i in range(n):
        low += f[i] * band
        high = x[i] - low - damp * band
        band += f[i] * high
        y[i] = low
    return y


def sine(freq, dur, phase=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n_of(dur),))
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def poly_saw(freq, dur):
    """Band-limited пила (polyBLEP) — без алиасинга на высоких нотах."""
    n = n_of(dur)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    dt = f / SR
    phase = (np.cumsum(dt) + rng.random()) % 1.0
    y = 2 * phase - 1
    m1 = phase < dt
    t1 = phase[m1] / dt[m1]
    y[m1] -= t1 + t1 - t1 * t1 - 1
    m2 = phase > 1 - dt
    t2 = (phase[m2] - 1) / dt[m2]
    y[m2] -= t2 * t2 + t2 + t2 + 1
    return y


def supersaw(note, dur, voices=5, spread=0.12, width=0.8):
    """Стерео-суперпила: голоса расстроены и разнесены по панораме."""
    out = np.zeros((n_of(dur), 2))
    for i in range(voices):
        k = (i - (voices - 1) / 2) / max(1, (voices - 1) / 2)
        out += stereo(poly_saw(midi(note + k * spread), dur), k * width) / voices
    return out


def fm_bell(freq, dur, ratio=3.5, index=2.4, decay=0.6, bright_decay=None):
    """FM-колокол: индекс модуляции спадает быстрее амплитуды — тембр «остывает»."""
    t = tt(dur)
    bd = bright_decay or decay * 0.35
    mod = np.sin(2 * np.pi * freq * ratio * t) * index * np.exp(-t / bd)
    car = np.sin(2 * np.pi * freq * t + mod)
    return car * exp_env(dur, decay, attack=0.0015)


def glass(freq, dur, decay=0.9):
    """«Хрусталь»: аддитивные негармонические партиалы стеклянной чаши."""
    parts = [(1.0, 1.0), (2.32, 0.5), (4.25, 0.28), (6.63, 0.16), (9.38, 0.08)]
    t = tt(dur)
    x = np.zeros_like(t)
    for r, g in parts:
        x += g * np.sin(2 * np.pi * freq * r * t + rng.random() * 6.28) * np.exp(-t / (decay / (0.6 + r * 0.35)))
    r = min(len(x), n_of(0.012))
    x[-r:] *= np.linspace(1, 0, r) ** 2
    return x * np.clip(t / 0.002, 0, 1)


def ks_string(freq, dur, bright=0.5, damp=0.996):
    """Karplus–Strong: щипок/молоточек «войлочного пианино»."""
    n = n_of(dur)
    period = max(2, int(SR / freq))
    buf = lp(rng.uniform(-1, 1, period), 800 + 6000 * bright)
    out = np.zeros(n)
    idx = 0
    prev = 0.0
    for i in range(n):
        cur = buf[idx]
        out[i] = cur
        buf[idx] = damp * 0.5 * (cur + prev)
        prev = cur
        idx = (idx + 1) % period
    return out * np.clip(np.arange(n) / (SR * 0.003), 0, 1)


def felt_piano(note, dur, vel=0.8):
    f = float(midi(note))
    body = ks_string(f, dur, bright=0.25 + 0.3 * vel, damp=0.9985) + 0.3 * ks_string(f * 2.001, dur, bright=0.2, damp=0.997)
    return lp(body, 2600) * vel


def choir(notes, dur, vowel="a", attack=0.5, release=0.8):
    """Формантный хор «а / о»: пилы → банк полосовых резонаторов."""
    formants = {"a": [(800, 1.0), (1150, 0.5), (2900, 0.25)], "o": [(450, 1.0), (800, 0.45), (2830, 0.12)]}[vowel]
    src = np.zeros((n_of(dur), 2))
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * tt(dur))
    for k, note in enumerate(notes):
        for v in range(3):
            pan = (v - 1) * 0.6
            f = midi(note + (v - 1) * 0.08) * vib
            src += stereo(poly_saw(f, dur), pan)
    out = np.zeros_like(src)
    for fc, g in formants:
        out += bp(src, fc * 0.88, fc * 1.12) * g
    env = adsr(dur, a=attack, d=dur, s=1.0, r=release)
    return out * env[:, None] * 0.35 / max(1, len(notes))


# --- пространство и мастеринг -----------------------------------------------------

_IR_CACHE = {}


def reverb_ir(length=2.2, predelay=0.02, damping=4500, seed=3):
    key = (length, predelay, damping, seed)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    r = np.random.default_rng(seed)
    n = n_of(length)
    t = np.arange(n) / SR
    decay = np.exp(-6.9 * t / length)  # -60 дБ к концу
    ir = np.stack([r.standard_normal(n), r.standard_normal(n)], axis=1) * decay[:, None]
    ir = lp(ir, damping)
    ir = hp(ir, 180)
    ir /= np.sqrt((ir ** 2).sum(axis=0, keepdims=True))
    ir = np.concatenate([np.zeros((n_of(predelay), 2)), ir])
    _IR_CACHE[key] = ir
    return ir


def reverb(x, wet=0.25, length=2.2, predelay=0.02, damping=4500, tail=True):
    x = stereo(x)
    ir = reverb_ir(length, predelay, damping)
    wet_sig = np.stack([signal.fftconvolve(x[:, c], ir[:, c]) for c in range(2)], axis=1)
    if tail:
        dry = np.concatenate([x, np.zeros((len(wet_sig) - len(x), 2))])
    else:
        dry = x
        wet_sig = wet_sig[: len(x)]
    return dry * (1 - wet * 0.5) + wet_sig * wet


def loop_wrap(x, loop_len):
    """Круговая склейка: всё, что звучит после точки лупа, добавляется в начало."""
    n = n_of(loop_len)
    y = x[:n].copy()
    rest = x[n:]
    while len(rest) > 0:
        k = min(n, len(rest))
        y[:k] += rest[:k]
        rest = rest[k:]
    return y


def true_peak(x):
    over = signal.resample_poly(x, 4, 1, axis=0)
    return float(np.max(np.abs(over)))


def limit(x, ceiling_db=TRUE_PEAK_DB):
    """Мягкий лимитер: огибающая пиков с быстрой атакой и плавным отпусканием."""
    ceiling = 10 ** (ceiling_db / 20)
    mono = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    need = np.maximum(1.0, mono / (ceiling * 0.98))
    # огибающая «максимум по окну» + сглаживание отпускания
    win = n_of(0.004)
    need = signal.convolve(need, np.ones(win) / win, mode="same")
    rel = np.exp(-1 / (SR * 0.08))
    g = np.empty_like(need)
    cur = 1.0
    for i in range(len(need)):
        cur = need[i] if need[i] > cur else need[i] + (cur - need[i]) * rel
        g[i] = cur
    y = x / (g[:, None] if x.ndim == 2 else g)
    tp = true_peak(y)
    if tp > ceiling:
        y *= ceiling / tp
    return y


def active_rms_db(x):
    mono = x.mean(axis=1) if x.ndim == 2 else x
    frame = n_of(0.01)
    frames = len(mono) // frame
    if frames == 0:
        return 20 * np.log10(np.sqrt((mono ** 2).mean()) + 1e-12)
    e = (mono[: frames * frame].reshape(frames, frame) ** 2).mean(axis=1)
    top = e.max()
    act = e[e > top * 10 ** (-30 / 10)]
    return 10 * np.log10(act.mean() + 1e-12)


def lufs(x):
    path = write_wav(x)
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    os.remove(path)
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", r)
    return float(m[-1]) if m else -70.0


def trim_tail(x, floor_db=-60.0):
    """Срезает хвост тише floor_db от пика (ревер под -60 дБ неслышен, но занимает голос пула)."""
    mono = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    above = np.nonzero(mono > mono.max() * 10 ** (floor_db / 20))[0]
    end = min(len(x), (above[-1] if len(above) else len(x)) + n_of(0.02))
    return x[:end]


def fades(x, fin=0.003, fout=0.015):
    x = x.copy()
    a, b = n_of(fin), n_of(fout)
    ramp_in = np.linspace(0, 1, a) ** 2
    ramp_out = np.linspace(1, 0, b) ** 2
    if x.ndim == 2:
        x[:a] *= ramp_in[:, None]
        x[-b:] *= ramp_out[:, None]
    else:
        x[:a] *= ramp_in
        x[-b:] *= ramp_out
    return x


def master(x, kind):
    x = stereo(x)
    x = hp(x, 25, order=2)
    x -= x.mean(axis=0, keepdims=True)
    if kind == "sfx":
        x = fades(trim_tail(x))
        x *= 10 ** ((SFX_RMS_DB - active_rms_db(x)) / 20)
    elif kind == "stinger":
        x = fades(trim_tail(x))
        x *= 10 ** ((STINGER_LUFS - lufs(x)) / 20)
    else:  # loop — без фейдов, стык уже бесшовный
        x *= 10 ** ((MUSIC_LUFS - lufs(x)) / 20)
    return limit(x)


def write_wav(x):
    x = stereo(x)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path


def save(x, name, folder, kind):
    os.makedirs(folder, exist_ok=True)
    y = master(x, kind)
    path = write_wav(y)
    out = os.path.join(folder, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "6", out], check=True)
    os.remove(path)
    print(f"wrote {os.path.relpath(out, ROOT)} {len(y) / SR:.2f}s tp={20 * np.log10(true_peak(y)):.1f}dB")


# --- SFX (DS §06) ----------------------------------------------------------------

def spark():
    # «дзынь»: FM-колокольчик ре6; серия +1 полутон за искру — pitch_scale в движке.
    d = 0.45
    x = fm_bell(midi(86), d, ratio=3.01, index=1.6, decay=0.16) * 0.8
    x += glass(midi(98), d, decay=0.18) * 0.25
    x += hp(noise(d), 7000) * exp_env(d, 0.012) * 0.08
    return reverb(stereo(x), wet=0.12, length=0.8)


def fuel():
    # вдох → низкий «бум» + блестящий хвост
    out = canvas(1.6)
    inhale = sweep_lp(bp(noise(0.3, "pink"), 300, 6000), 500, 5000) * np.linspace(0, 1, n_of(0.3)) ** 2.2
    place(out, inhale * 0.35, 0.0)
    boom = sine(np.geomspace(95, 36, n_of(0.8)), 0.8) * exp_env(0.8, 0.22, attack=0.004)
    boom[: n_of(0.3)] += np.tanh(3 * sine(np.geomspace(190, 72, n_of(0.3)), 0.3) * exp_env(0.3, 0.05)) * 0.25
    place(out, boom, 0.28)
    for i, n in enumerate([86, 90, 93, 98]):
        place(out, stereo(fm_bell(midi(n), 0.9, ratio=4.0, index=1.2, decay=0.3), (i - 1.5) * 0.4) * 0.18, 0.3 + i * 0.045)
    return reverb(out, wet=0.22, length=1.4)


def light_burst():
    out = canvas(1.8)
    whoosh = sweep_lp(hp(noise(0.5, "pink"), 400), 8000, 900) * exp_env(0.5, 0.14, attack=0.01)
    place(out, stereo(whoosh * 0.5), 0.0)
    boom = sine(np.geomspace(130, 32, n_of(1.1)), 1.1) * exp_env(1.1, 0.35, attack=0.003)
    boom[: n_of(0.25)] += lp(noise(0.25), 400) * exp_env(0.25, 0.05) * 0.6
    place(out, np.tanh(boom * 1.6) * 0.8, 0.0)
    for i, n in enumerate([81, 86, 90, 93, 98, 102]):
        place(out, stereo(glass(midi(n), 1.0, decay=0.5), (i % 3 - 1) * 0.7) * 0.12, 0.04 + i * 0.028)
    return reverb(out, wet=0.28, length=1.8)


def burn():
    # короткое «пшш»; высота по размеру врага — pitch_scale в движке
    d = 0.2
    hiss = bp(noise(d), 1800, 9000) * exp_env(d, 0.05, attack=0.003)
    sizzle = (rng.random(n_of(d)) < 0.02) * rng.standard_normal(n_of(d)) * exp_env(d, 0.06) * 0.6
    tone = sine(np.geomspace(900, 420, n_of(d)), d) * exp_env(d, 0.03) * 0.12
    return stereo(hiss * 0.7 + hp(sizzle, 2500) + tone)


def player_hit():
    # глухой удар (музыка искажается движком на 200 мс)
    d = 0.35
    thud = sine(np.geomspace(140, 48, n_of(d)), d) * exp_env(d, 0.09, attack=0.002)
    body = lp(noise(d, "pink"), 700) * exp_env(d, 0.05) * 0.8
    crack = bp(noise(0.04), 900, 3500) * exp_env(0.04, 0.008) * 0.4
    x = np.tanh((thud + body) * 1.8) * 0.8
    x[: len(crack)] += crack
    return reverb(stereo(x), wet=0.08, length=0.5)


def heartbeat():
    # «тук-тук» + дыхание (DS: «музыка уходит в low-pass, слышно дыхание»); цикл 1.2 с
    out = canvas(1.2)
    beat = sine(np.geomspace(72, 38, n_of(0.18)), 0.18) * exp_env(0.18, 0.05, attack=0.004)
    beat = lp(beat + lp(noise(0.18), 180) * exp_env(0.18, 0.03) * 0.4, 400)
    place(out, stereo(beat), 0.0)
    place(out, stereo(beat * 0.65), 0.22)
    breath = bp(noise(0.7, "pink"), 500, 2600)
    breath *= np.sin(np.linspace(0, np.pi, len(breath))) ** 2 * 0.06
    place(out, stereo(breath, 0.1), 0.45)
    return out


def level_up():
    # мажорный аккорд ре мажор + «флип» бумаги со светом
    out = canvas(1.6)
    flip = sweep_lp(bp(noise(0.16), 900, 7000), 2000, 9000) * exp_env(0.16, 0.05, attack=0.006)
    place(out, stereo(flip * 0.35, -0.2), 0.0)
    for i, n in enumerate([74, 78, 81, 86]):
        place(out, stereo(fm_bell(midi(n), 1.3, ratio=2.0, index=1.4, decay=0.5), (i - 1.5) * 0.35) * 0.3, 0.05 + i * 0.055)
    pad = supersaw(62, 1.4, spread=0.1) + supersaw(66, 1.4, spread=0.1) + supersaw(69, 1.4, spread=0.1)
    pad = lp(pad, 2200) * adsr(1.4, a=0.08, d=0.5, s=0.0, r=0.3)[:, None] * 0.12
    place(out, pad, 0.03)
    return reverb(out, wet=0.25, length=1.6)


def card_pick():
    out = canvas(0.6)
    flip = bp(noise(0.09), 1200, 8000) * exp_env(0.09, 0.025, attack=0.004)
    place(out, stereo(flip * 0.4, 0.2), 0.0)
    place(out, stereo(fm_bell(midi(81), 0.5, ratio=2.0, index=1.0, decay=0.15)) * 0.5, 0.02)
    place(out, stereo(fm_bell(midi(88), 0.45, ratio=2.0, index=0.8, decay=0.12), 0.3) * 0.3, 0.06)
    return reverb(out, wet=0.15, length=0.9)


def beacon_tick():
    # лёгкий стеклянный тик; частота растёт вместе с темпом внесения
    d = 0.2
    x = glass(midi(93), d, decay=0.07) * 0.6 + hp(noise(d), 5000) * exp_env(d, 0.004) * 0.15
    return reverb(stereo(x), wet=0.1, length=0.6)


def beacon_tier():
    # восходящее глиссандо · хор + колокол
    out = canvas(3.2)
    gl = np.geomspace(float(midi(50)), float(midi(74)), n_of(1.0))
    rise = lp(stereo(poly_saw(gl, 1.0)) + stereo(poly_saw(gl * 1.5, 1.0), 0.3) * 0.5, 1800)
    rise *= (np.linspace(0, 1, n_of(1.0)) ** 1.5)[:, None] * 0.18
    place(out, rise, 0.0)
    place(out, choir([62, 66, 69, 74], 2.2, attack=0.15, release=1.0), 0.9)
    place(out, stereo(fm_bell(midi(74), 2.2, ratio=3.5, index=2.0, decay=0.9)) * 0.45, 0.95)
    place(out, stereo(fm_bell(midi(81), 1.8, ratio=3.5, index=1.5, decay=0.7), 0.4) * 0.22, 1.0)
    place(out, stereo(sine(midi(38), 1.8) * adsr(1.8, a=0.05, d=1.0, s=0.0, r=0.4)) * 0.3, 0.95)
    return reverb(out, wet=0.35, length=2.4)


def beacon_milestone():
    out = canvas(3.6)
    place(out, choir([50, 57, 62, 66, 69], 3.0, attack=0.5, release=1.2), 0.0)
    place(out, stereo(fm_bell(midi(74), 2.6, ratio=3.5, index=2.2, decay=1.0)) * 0.4, 0.35)
    place(out, stereo(fm_bell(midi(81), 2.2, ratio=3.5, index=1.6, decay=0.8), -0.4) * 0.25, 0.5)
    place(out, stereo(fm_bell(midi(86), 2.0, ratio=3.5, index=1.2, decay=0.7), 0.4) * 0.18, 0.62)
    place(out, stereo(sine(midi(38), 2.8) * adsr(2.8, a=0.4, d=1.5, s=0.0, r=0.6)) * 0.3, 0.0)
    return reverb(out, wet=0.38, length=2.8)


def iap_crystal():
    # уникальный «хрустальный» аккорд — только покупки за деньги (ре мажор add9, высокий регистр)
    out = canvas(2.4)
    for i, n in enumerate([86, 90, 93, 97, 100, 105]):
        place(out, stereo(glass(midi(n), 1.9, decay=1.1), (i - 2.5) * 0.3) * (0.34 - i * 0.03), i * 0.03)
    shimmer = hp(noise(1.2), 9000) * exp_env(1.2, 0.4, attack=0.05) * 0.04
    place(out, stereo(shimmer), 0.05)
    return reverb(out, wet=0.35, length=2.2, damping=9000)


def ui_click():
    # мягкий клик
    d = 0.05
    x = bp(noise(d), 1500, 6000) * exp_env(d, 0.004, attack=0.0008) * 0.6
    x += sine(1350, d) * exp_env(d, 0.006, attack=0.0008) * 0.35
    return stereo(x)


def ui_disabled():
    # глухой «тук»
    d = 0.1
    x = sine(np.geomspace(260, 170, n_of(d)), d) * exp_env(d, 0.025, attack=0.001)
    x += lp(noise(d), 900) * exp_env(d, 0.01) * 0.3
    return stereo(lp(x, 1400))


def whisper_eyes():
    # шёпот во тьме: формантный шум «хсс» с дрожанием
    d = 1.0
    src = noise(d, "pink")
    x = bp(src, 2400, 7000) * 0.5 + bp(src, 600, 1000) * 0.3
    flutter = 0.6 + 0.4 * np.sin(2 * np.pi * 7.3 * tt(d)) * np.sin(2 * np.pi * 0.9 * tt(d))
    x *= flutter * adsr(d, a=0.35, d=d, s=1.0, r=0.35)
    left = x
    right = np.roll(x, n_of(0.013)) * 0.9
    return reverb(np.stack([left, right], axis=1) * 0.8, wet=0.3, length=1.4)


def reaper_windup():
    # нарастающий скрежет косы — предупреждение
    d = 0.75
    sc = sweep_lp(bp(noise(d), 300, 7000), 600, 6000) * np.linspace(0.1, 1, n_of(d)) ** 1.5
    ring = sine(np.geomspace(420, 1400, n_of(d)), d) * 0.2 + sine(np.geomspace(627, 2090, n_of(d)), d) * 0.1
    ring *= np.linspace(0, 1, n_of(d)) ** 2
    return reverb(stereo(sc * 0.6 + ring), wet=0.15, length=0.8)


def devourer_bite():
    d = 0.3
    out = np.zeros(n_of(d))
    for k, at_s in enumerate([0.0, 0.035, 0.07]):
        c = bp(noise(0.05), 700 + 500 * k, 4000) * exp_env(0.05, 0.012)
        out[n_of(at_s): n_of(at_s) + len(c)] += c * (1 - 0.25 * k)
    low = sine(np.geomspace(95, 42, n_of(d)), d) * exp_env(d, 0.07)
    return reverb(stereo(np.tanh((out * 0.8 + low) * 1.5) * 0.8), wet=0.08, length=0.5)


def extinguisher_hum():
    # тёмный нарастающий гул Гасителя (биения, без щелчка на конце)
    d = 1.3
    f = np.geomspace(55, 104, n_of(d))
    x = sine(f, d) + 0.5 * sine(f * 2.003, d) + 0.3 * sine(f * 3.01, d) + 0.15 * poly_saw(f * 0.998, d)
    x = lp(x, 900)
    env = np.linspace(0.05, 1, n_of(d)) ** 1.5
    env[-n_of(0.12):] *= np.linspace(1, 0, n_of(0.12))
    return stereo(np.tanh(x * env * 1.3) * 0.8)


def chest_open():
    out = canvas(1.4)
    thunk = sine(np.geomspace(170, 70, n_of(0.25)), 0.25) * exp_env(0.25, 0.05)
    thunk[: n_of(0.08)] += lp(noise(0.08), 1800) * exp_env(0.08, 0.015) * 0.6
    place(out, stereo(thunk), 0.0)
    latch = bp(noise(0.03), 2500, 7000) * exp_env(0.03, 0.005)
    place(out, stereo(latch * 0.4, 0.2), 0.09)
    for i, n in enumerate([79, 83, 86, 90, 95]):
        place(out, stereo(glass(midi(n), 0.9, decay=0.45), (i - 2) * 0.35) * 0.18, 0.14 + i * 0.045)
    return reverb(out, wet=0.22, length=1.4)


def item_merge():
    out = canvas(2.2)
    swell = sweep_lp(noise(0.65, "pink"), 250, 7000) * np.linspace(0, 1, n_of(0.65)) ** 2.5
    place(out, stereo(swell * 0.35), 0.0)
    place(out, stereo(fm_bell(midi(74), 1.4, ratio=2.0, index=1.8, decay=0.55)) * 0.45, 0.62)
    place(out, stereo(fm_bell(midi(81), 1.3, ratio=2.0, index=1.4, decay=0.5), -0.3) * 0.3, 0.64)
    place(out, stereo(glass(midi(90), 1.2, decay=0.6), 0.3) * 0.2, 0.66)
    place(out, stereo(sine(np.geomspace(80, 40, n_of(0.5)), 0.5) * exp_env(0.5, 0.15)) * 0.5, 0.62)
    return reverb(out, wet=0.28, length=1.8)


def revive():
    out = canvas(2.2)
    inhale = sweep_lp(bp(noise(0.45, "pink"), 300, 5000), 400, 4000) * np.linspace(0, 1, n_of(0.45)) ** 2
    place(out, stereo(inhale * 0.3), 0.0)
    pad = (supersaw(62, 1.6) + supersaw(69, 1.6) + supersaw(74, 1.6) + supersaw(78, 1.6)) * 0.1
    pad = lp(pad, 2500) * adsr(1.6, a=0.35, d=0.8, s=0.0, r=0.4)[:, None]
    place(out, pad, 0.3)
    place(out, stereo(fm_bell(midi(86), 1.4, ratio=3.5, index=1.6, decay=0.6)) * 0.35, 0.45)
    return reverb(out, wet=0.3, length=2.0)


# --- музыка ------------------------------------------------------------------------
# Хаб: 72 BPM, 16 тактов (≈53 с), ре мажор с лидийской окраской — тёплая надежда.
# Забег: 96 BPM, 16 тактов (40 с), ре минор; A (такты 1–8) и B (9–16) отличаются гармонией.
# Слои забега run_base / run_drums строго одной длины — AudioStreamSynchronized.

def bars_to_s(bars, bpm):
    return bars * 4 * 60 / bpm


def music_hub():
    bpm = 72
    beat = 60 / bpm
    loop = bars_to_s(16, bpm)
    tail = 4.0
    out = canvas(loop + tail)
    # D — G(#11 окраска: Gmaj7) — Bm — A(sus4 → A), по 2 такта; вторая половина — вариация
    prog = [[50, 62, 66, 69, 73], [43, 59, 62, 66, 73], [47, 62, 66, 71, 74], [45, 61, 64, 69, 76],
            [50, 62, 66, 69, 76], [43, 59, 62, 67, 71], [47, 59, 62, 66, 69], [45, 57, 62, 64, 69]]
    for i, ch in enumerate(prog):
        s = i * 8 * beat
        seg = sum(supersaw(n, 8 * beat + 1.5, voices=5, spread=0.09) for n in ch[1:]) * 0.07
        seg = lp(seg, 1300) * adsr(8 * beat + 1.5, a=1.2, d=9, s=0.85, r=1.4)[:, None]
        place(out, seg, s)
        bass = sine(midi(ch[0] - 12), 8 * beat + 1.0) * adsr(8 * beat + 1.0, a=0.6, d=6, s=0.7, r=1.0) * 0.28
        place(out, stereo(bass), s)
    # войлочное пианино: мотив из 5 нот, отвечающий гармонии
    motif = [(0, 0), (1.5, 2), (2, 4), (3, 3), (5, 1)]
    scale = [74, 76, 78, 81, 83, 85, 86]
    for i, ch in enumerate(prog):
        base = i * 8 * beat
        for k, (b, deg) in enumerate(motif):
            note = scale[(deg + i) % len(scale)]
            if (i + k) % 5 == 4:
                continue
            place(out, stereo(felt_piano(note, 3.0, vel=0.55 + 0.1 * (k % 2)), (k - 2) * 0.25) * 0.5, base + b * beat)
    # далёкий колокол Маяка раз в 4 такта
    for k in range(4):
        place(out, stereo(fm_bell(midi(86), 4.0, ratio=3.5, index=1.4, decay=1.6), 0.3) * 0.12, k * 16 * beat + 0.5)
    wet = reverb(out, wet=0.42, length=3.2, damping=5000)
    return loop_wrap(wet, loop)


def run_prog():
    # A: Dm — Bb — F — C ; B: Dm — Bb — Gm — A (напряжение → возврат)
    a = [[50, 62, 65, 69], [46, 62, 65, 70], [41, 60, 65, 69], [48, 60, 64, 67]]
    b = [[50, 62, 65, 69], [46, 62, 65, 70], [43, 62, 67, 70], [45, 61, 64, 69]]
    return a + a + b + b  # 16 тактов


def music_run_base():
    bpm = 96
    beat = 60 / bpm
    loop = bars_to_s(16, bpm)
    tail = 3.0
    out = canvas(loop + tail)
    for i, ch in enumerate(run_prog()):
        s = i * 4 * beat
        pad = sum(supersaw(n, 4 * beat + 0.8, voices=5, spread=0.1) for n in ch[1:]) * 0.06
        pad = lp(pad, 1100 if i < 8 else 1500) * adsr(4 * beat + 0.8, a=0.25, d=5, s=0.8, r=0.6)[:, None]
        place(out, pad, s)
        # пульсирующий бас восьмыми, с «дыханием» фильтра
        for e in range(8):
            dur = beat * 0.48
            note = ch[0] - 12 + (12 if e in (3, 7) else 0)
            bass = poly_saw(midi(note), dur) * 0.6 + sine(midi(note), dur) * 0.5
            bass = lp(bass, 380 + 160 * (e % 2)) * adsr(dur, a=0.004, d=0.18, s=0.25, r=0.03)
            place(out, stereo(bass) * 0.55, s + e * beat / 2)
        # арпеджио-щипок шестнадцатыми во второй половине (B)
        if i >= 8:
            arp = [ch[1] + 12, ch[2] + 12, ch[3] + 12, ch[2] + 24]
            for k in range(16):
                note = arp[k % 4]
                place(out, stereo(fm_bell(midi(note), 0.3, ratio=1.0, index=1.8, decay=0.09), ((k % 4) - 1.5) * 0.4) * 0.12,
                      s + k * beat / 4)
    wet = reverb(out, wet=0.25, length=1.8)
    return loop_wrap(wet, loop)


def music_run_drums():
    bpm = 96
    beat = 60 / bpm
    loop = bars_to_s(16, bpm)
    out = canvas(loop + 1.5)
    kick = np.tanh(sine(np.geomspace(150, 44, n_of(0.3)), 0.3) * exp_env(0.3, 0.09, attack=0.001) * 1.6) * 0.9
    kick[: n_of(0.006)] += bp(noise(0.006), 2000, 6000) * 0.3
    snare = bp(noise(0.22), 1200, 7500) * exp_env(0.22, 0.06) * 0.6 + sine(np.geomspace(230, 180, n_of(0.22)), 0.22) * exp_env(0.22, 0.04) * 0.4
    hat = hp(noise(0.06), 7000) * exp_env(0.06, 0.012) * 0.25
    shaker = bp(noise(0.08), 4000, 11000) * np.sin(np.linspace(0, np.pi, n_of(0.08))) * 0.12
    tom = sine(np.geomspace(140, 90, n_of(0.3)), 0.3) * exp_env(0.3, 0.1) * 0.6
    for bar in range(16):
        s = bar * 4 * beat
        fill = bar in (7, 15)
        for b in range(4):
            if b in (0, 2) or (b == 3 and bar % 2 == 1):
                place(out, stereo(kick), s + b * beat + (beat / 2 if b == 3 else 0))
            if b in (1, 3) and not (fill and b == 3):
                place(out, stereo(snare, 0.05) * 0.7, s + b * beat)
        for k in range(8):
            place(out, stereo(hat, 0.35 if k % 2 else -0.2) * (1.0 if k % 2 else 0.6), s + k * beat / 2)
        for k in range(16):
            if k % 2:
                place(out, stereo(shaker, -0.4), s + k * beat / 4)
        if fill:
            for k, pan in enumerate([-0.5, -0.2, 0.2, 0.5]):
                place(out, stereo(tom * (1 - 0.1 * k), pan), s + 3 * beat + k * beat / 4)
    wet = reverb(out, wet=0.12, length=0.9, damping=7000)
    return loop_wrap(wet, loop)


def music_reward_resolve():
    # разрешение в ре мажор на фазе Награды (стингер, не луп)
    out = canvas(3.6)
    place(out, choir([50, 62, 66, 69, 74], 2.6, attack=0.2, release=1.2), 0.0)
    for i, n in enumerate([74, 78, 81, 86]):
        place(out, stereo(fm_bell(midi(n), 2.4, ratio=2.0, index=1.2, decay=0.9), (i - 1.5) * 0.4) * 0.22, 0.05 + i * 0.07)
    place(out, stereo(sine(midi(38), 2.6) * adsr(2.6, a=0.1, d=1.4, s=0.0, r=0.8)) * 0.35, 0.0)
    return reverb(out, wet=0.35, length=2.6)


SFX = {
    "spark": spark, "fuel": fuel, "light_burst": light_burst, "burn": burn, "player_hit": player_hit,
    "heartbeat": heartbeat, "level_up": level_up, "card_pick": card_pick, "beacon_tick": beacon_tick,
    "beacon_tier": beacon_tier, "beacon_milestone": beacon_milestone, "iap_crystal": iap_crystal,
    "ui_click": ui_click, "ui_disabled": ui_disabled, "whisper_eyes": whisper_eyes, "reaper_windup": reaper_windup,
    "devourer_bite": devourer_bite, "extinguisher_hum": extinguisher_hum, "chest_open": chest_open,
    "item_merge": item_merge, "revive": revive,
}
MUSIC = {"hub": music_hub, "run_base": music_run_base, "run_drums": music_run_drums}
STINGERS = {"reward_resolve": music_reward_resolve}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn in SFX.items():
        if not only or name in only:
            save(fn(), name, OUT_SFX, "sfx")
    for name, fn in STINGERS.items():
        if not only or name in only:
            save(fn(), name, OUT_MUSIC, "stinger")
    for name, fn in MUSIC.items():
        if not only or name in only:
            save(fn(), name, OUT_MUSIC, "loop")
