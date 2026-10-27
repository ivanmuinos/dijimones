#!/usr/bin/env python3
"""Genera la banda sonora ORIGINAL de Dijimones.

No usa samples ni melodías de Digimon: todo se sintetiza acá (saw/square aditivas,
distorsión, reverb por convolución, delay, sidechain) y las composiciones son propias.

Uso:
    python3 tools/make_music.py            # -> game/assets/music/{batalla,menu}.ogg
    python3 tools/make_music.py --wav      # además deja los .wav para escucharlos

Requiere numpy y ffmpeg (solo para comprimir a OGG).
"""
import argparse
import math
import os
import shutil
import subprocess
import sys
import wave

try:
    import numpy as np
except ImportError:
    sys.exit("Falta numpy: python3 -m pip install numpy")

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "game", "assets", "music"))
RNG = np.random.default_rng(20261027)

NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
CHORDS = {
    "D": [62, 66, 69], "G": [55, 59, 62], "A": [57, 61, 64], "Bm": [59, 62, 66],
    "F#m": [54, 57, 61], "Em": [52, 55, 59], "E": [56, 59, 63], "C#m": [61, 64, 68],
}


def ns(sec):
    """Segundos -> muestras."""
    return max(1, int(round(sec * RATE)))


def midi(note):
    return 12 * (int(note[-1]) + 1) + NAMES[note[:-1]]


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


# ---------------------------------------------------------------- síntesis ---

def osc(f, n, harmonics=18, bright=8.0, shape="saw", vib=0.0, vib_rate=5.6, phase0=0.0):
    """Oscilador aditivo limitado en banda (sin aliasing)."""
    t = np.arange(n, dtype=np.float64) / RATE
    ph = 2.0 * np.pi * f * t + phase0
    if vib:
        ph = ph + vib * np.sin(2.0 * np.pi * vib_rate * t) * (1.0 - np.exp(-t / 0.35))
    kmax = max(1, int(min(harmonics, 0.45 * RATE / max(f, 1.0))))
    k = np.arange(1, kmax + 1, dtype=np.float64)
    if shape == "square":
        amp = (k % 2) / k
    elif shape == "pulse":
        amp = np.abs(np.sin(np.pi * k * 0.25)) / k
    else:
        amp = 1.0 / k
    amp = amp * np.exp(-(k - 1.0) / bright)
    return amp @ np.sin(np.outer(k, ph)) / (np.abs(amp).sum() or 1.0)


def adsr(n, gate, a, d, s, r):
    e = np.zeros(n)
    gate = min(gate, n)
    ai = min(int(a * RATE), gate)
    di = min(int(d * RATE), gate - ai)
    si = gate - ai - di
    ri = n - gate
    i = 0
    if ai > 0:
        e[i:i + ai] = np.linspace(0.0, 1.0, ai, endpoint=False)
        i += ai
    if di > 0:
        e[i:i + di] = np.linspace(1.0, s, di, endpoint=False)
        i += di
    if si > 0:
        e[i:i + si] = s
        i += si
    if ri > 0:
        e[i:i + ri] = np.linspace(s, 0.0, ri)
    return e


def lp(x, fc, order=2):
    return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order)))


def hp(x, fc, order=2):
    return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-6)) ** (2 * order)))


def fft_filter(x, resp):
    n = x.shape[-1]
    nfft = 1 << int(np.ceil(np.log2(n + 1)))
    spec = np.fft.rfft(x, nfft)
    f = np.fft.rfftfreq(nfft, 1.0 / RATE)
    out = np.fft.irfft(spec * resp(f), nfft)
    return out[..., :n]


# --------------------------------------------------------------- instrumentos

