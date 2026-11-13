"""Música y efectos sintetizados para el tráiler (sin archivos de audio)."""
import math
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 48000
rng = np.random.default_rng(5)


def tt(d):
    return np.arange(int(d * SR)) / SR


def noise(d):
    return rng.uniform(-1, 1, int(d * SR))


def lp(x, f, o=2):
    return sosfilt(butter(o, f, 'low', fs=SR, output='sos'), x)


def hp(x, f, o=2):
    return sosfilt(butter(o, f, 'high', fs=SR, output='sos'), x)


def bp(x, f1, f2, o=2):
    return sosfilt(butter(o, [f1, f2], 'band', fs=SR, output='sos'), x)


def ph(freq):
    return 2 * np.pi * np.cumsum(freq) / SR


def saw(freq, d):
    t = tt(d); return 2 * ((freq * t) % 1.0) - 1


# ------------------------------------------------------------- instrumentos
def kick(d=0.45, f1=48, f2=150):
    t = tt(d); s = np.sin(ph(f1 + (f2 - f1) * np.exp(-t * 32))) * np.exp(-t * 7.5)
    n = int(0.004 * SR); s[:n] += noise(0.004) * 0.5
    return s


def tom(f0=110, d=0.35):
    t = tt(d)
    return np.sin(ph(f0 * (0.75 + 0.35 * np.exp(-t * 18)))) * np.exp(-t * 9) + lp(noise(d), 2500) * 0.15 * np.exp(-t * 35)


def clap():
    d = 0.22; t = tt(d); env = np.exp(-t * 18) * 0.6
    for off in (0.0, 0.011, 0.022):
        env = env + np.where((t >= off) & (t < off + 0.008), 0.8, 0)
    return bp(noise(d), 900, 3200) * env * 0.8


def hat(open_=False):
    d = 0.18 if open_ else 0.05; t = tt(d)
    return hp(noise(d), 7000) * np.exp(-t * (14 if open_ else 70)) * 0.5


def crash(d=1.6):
    t = tt(d); return hp(noise(d), 3500) * np.exp(-t * 2.6) * 0.5


def bass(freq, d, bright=420):
    t = tt(d)
    s = lp(saw(freq, d), bright) * 0.8 + np.sin(2 * np.pi * freq * t) * 0.6
    return s * np.minimum(1, t / 0.006) * np.exp(-t * 4.0)


def marimba(freq, d=0.5):
    t = tt(d)
    s = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t * 25) + 0.12 * np.sin(2 * np.pi * freq * 2.01 * t)
    return s * np.exp(-t * 7) * np.minimum(1, t / 0.002)


def lead(freq, d=0.14):
    t = tt(d); s = lp(np.sign(np.sin(2 * np.pi * freq * t)), 2600)
    return s * np.exp(-t * 9) * np.minimum(1, t / 0.004) * 0.35


def pad(freqs, d, att=0.4, rel=0.5, cut=900):
    t = tt(d)
    s = sum(lp(saw(f * (1 + det), d), cut) for f in freqs for det in (-0.004, 0.004))
    env = np.minimum(1, t / att) * np.clip((d - t) / rel, 0, 1)
    return s * env / (len(freqs) * 2)


def cling(semi=0.0, g=1.0):
    k = 2 ** (semi / 12)
    a = np.sin(2 * np.pi * 988 * k * tt(0.05)) * 0.7
    t2 = tt(0.28); b = (np.sin(2 * np.pi * 1319 * k * t2) + 0.25 * np.sin(2 * np.pi * 2638 * k * t2)) * np.exp(-t2 * 11)
    return np.concatenate([a, b]) * 0.5 * g


def whoosh(d=0.3, up=True):
    t = tt(d); n = noise(d); lo = bp(n, 300, 1200); hi = bp(n, 1500, 6000)
    u = t / d if up else 1 - t / d
    return (lo * (1 - u) + hi * u) * np.sin(np.pi * t / d) ** 2 * 0.9


