"""Genera la música chiptune ORIGINAL de Dijimones (sin samples ni temas oficiales).

Uso: python3 tools/make_music.py   -> game/assets/music/{menu,batalla}.wav (loops)
Sintetiza ondas cuadrada (melodía), triángulo (bajo) y ruido (batería), como una consola de 8 bits.
"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "music")

NOTES = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(note):
    """'E5' -> Hz. '-' = silencio."""
    if note == "-":
        return 0.0
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTES[name] + 12 * (octave - 4) - 9) / 12)


def square(t, f, duty=0.5):
    return 1.0 if (t * f) % 1.0 < duty else -1.0


def triangle(t, f):
    p = (t * f) % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def render(bpm, melody, bass, drums, duty, volume=0.28):
    """melody/bass: listas de (nota, corcheas). drums: string por corchea (k=bombo, s=caja, h=hi-hat, -=nada)."""
    eighth = 60.0 / bpm / 2
    total = int(sum(d for _, d in melody) * eighth * RATE)
    buf = [0.0] * total

    def put(track, fn, vol, release):
        i = 0
        for note, dur in track:
            f = freq(note)
            n = int(dur * eighth * RATE)
            if f > 0:
                for k in range(n):
                    if i + k >= total:
                        break
                    t = k / RATE
                    env = min(1.0, k / 60) * max(0.0, 1.0 - max(0, k - n * (1 - release)) / (n * release + 1))
                    buf[i + k] += fn(t, f) * vol * env
            i += n

    put(melody, lambda t, f: square(t, f, duty) + 0.3 * square(t, f * 1.003, duty), 0.16, 0.25)
    put(bass, triangle, 0.32, 0.1)
    rnd = random.Random(7)
    step = int(eighth * RATE)
    for j, h in enumerate(drums * (total // (step * len(drums)) + 1)):
        start = j * step
        if start >= total:
            break
        if h == "-":
            continue
        length = {"k": 0.12, "s": 0.1, "h": 0.03}[h]
        for k in range(int(length * RATE)):
            if start + k >= total:
                break
            t = k / RATE
            env = 1.0 - k / (length * RATE)
            if h == "k":
                s = math.sin(2 * math.pi * (60 + 120 * env) * t) * 0.5
            elif h == "s":
                s = (rnd.random() * 2 - 1) * 0.28
            else:
                s = (rnd.random() * 2 - 1) * 0.1
            buf[start + k] += s * env
    peak = max(abs(x) for x in buf) or 1.0
    return [x / peak * volume * 3 for x in buf]


def write(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
    print(path, round(len(samples) / RATE, 1), "s")


def chords(progression, octave=2, per=8):
    """Bajo: raíz y quinta alternadas en corcheas."""
    out = []
    for root, fifth in progression:
        for k in range(per):
            out.append(((root if k % 2 == 0 else fifth) + str(octave), 1))
    return out


# --- Batalla: 150 BPM, Do mayor, progresión I–V–vi–IV y puente IV–V–iii–vi (composición original) ---
A = [("E5", 2), ("G5", 1), ("C6", 3), ("B5", 1), ("G5", 1), ("A5", 2), ("G5", 2), ("E5", 2), ("D5", 2),
     ("E5", 2), ("G5", 1), ("A5", 3), ("G5", 1), ("E5", 1), ("D5", 4), ("-", 4)]
B = [("C5", 1), ("D5", 1), ("E5", 2), ("G5", 2), ("E5", 2), ("F5", 2), ("A5", 2), ("G5", 4),
     ("E5", 1), ("F5", 1), ("G5", 2), ("C6", 2), ("B5", 2), ("C6", 6), ("-", 2)]
C = [("A5", 2), ("G5", 2), ("F5", 2), ("E5", 2), ("G5", 3), ("F5", 1), ("E5", 2), ("D5", 2),
     ("E5", 2), ("D5", 2), ("C5", 2), ("E5", 2), ("D5", 6), ("G4", 2)]
battle_melody = A + B + C + B
prog_a = [("C", "G"), ("G", "D"), ("A", "E"), ("F", "C")]
prog_c = [("F", "C"), ("G", "D"), ("E", "B"), ("A", "E")]
battle_bass = chords(prog_a) + chords(prog_a) + chords(prog_c) + chords(prog_a)
battle = render(150, battle_melody, battle_bass, "k-h-s-h-k-k-s-h-", duty=0.25)

# --- Menú: 100 BPM, más tranquilo, melodía en La menor relativa ---
M1 = [("A4", 3), ("C5", 1), ("E5", 2), ("D5", 2), ("C5", 3), ("B4", 1), ("A4", 4),
      ("F4", 3), ("A4", 1), ("C5", 2), ("B4", 2), ("G4", 6), ("-", 2)]
M2 = [("A4", 3), ("C5", 1), ("E5", 2), ("G5", 2), ("F5", 3), ("E5", 1), ("D5", 4),
      ("C5", 2), ("B4", 2), ("G4", 2), ("B4", 2), ("A4", 6), ("-", 2)]
menu_melody = M1 + M2
prog_m = [("A", "E"), ("F", "C"), ("C", "G"), ("G", "D")]
menu_bass = chords(prog_m) + chords(prog_m)
menu = render(100, menu_melody, menu_bass, "k---h---s---h---", duty=0.5, volume=0.22)

os.makedirs(OUT, exist_ok=True)
write("batalla.wav", battle)
write("menu.wav", menu)