def lead(f, dur, vel=1.0, bright=7.0):
    """Lead de synth tipo opening: dos saws desafinados, square una octava abajo, vibrato."""
    gate = ns(dur * 0.94)
    rel = ns(0.10)
    n = gate + rel
    sig = osc(f * 0.996, n, 20, bright, vib=0.35) * 0.55
    sig += osc(f * 1.004, n, 20, bright, vib=0.35) * 0.55
    sig += osc(f * 0.5, n, 8, 3.0, shape="square") * 0.30
    return sig * adsr(n, gate, 0.012, 0.10, 0.74, rel / RATE) * vel


def guitar(root, dur, palm=False, vel=1.0):
    """Power chord distorsionado (root + quinta + octava) con waveshaper."""
    f = hz(root)
    gate = ns(dur * 0.96)
    rel = ns(0.02 if palm else 0.05)
    n = gate + rel
    sig = osc(f, n, 14, 4.5) * 0.8 + osc(f * 1.006, n, 14, 4.5) * 0.8
    sig += osc(hz(root + 7), n, 10, 4.0) * 0.55 + osc(hz(root + 12), n, 8, 3.0) * 0.30
    sig = np.tanh(5.0 * sig)
    e = adsr(n, gate, 0.004, 0.05 if palm else 0.10, 0.32 if palm else 0.82, rel / RATE)
    return sig * e * vel


def bass_note(m, dur, vel=1.0, sub=0.55):
    f = hz(m)
    gate = ns(dur * 0.88)
    rel = ns(0.04)
    n = gate + rel
    sig = osc(f, n, 16, 5.0) * 0.70 + osc(f, n, 6, 2.0) * sub + osc(f * 2, n, 6, 3.0) * 0.15
    return np.tanh(2.0 * sig) * adsr(n, gate, 0.005, 0.09, 0.80, rel / RATE) * vel


def pad_chord(midis, dur, vel=1.0, bright=4.5):
    gate = ns(dur)
    rel = ns(0.50)
    n = gate + rel
    sig = np.zeros(n)
    for m in midis:
        f = hz(m)
        for det in (-0.009, 0.0, 0.009):
            sig += osc(f * (1 + det), n, 9, bright) * 0.22
    return sig * adsr(n, gate, 0.35, 0.20, 0.90, rel / RATE) * vel / max(1, len(midis))


def pluck(f, dur, vel=1.0):
    gate = ns(min(dur * 0.9, 0.30))
    rel = ns(0.12)
    n = gate + rel
    sig = osc(f, n, 12, 9.0, shape="pulse") * 0.7 + osc(f * 2, n, 6, 6.0) * 0.15
    return sig * adsr(n, gate, 0.003, 0.10, 0.25, rel / RATE) * vel


def bell(f, dur, vel=1.0):
    """Campana / music box con parciales inarmónicos."""
    n = ns(dur + 0.9)
    t = np.arange(n) / RATE
    sig = np.zeros(n)
    for ratio, amp, dec in ((1.0, 1.0, 1.10), (2.0, 0.45, 0.70), (3.01, 0.26, 0.45), (4.2, 0.15, 0.32), (5.4, 0.08, 0.22)):
        sig += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / dec)
    return sig * np.minimum(1.0, t / 0.003) * vel * 0.42


def epiano(f, dur, vel=1.0):
    n = ns(dur + 0.8)
    t = np.arange(n) / RATE
    sig = np.zeros(n)
    for ratio, amp, dec in ((1, 1.0, 1.3), (2, 0.42, 0.70), (3, 0.20, 0.42), (4.02, 0.09, 0.28)):
        sig += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / dec)
    return sig * np.minimum(1.0, t / 0.004) * vel * 0.34


# -------------------------------------------------------------------- batería

DRUMS = {}


def _noise(n):
    return RNG.standard_normal(n)