def boing():
    d = 0.42; t = tt(d)
    f = 210 * (1 + 0.9 * np.exp(-t * 10)) * (1 + 0.07 * np.sin(2 * np.pi * 16 * t))
    return np.sin(ph(f)) * np.exp(-t * 6) * 0.8


def tick():
    t = tt(0.025); return (np.sin(2 * np.pi * 2600 * t) * np.exp(-t * 220) + noise(0.025) * np.exp(-t * 400) * 0.4) * 0.6


def ding():
    t = tt(1.0)
    return (np.sin(2 * np.pi * 1568 * t) + 0.6 * np.sin(2 * np.pi * 2349 * t) + 0.25 * np.sin(2 * np.pi * 3136 * t)) * np.exp(-t * 4) * 0.45


def brass(freqs, d):
    t = tt(d); s = lp(sum(saw(f, d) for f in freqs) / len(freqs), 1800)
    return s * np.minimum(1, t / 0.03) * (0.75 + 0.25 * np.exp(-t * 6)) * np.clip((d - t) / 0.08, 0, 1)


def fanfare(base=1.0):
    A = [440 * base, 554.37 * base, 659.25 * base]; out = np.zeros(int(1.4 * SR))
    for k, (s0, d) in enumerate([(0.0, 0.11), (0.14, 0.11), (0.28, 1.0)]):
        sig = brass(A if k < 2 else A + [880 * base], d); i = int(s0 * SR); out[i:i + len(sig)] += sig
    return out * 0.6


def bleat():
    d = 0.6; t = tt(d); f = 300 * (1 + 0.06 * np.sin(2 * np.pi * 9 * t)) * (1 - 0.15 * t)
    s = lp(np.sign(np.sin(ph(f))), 1800)
    return s * np.minimum(1, t / 0.03) * np.exp(-t * 2.5) * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t)) * 0.35


def frost():
    d = 0.5; t = tt(d)
    return hp(noise(d), 3000) * np.exp(-t * 12) * 0.6 + np.sin(ph(2400 * np.exp(-t * 2.2))) * np.exp(-t * 5) * 0.4


def puff():
    d = 0.35; t = tt(d); return lp(noise(d), 900) * np.sin(np.pi * t / d) ** 2 * 0.6


def pop(f0=520):
    d = 0.09; t = tt(d); return np.sin(ph(f0 * (1 + 0.8 * t / d))) * np.exp(-t * 30) * 0.6


def tok():
    t = tt(0.08); return (np.sin(2 * np.pi * 780 * t) + 0.5 * np.sin(2 * np.pi * 1650 * t)) * np.exp(-t * 60) * 0.6


def tink():
    t = tt(0.8)
    return (np.sin(2 * np.pi * 3100 * t) + 0.7 * np.sin(2 * np.pi * 4650 * t) + 0.4 * np.sin(2 * np.pi * 6200 * t)) * np.exp(-t * 7) * 0.35


def sub(d=1.4, f=42):
    t = tt(d); return np.sin(2 * np.pi * f * t * (1 - 0.15 * t / d)) * np.exp(-t * 2.6)


def impact():
    s = np.zeros(int(1.8 * SR))
    for sig, g in ((kick(0.6), 1.0), (sub(), 0.9), (crash(1.8), 0.6)):
        s[:len(sig)] += sig * g
    return s


def riser(d):
    t = tt(d); u = t / d
    return bp(noise(d), 400, 5000) * u ** 2 * 0.6 + np.sin(ph(200 + 1400 * u ** 2)) * 0.25 * u ** 1.5


def whistle():
    d = 0.55; t = tt(d)
    s = np.sin(2 * np.pi * 2350 * t) * (0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 28 * t)))
    return s * np.minimum(1, t / 0.01) * np.clip((d - t) / 0.05, 0, 1) * 0.3


def arp(freqs, step=0.07, d=0.45):
    out = np.zeros(int((step * len(freqs) + d) * SR))
    for i, f in enumerate(freqs):
        s = marimba(f, d); j = int(i * step * SR); out[j:j + len(s)] += s
    return out