def drum(kind):
    if kind in DRUMS:
        return DRUMS[kind]
    if kind == "K":
        n = ns(0.38)
        t = np.arange(n) / RATE
        f = 46.0 + 130.0 * np.exp(-t / 0.028)
        body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t / 0.11)
        click = _noise(ns(0.012)) * np.exp(-np.arange(ns(0.012)) / RATE / 0.002) * 0.5
        s = body * 0.95
        s[:len(click)] += click
        s = np.tanh(1.7 * s)
    elif kind == "S":
        n = ns(0.25)
        t = np.arange(n) / RATE
        nz = hp(_noise(n) * np.exp(-t / 0.075), 1200)
        tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05) * 0.5
        s = np.tanh(1.2 * (nz * 0.9 + tone))
    elif kind in ("H", "O"):
        d = 0.045 if kind == "H" else 0.17
        n = ns(d * 4)
        t = np.arange(n) / RATE
        s = hp(_noise(n), 6500, 3) * np.exp(-t / (d * 0.45)) * 0.30
    elif kind == "C":
        n = ns(1.7)
        t = np.arange(n) / RATE
        nz = hp(_noise(n), 3200, 3)
        metal = sum(np.sin(2 * np.pi * f * t) for f in (3170, 4310, 5830, 7420)) * 0.05
        s = (nz * 0.8 + metal) * np.exp(-t / 0.55) * 0.55
    elif kind == "T":
        n = ns(0.30)
        t = np.arange(n) / RATE
        f = 120.0 + 90.0 * np.exp(-t / 0.05)
        s = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t / 0.13) * 0.7
    else:  # R = rim
        n = ns(0.09)
        t = np.arange(n) / RATE
        s = (np.sin(2 * np.pi * 900 * t) * 0.4 + hp(_noise(n), 2500) * 0.4) * np.exp(-t / 0.02)
    DRUMS[kind] = s
    return s


# ------------------------------------------------------------------ canción ---

class Song:
    def __init__(self, name, bpm, bars, tail=3.0):
        self.name = name
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.length = bars * 4 * self.beat
        self.n = ns(self.length + tail)
        self.buses = {}
        self.duck = np.zeros(self.n)
        self._cache = {}

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = np.zeros((2, self.n))
        return self.buses[name]

    def at(self, bar, beat=0.0):
        return (bar * 4 + beat) * self.beat

    def add(self, bus, sig, t, gain=1.0, pan=0.0):
        b = self.bus(bus)
        s = int(round(t * RATE))
        if s >= self.n or s < 0:
            return
        m = min(len(sig), self.n - s)
        if m <= 0:
            return
        gl = math.cos((pan + 1.0) * math.pi / 4.0) * gain
        gr = math.sin((pan + 1.0) * math.pi / 4.0) * gain
        b[0, s:s + m] += sig[:m] * gl
        b[1, s:s + m] += sig[:m] * gr

    def duck_at(self, t, depth=1.0, decay=0.16):
        s = int(round(t * RATE))
        m = min(ns(decay * 2.5), self.n - s)
        if m <= 0:
            return
        tarr = np.arange(m) / RATE
        self.duck[s:s + m] = np.maximum(self.duck[s:s + m], np.exp(-tarr / decay) * depth)

    # -- helpers de arreglo ------------------------------------------------
    def phrase(self, bus, bar, tokens, inst, gain=1.0, pan=0.0, transpose=0, **kw):
        """tokens: [(nota|None, corcheas), ...] a partir de `bar`."""
        t = self.at(bar)
        for name, eighths in tokens:
            dur = eighths * self.beat / 2.0
            if name:
                m = midi(name) + transpose
                self.add(bus, inst(hz(m), dur, **kw), t, gain, pan)
            t += dur

    def drums(self, bar, *patterns, gain=1.0):
        step = self.beat / 4.0
        for pat in patterns:
            assert len(pat) == 16, "un compás de batería son 16 pasos: %r" % pat
            for j, ch in enumerate(pat):
                if ch in "-.":
                    continue
                vel = 1.0 if j % 4 == 0 else 0.76
                pan = {"H": 0.16, "O": 0.20, "C": -0.12, "R": 0.28}.get(ch, 0.0)
                self.add("drums", drum(ch), self.at(bar) + j * step, gain * vel, pan)
                if ch == "K":
                    self.duck_at(self.at(bar) + j * step)


# ---------------------------------------------------------------- arreglos ---

HATS = "H.H.H.H.H.H.H.H."
HATS16 = "HHHHHHHHHHHHHHHH"
SNARE = "....S.......S..."
FILL = "K.K.S.S.TTTTSSSS"

MEL_VERSE = [
    ("F#4", 1), (None, 1), ("F#4", 1), ("A4", 1), ("B4", 2), ("A4", 2),
    ("G4", 1), (None, 1), ("G4", 1), ("B4", 1), ("D5", 2), ("B4", 2),
    ("A4", 1), (None, 1), ("A4", 1), ("D5", 1), ("F#5", 2), ("E5", 2),
    ("C#5", 2), ("B4", 2), ("A4", 2), ("E4", 2),
]

MEL_PRE = [
    ("E4", 2), ("E4", 2), ("G4", 2), ("A4", 2),
    ("F#4", 2), ("F#4", 2), ("A4", 2), ("B4", 2),
    ("G4", 2), ("G4", 2), ("B4", 2), ("D5", 2),
    ("C#5", 2), ("E5", 2), ("A5", 4),
]

MEL_CHORUS_A = [
    ("A4", 1), ("B4", 1), ("D5", 2), ("E5", 2), ("D5", 1), ("B4", 1),
    ("C#5", 1), ("D5", 1), ("E5", 2), ("A5", 3), (None, 1),
    ("F#5", 1), ("E5", 1), ("C#5", 2), ("D5", 2), ("C#5", 1), ("A4", 1),
    ("B4", 1), ("D5", 1), ("F#5", 2), ("A5", 2), ("F#5", 1), ("D5", 1),
]

MEL_CHORUS_B = [
    ("A4", 1), ("B4", 1), ("D5", 2), ("F#5", 2), ("E5", 2),
    ("D5", 1), ("E5", 1), ("F#5", 2), ("A5", 4),
    ("B5", 2), ("A5", 1), ("F#5", 1), ("E5", 2), ("C#5", 2),
    ("D5", 2), ("F#5", 2), ("A5", 2), ("B5", 2),
]

MEL_BRIDGE = [
    ("E5", 4), ("D5", 2), ("B4", 2),
    ("C#5", 4), ("E5", 4),
    ("F#5", 4), ("E5", 2), ("C#5", 2),
    ("D5", 2), ("F#5", 2), ("B5", 4),
]

MEL_INTRO = [
    ("D5", 2), ("F#5", 2), ("A5", 2), ("F#5", 2),
    ("D5", 2), ("G5", 2), ("B5", 4),
]