def hiss(d=0.6):
    t = tt(d); return bp(noise(d), 2500, 9000) * np.minimum(1, t / 0.03) * np.exp(-t * 4) * 0.7


def shing():
    t = tt(0.5)
    s = (np.sin(2 * np.pi * 2200 * t) + 0.6 * np.sin(2 * np.pi * 3520 * t) + 0.4 * np.sin(2 * np.pi * 5100 * t)) * np.exp(-t * 9) * 0.35
    s[:int(0.03 * SR)] += hp(noise(0.03), 4000) * 0.6
    return s


def creak():
    d = 0.5; t = tt(d); f = 90 * (1 + 0.5 * np.sin(2 * np.pi * 3 * t))
    s = lp(np.sign(np.sin(ph(f))), 900) * np.exp(-t * 3) * 0.35
    return s + lp(noise(d), 400) * np.exp(-t * 6) * 0.3


def warp(up=True):
    d = 0.4; t = tt(d); u = t / d
    f = (300 + 1500 * u ** 2) if up else (1800 - 1500 * u ** 0.5)
    return np.sin(ph(f)) * np.sin(np.pi * u) * 0.35 + bp(noise(d), 1000, 4000) * np.sin(np.pi * u) * 0.15


def zap():
    d = 0.35; t = tt(d)
    s = np.sign(np.sin(ph(140 + 60 * np.sin(2 * np.pi * 37 * t)))) * 0.25 + hp(noise(d), 2000) * 0.3
    return lp(s, 5000) * np.exp(-t * 6)


def boo():
    d = 0.7; t = tt(d); f = 420 * (1 - 0.3 * t / d) * (1 + 0.04 * np.sin(2 * np.pi * 6 * t))
    return (np.sin(ph(f)) + 0.3 * np.sin(ph(f * 2))) * np.sin(np.pi * t / d) * 0.25