def build_battle():
    s = Song("batalla", 172, 38)
    prog = (["Bm", "G", "D", "A"]          # 0-3 intro
            + ["Bm", "G", "D", "A"] * 2    # 4-11 estrofa
            + ["Em", "F#m", "G", "A"]      # 12-15 pre-estribillo
            + ["G", "A", "F#m", "Bm"] * 2  # 16-23 estribillo
            + ["Em", "A", "F#m", "Bm"]     # 24-27 puente
            + ["G", "A", "F#m", "Bm"] * 2  # 28-35 estribillo final
            + ["G", "A"])                  # 36-37 vuelta
    assert len(prog) == 38

    def section(bar):
        if bar < 4:
            return "intro"
        if bar < 12:
            return "verse"
        if bar < 16:
            return "pre"
        if bar < 24:
            return "chorus"
        if bar < 28:
            return "bridge"
        if bar < 36:
            return "chorus2"
        return "outro"

    for bar, chord in enumerate(prog):
        sec = section(bar)
        last_of_section = bar in (3, 11, 15, 23, 27, 35)
        notes = CHORDS[chord]
        root = notes[0] - 24

        # --- pads (todos menos el puente completo) ---
        pad_gain = {"intro": 0.55, "verse": 0.65, "pre": 0.75, "chorus": 0.85,
                    "bridge": 0.95, "chorus2": 0.9, "outro": 0.7}[sec]
        s.add("pad", pad_chord([n - 12 for n in notes] + [notes[0]], s.beat * 4), s.at(bar), pad_gain, 0.0)

        # --- bajo ---
        if sec in ("verse", "pre", "chorus", "chorus2", "outro"):
            pattern = [0, 0, 0, 0, 0, 0, 7, 12] if sec != "pre" else [0, 0, 0, 0, 7, 7, 12, 12]
            for j, off in enumerate(pattern):
                s.add("bass", bass_note(root + off, s.beat / 2.0), s.at(bar) + j * s.beat / 2.0, 0.95)
        elif sec == "bridge":
            for j, off in enumerate([0, 0, 7, 12]):
                s.add("bass", bass_note(root + off, s.beat), s.at(bar) + j * s.beat, 1.0)

        # --- guitarras ---
        if sec in ("verse", "pre"):
            for j in range(8):
                s.add("gtr", guitar(root + 12, s.beat / 2.0, palm=True), s.at(bar) + j * s.beat / 2.0, 0.55)
        elif sec in ("chorus", "chorus2", "outro"):
            for j in range(8):
                s.add("gtr", guitar(root + 12, s.beat / 2.0, palm=False), s.at(bar) + j * s.beat / 2.0, 0.68)
        elif sec == "bridge":
            s.add("gtr", guitar(root + 12, s.beat * 4, palm=False), s.at(bar), 0.7)

        # --- arpegio (intro, pre, puente) ---
        if sec in ("intro", "pre", "bridge"):
            tones = notes + [notes[0] + 12]
            order = [0, 1, 2, 3, 2, 1, 0, 1] * 2
            for j in range(16):
                m = tones[order[j] % len(tones)] + 12
                s.add("arp", pluck(hz(m), s.beat / 4.0), s.at(bar) + j * s.beat / 4.0,
                      0.30 if sec == "intro" else 0.24, -0.25 if j % 2 else 0.25)

        # --- batería ---
        if sec == "intro":
            if bar == 1:
                s.drums(bar, HATS)
            elif bar == 2:
                s.drums(bar, HATS, SNARE, "K-------K-------")
            elif bar == 3:
                s.drums(bar, HATS, SNARE, "K-------K-------")
                s.drums(bar, FILL, gain=0.75)
        elif sec == "verse":
            s.drums(bar, HATS, SNARE, "K..K..K.K..K..K.")
            if last_of_section:
                s.drums(bar, FILL)
        elif sec == "pre":
            s.drums(bar, HATS16, SNARE, "K...K...K...K...")
            if last_of_section:
                s.drums(bar, FILL, gain=0.9)
        elif sec in ("chorus", "chorus2", "outro"):
            s.drums(bar, HATS, "O...O...O...O...", SNARE, "K...K...K...K...")
            if bar % 4 == 0:
                s.drums(bar, "C---------------")
            if last_of_section:
                s.drums(bar, FILL)
        elif sec == "bridge":
            s.drums(bar, HATS, "K-------K-------")
            if bar % 2:
                s.drums(bar, SNARE)
            if bar == 27:
                s.drums(bar, FILL)

    # --- melodías ---
    for bar in range(4, 8):
        s.phrase("lead", bar, MEL_VERSE, lead, gain=0.85, pan=0.0)
    for bar in range(8, 12):
        s.phrase("lead", bar, MEL_VERSE, lead, gain=0.85, pan=0.0)

    s.phrase("lead", 12, MEL_PRE, lead, gain=0.9)

    s.phrase("lead", 16, MEL_CHORUS_A, lead, gain=1.0)
    s.phrase("lead", 20, MEL_CHORUS_B, lead, gain=1.0)

    s.phrase("lead", 24, MEL_BRIDGE, lead, gain=1.0)
    s.phrase("bell", 24, MEL_BRIDGE, bell, gain=0.55)

    s.phrase("lead", 28, MEL_CHORUS_A, lead, gain=1.0)
    s.phrase("lead", 28, MEL_CHORUS_A, lead, gain=0.50, transpose=12)   # armonía
    s.phrase("lead", 32, MEL_CHORUS_B, lead, gain=1.0)
    s.phrase("lead", 32, MEL_CHORUS_B, lead, gain=0.45, transpose=12)

    # intro: campana + melodía suave
    s.phrase("bell", 0, MEL_INTRO, bell, gain=0.9, pan=-0.15)
    s.phrase("bell", 2, MEL_INTRO, bell, gain=0.9, pan=0.15)
    s.phrase("lead", 2, MEL_INTRO, lead, gain=0.45)

    # vuelta final: misma célula que la intro para que el loop cierre
    s.phrase("bell", 36, MEL_INTRO, bell, gain=0.75)
    s.phrase("lead", 36, MEL_INTRO, lead, gain=0.6)
    return s


MEL_MENU_A = [
    ("E5", 2), ("C#5", 2), ("A4", 4),
    ("B4", 2), ("G#4", 2), ("E4", 4),
    ("F#4", 2), ("A4", 2), ("C#5", 4),
    ("D5", 2), ("C#5", 2), ("A4", 4),
    ("E5", 2), ("F#5", 2), ("E5", 4),
    ("B4", 2), ("C#5", 2), ("B4", 4),
    ("D5", 2), ("B4", 2), ("A4", 4),
    ("G#4", 2), ("B4", 2), ("E5", 4),
]

MEL_MENU_B = [
    ("C#5", 2), ("A4", 2), ("F#4", 2), ("A4", 2),
    ("D5", 2), ("A4", 2), ("F#4", 2), ("A4", 2),
    ("E5", 4), ("C#5", 2), ("A4", 2),
    ("B4", 2), ("G#4", 2), ("B4", 4),
    ("C#5", 2), ("D5", 2), ("E5", 4),
    ("F#5", 2), ("E5", 2), ("D5", 4),
    ("B4", 2), ("C#5", 2), ("D5", 4),
    ("E5", 6), (None, 2),
]


def build_menu():
    s = Song("menu", 92, 24, tail=3.5)
    prog = (["A", "E", "F#m", "D"]          # 0-3 intro
            + ["A", "E", "F#m", "D", "A", "E", "D", "E"]     # 4-11 A
            + ["F#m", "D", "A", "E", "F#m", "D", "E", "E"]   # 12-19 B
            + ["A", "E", "F#m", "D"])                        # 20-23 vuelta
    assert len(prog) == 24

    for bar, chord in enumerate(prog):
        notes = CHORDS[chord]
        root = notes[0] - 12
        if bar < 4 or bar >= 20:
            s.add("pad", pad_chord([n - 12 for n in notes], s.beat * 4), s.at(bar), 0.7, 0.0)
            s.add("bass", bass_note(root, s.beat * 2, sub=0.22), s.at(bar), 0.7)
            s.add("bass", bass_note(root + 7, s.beat * 2, sub=0.20), s.at(bar, 2), 0.6)
        else:
            s.add("pad", pad_chord([n - 12 for n in notes], s.beat * 4), s.at(bar), 0.5, 0.0)
            s.add("bass", bass_note(root, s.beat, sub=0.22), s.at(bar), 0.8)
            s.add("bass", bass_note(root + 12, s.beat, sub=0.18), s.at(bar, 1), 0.55)
            s.add("bass", bass_note(root + 7, s.beat, sub=0.20), s.at(bar, 2), 0.7)
            s.add("bass", bass_note(root, s.beat, sub=0.22), s.at(bar, 3), 0.8)
            # arpegio de 8vos suave
            tones = notes + [notes[0] + 12]
            order = [0, 1, 2, 3, 2, 1, 2, 1]
            for j in range(8):
                s.add("arp", pluck(hz(tones[order[j]] + 12), s.beat / 2.0),
                      s.at(bar) + j * s.beat / 2.0, 0.16, 0.3 if j % 2 else -0.3)

        # batería suave
        if 4 <= bar < 20:
            s.drums(bar, "H.H.H.H.H.H.H.H.", gain=0.55)
            s.drums(bar, "R---R---R---R---", gain=0.5)
            if bar % 2 == 0:
                s.drums(bar, "K-------K-------", gain=0.75)
            if bar % 8 == 4:
                s.drums(bar, "C---------------", gain=0.5)

    s.phrase("epiano", 0, MEL_MENU_A[:16], epiano, gain=0.9, pan=-0.2)
    s.phrase("bell", 0, MEL_MENU_A[:16], bell, gain=0.35, pan=0.2)
    s.phrase("epiano", 2, MEL_MENU_A[16:], epiano, gain=0.9, pan=0.15)
    s.phrase("bell", 2, MEL_MENU_A[16:], bell, gain=0.35, pan=-0.2)

    for start in (4, 8):
        s.phrase("epiano", start, MEL_MENU_A, epiano, gain=1.0)
        s.phrase("bell", start, MEL_MENU_A, bell, gain=0.30, pan=0.25)
    for start in (12, 16):
        s.phrase("epiano", start, MEL_MENU_B, epiano, gain=1.0, pan=-0.1)
        s.phrase("bell", start, MEL_MENU_B, bell, gain=0.28, pan=-0.25)

    s.phrase("bell", 20, MEL_MENU_A[:16], bell, gain=0.55, pan=-0.2)
    s.phrase("epiano", 20, MEL_MENU_A[:16], epiano, gain=0.8)
    s.phrase("bell", 22, MEL_MENU_A[16:], bell, gain=0.5, pan=0.2)
    s.phrase("epiano", 22, MEL_MENU_A[16:], epiano, gain=0.8)
    return s