# ------------------------------------------------------------- mezcla
TL_V1 = dict(groove=7.5, lift=99.0, frenzy=27.0, count=32.0, podium=34.0, end=37.0)
def build(events, total, path, tl=TL_V1):
    G, LIFT, FZ, CT, PD, EN = tl['groove'], tl['lift'], tl['frenzy'], tl['count'], tl['podium'], tl['end']
    N = int(SR * (total + 2))
    music = np.zeros((N, 2)); fx = np.zeros((N, 2))

    def put(buf, sig, t, g=1.0, pan=0.0):
        i = int(t * SR)
        if i < 0:
            sig = sig[-i:]; i = 0
        n = min(len(sig), N - i)
        if n <= 0:
            return
        a = (pan + 1) * math.pi / 4
        buf[i:i + n, 0] += sig[:n] * g * math.cos(a); buf[i:i + n, 1] += sig[:n] * g * math.sin(a)

    # -------- música
    put(music, pad([55, 110, 164.8], 4.0, att=1.6, rel=0.4, cut=500), 0.0, 0.7)
    put(music, pad([220, 261.63, 329.63], 2.8, att=0.05, rel=1.0, cut=1400), 4.98, 0.55)
    for i in range(8):
        put(music, tom(140 + i * 12, 0.25), G - 0.5 + i * 0.0625, 0.25 + i * 0.06)
    BASS = [55, 55, 65.41, 55, 73.42, 55, 82.41, 49.0]
    MEL = [440, 0, 523.25, 0, 587.33, 523.25, 440, 0, 392, 0, 440, 0, 523.25, 0, 659.25, 587.33]
    t = G; i = 0
    while t < FZ - 1e-6:
        kx = 2 ** (2 / 12) if t >= LIFT else 1.0
        pos = i % 8; bar = i // 8
        if pos in (0, 3, 4):
            put(music, kick(), t, 0.9)
        if pos in (2, 6):
            put(music, clap(), t, 0.55, 0.1)
        put(music, hat(pos == 7), t, 0.22 if pos % 2 else 0.12, -0.3)
        if pos == 7 or (pos == 5 and bar % 2 == 1):
            put(music, tom(120 if pos == 7 else 95), t, 0.45, 0.25)
        if not (FZ - 0.5 <= t < FZ):
            put(music, bass(BASS[pos] * kx, 0.23), t, 0.55)
        if bar >= 1 and t < FZ - 1.0:
            m = MEL[i % 16]
            if m:
                put(music, marimba(m * kx), t, 0.22, 0.2)
        t += 0.25; i += 1
    for k in range(16):
        put(music, clap(), FZ - 1.0 + k * 0.0625, 0.15 + k * 0.025)
    put(music, riser(1.0), FZ - 1.0, 0.55)
    ARP = [440, 523.25, 659.25, 880]
    t = FZ; i = 0
    while t < CT - 1e-6:
        pos = i % 16
        if pos % 4 == 0:
            put(music, kick(), t, 1.0)
        if pos in (4, 12):
            put(music, clap(), t, 0.6, 0.1)
        if pos % 4 == 2:
            put(music, tom(130), t, 0.35, 0.25)
        put(music, hat(), t, 0.16, -0.3)
        if pos % 2 == 0:
            put(music, bass(BASS[(i // 2) % 8] * 2, 0.12, bright=900), t, 0.5)
        put(music, lead(ARP[pos % 4] * (1.5 if (i // 16) % 2 else 1.0)), t, 0.35, 0.15)
        t += 0.125; i += 1
    put(music, pad([55, 82.41], 2.0, att=0.6, rel=0.6, cut=300), CT, 0.35)
    put(music, pad([220, 277.18, 329.63, 440], 3.0, att=0.3, rel=1.0, cut=1600), PD, 0.45)
    for k in range(6):
        put(music, kick(0.3), PD + k * 0.5, 0.45)
    put(music, pad([110, 164.81, 220, 261.63, 329.63], 5.0, att=0.2, rel=1.8, cut=1300), EN, 0.55)
    put(music, arp([880, 1046.5, 1318.5, 1760, 2093], 0.12, 1.2), EN + 0.6, 0.18)

    # -------- efectos
    last_land = -1.0
    for ev in events:
        t, k = ev[0], ev[1]; a = ev[2:]
        if k == 'heart':
            put(fx, kick(0.35, 38, 85), t, 0.9 * a[0])
        elif k == 'blink':
            put(fx, pop(900), t, 0.15)
        elif k == 'riser':
            put(fx, riser(a[0]), t, 0.5)
        elif k == 'tok':
            put(fx, tok(), t, 0.5, float(rng.uniform(-0.4, 0.4)))
        elif k in ('impact', 'final'):
            put(fx, impact(), t, 0.85)
        elif k == 'tink':
            put(fx, tink(), t, 0.6, 0.3)
        elif k == 'pop':
            put(fx, pop(), t, 0.45)
        elif k == 'fill':
            pass
        elif k == 'land':
            if t - last_land > 0.03:
                put(fx, cling(float(rng.uniform(5, 14)), 0.12), t, 1.0, (a[0] * 2 - 1) * 0.6); last_land = t
        elif k == 'puff':
            put(fx, puff(), t, 0.45)
        elif k == 'coin':
            pid, combo = a
            if pid == 0:
                put(fx, cling(min(combo - 1, 19)), t, 0.8)
            else:
                put(fx, cling(float(rng.uniform(0, 5)), 0.3), t, 1.0, [-0.6, 0.6, -0.3][pid - 1])
        elif k == 'tier':
            pid, tier = a
            if pid == 0 and tier < 3:
                put(fx, arp([440 * (1 + tier * 0.25), 554.37 * (1 + tier * 0.25), 659.25 * (1 + tier * 0.25)], 0.05, 0.4), t, 0.35)
            elif pid == 0:
                put(fx, impact(), t, 0.7); put(fx, arp([880, 1108.7, 1318.5, 1760, 2217.5], 0.06, 0.6), t, 0.4)
        elif k == 'word':
            put(fx, kick(0.3), t, 0.45); put(fx, tok(), t, 0.3)
        elif k == 'windup':
            put(fx, pop(300), t, 0.4)
        elif k in ('dash', 'whoosh', 'pin'):
            put(fx, whoosh(0.22 if k != 'whoosh' else 0.35), t, 0.8)
        elif k == 'hit':
            put(fx, boing(), t, 0.9); put(fx, kick(0.3), t, 0.6); put(fx, crash(0.5), t, 0.3)
        elif k in ('scatter', 'pinhit'):
            n = a[0] if a else 5
            if k == 'pinhit':
                put(fx, tom(200, 0.2), t, 0.7)
            for j in range(n + 2):
                put(fx, cling(float(rng.uniform(2, 12)), 0.35), t + 0.05 + j * 0.06, 1.0, float(rng.uniform(-0.5, 0.5)))
        elif k == 'chest':
            put(fx, tok(), t, 0.6); put(fx, pop(400), t + 0.05, 0.4)
        elif k == 'tick':
            put(fx, tick(), t, 0.5)
        elif k == 'ding':
            put(fx, ding(), t, 0.6)
        elif k == 'legend':
            put(fx, fanfare(), t, 0.75); put(fx, crash(1.5), t, 0.4); put(fx, sub(1.0), t, 0.5)
        elif k == 'activate':
            put(fx, arp([1318.5, 1568, 1975.5, 2637], 0.05, 0.5), t, 0.35); put(fx, whoosh(0.3), t, 0.3)
        elif k == 'sheep':
            put(fx, puff(), t, 0.5); put(fx, bleat(), t + 0.08, 0.8)
        elif k == 'frost':
            put(fx, frost(), t, 0.8)
        elif k == 'cut':
            put(fx, whoosh(0.15), t, 0.35)
        elif k == 'frenzy':
            put(fx, impact(), t, 0.8); put(fx, fanfare(1.5), t + 0.05, 0.45)
        elif k == 'count':
            put(fx, tom(90, 0.5), t, 1.0); put(fx, kick(), t, 0.8)
        elif k == 'tiempo':
            put(fx, whistle(), t, 0.9); put(fx, crash(1.4), t, 0.5); put(fx, kick(), t, 0.8)
        elif k == 'thump':
            put(fx, tom(70, 0.4), t, 0.7)
        elif k == 'victory':
            put(fx, arp([440, 554.37, 659.25, 880], 0.11, 0.5), t, 0.5)
            put(fx, brass([440, 554.37, 659.25], 1.2), t + 0.46, 0.35)
        elif k == 'crown':
            put(fx, ding(), t, 0.3); put(fx, pop(700), t, 0.25)
        elif k == 'roots':
            put(fx, creak(), t, 0.8); put(fx, tom(60, 0.4), t, 0.5)
        elif k == 'warn':
            put(fx, tick(), t, 0.4); put(fx, tick(), t + 0.12, 0.4)
        elif k == 'spikes':
            put(fx, shing(), t, 0.8)
        elif k == 'ghost':
            put(fx, boo(), t, 0.6)
        elif k == 'fuse':
            put(fx, hiss(0.4), t, 0.35)
        elif k == 'boom':
            put(fx, impact(), t, 0.9); put(fx, puff(), t, 0.5)
        elif k == 'vent':
            put(fx, hiss(0.7), t, 0.6)
        elif k == 'portal':
            put(fx, warp(True), t, 0.7); put(fx, warp(False), t + 0.3, 0.6)
        elif k == 'zap':
            put(fx, zap(), t, 0.5)
        elif k == 'slam':
            put(fx, tom(70, 0.4), t, 0.8); put(fx, kick(0.3), t, 0.5)
        elif k == 'award':
            put(fx, pop(700), t, 0.45); put(fx, tick(), t, 0.3)

    mix = music * 0.55 + fx * 0.8
    mix = np.tanh(mix * 1.1) / np.tanh(1.1)
    mix /= max(1e-6, np.abs(mix).max()) / 0.93
    n_end = int(total * SR); mix = mix[:n_end]
    fade = int(0.8 * SR); mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
    wavfile.write(path, SR, (mix * 32767).astype(np.int16))