# --------------------------------------------------------------------- mezcla

def convolve(a, b):
    n = len(a) + len(b) - 1
    nfft = 1 << int(np.ceil(np.log2(n)))
    return np.fft.irfft(np.fft.rfft(a, nfft) * np.fft.rfft(b, nfft), nfft)[:len(a)]


def impulse(length=1.9, predelay=0.02):
    n = ns(length)
    t = np.arange(n) / RATE
    irs = []
    for _ in range(2):
        env = np.exp(-t / (length * 0.30))
        env[:ns(predelay)] *= 0.15
        h = lp(hp(_noise(n) * env, 220), 7200, 1)
        h /= math.sqrt(float(np.sum(h * h)) or 1.0)
        irs.append(h)
    return np.stack(irs)


def delay(x, d, fb, taps=4):
    out = np.zeros_like(x)
    for k in range(1, taps + 1):
        s = d * k
        if s >= x.shape[1]:
            break
        g = fb ** k
        if k % 2:
            out[0, s:] += x[0, :-s] * g
            out[1, s:] += x[1, :-s] * g * 0.5
        else:
            out[1, s:] += x[1, :-s] * g
            out[0, s:] += x[0, :-s] * g * 0.5
    return out


def render(s, levels, sends, rev_amount, duck_bus=(), delay_bus=None, delay_time=0.35):
    master = np.zeros((2, s.n))
    send = np.zeros((2, s.n))
    for name, bus in s.buses.items():
        sig = bus
        if name == "gtr":
            sig = lp(sig, 5000, 3)
        elif name == "drums":
            sig = lp(sig, 13000, 1)
        elif name == "pad":
            sig = hp(lp(sig, 3200, 1), 110, 1)
        elif name == "bass":
            sig = lp(sig, 1000, 1)
        elif name == "arp":
            sig = hp(sig, 320)
        g = levels.get(name, 1.0)
        if name in duck_bus:
            sig = sig * (1.0 - 0.34 * s.duck)
        master += sig * g
        send += sig * g * sends.get(name, 0.0)
    ir = impulse()
    wet = np.stack([convolve(send[0], ir[0]), convolve(send[1], ir[1])])
    master += wet * rev_amount
    if delay_bus:
        dry = s.buses[delay_bus] * levels.get(delay_bus, 1.0)
        master += delay(dry, ns(delay_time), 0.34) * 0.5
    return master


def master_chain(x, target_rms=0.12):
    x = hp(x, 26, 2)
    x = fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (f / 13000.0) ** 4))
    rms = float(np.sqrt(np.mean(x * x))) or 1.0
    x *= target_rms / rms
    x = np.tanh(x)
    peak = float(np.max(np.abs(x))) or 1.0
    return x / peak * 0.96


def fold_loop(x, length_samples):
    out = x[:, :length_samples].copy()
    tail = x[:, length_samples:]
    m = min(tail.shape[1], length_samples)
    out[:, :m] += tail[:, :m]
    return out


def write_wav(path, x):
    data = (np.clip(x.T, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def encode_ogg(wav_path, ogg_path):
    """OGG Vorbis. Prefiere libvorbis; si el ffmpeg del sistema no lo trae, usa el encoder nativo."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        return False
    for codec in (["-c:a", "libvorbis", "-q:a", "5"],
                  ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "5"]):
        r = subprocess.run([ffmpeg, "-y", "-loglevel", "quiet", "-i", wav_path] + codec + [ogg_path],
                           capture_output=True)
        if r.returncode == 0 and os.path.exists(ogg_path):
            return True
    return False


def export(name, x, ogg, keep_wav):
    """x ya viene mezclado y normalizado; recorta el loop y escribe."""
    wav = os.path.join(OUT, name + ".wav")
    write_wav(wav, x)
    info = "%.1fs  rms=%.3f  pico=%.3f" % (
        x.shape[1] / RATE, float(np.sqrt(np.mean(x * x))), float(np.max(np.abs(x))))
    if encode_ogg(wav, ogg):
        info += "  -> %s (%.1f MB)" % (os.path.basename(ogg), os.path.getsize(ogg) / 1e6)
        if not keep_wav:
            os.remove(wav)
    else:
        print("  (ffmpeg no encontrado: dejo el .wav)")
    print("%-8s %s" % (name, info))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wav", action="store_true", help="dejar también los .wav")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)

    battle = build_battle()
    x = master_chain(fold_loop(render(
        battle,
        levels={"lead": 1.0, "gtr": 0.95, "bass": 1.0, "pad": 1.0, "arp": 0.9, "drums": 0.95, "bell": 0.8},
        sends={"lead": 0.30, "arp": 0.35, "bell": 0.55, "gtr": 0.12, "pad": 0.18},
        rev_amount=0.55, duck_bus=("pad", "arp"), delay_bus="lead", delay_time=0.262),
        ns(battle.length)))
    export("batalla", x, os.path.join(OUT, "batalla.ogg"), args.wav)

    menu = build_menu()
    x = master_chain(fold_loop(render(
        menu,
        levels={"epiano": 1.0, "bell": 0.75, "bass": 0.95, "pad": 1.0, "arp": 0.9, "drums": 0.7},
        sends={"epiano": 0.45, "bell": 0.7, "pad": 0.25, "arp": 0.5},
        rev_amount=0.70, delay_bus="epiano", delay_time=0.391),
        ns(menu.length)))
    export("menu", x, os.path.join(OUT, "menu.ogg"), args.wav)


if __name__ == "__main__":
    main()
