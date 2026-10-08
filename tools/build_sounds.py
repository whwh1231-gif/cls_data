"""타닥 - 실제 기계식 스위치 녹음에서 타건음 파일을 만들어 내는 스크립트.

원본 (둘 다 MIT 라이선스, Licenses/ 폴더 참고):
  - Mechvibes  https://github.com/hainguyents13/mechvibes   (체리 적/갈/흑/청축 PBT, EG Crystal Purple)
  - kbsim      https://github.com/tplai/kbsim               (NovelKeys Cream)

준비:  git clone 으로 두 저장소를 받고, ffmpeg 를 설치한 뒤
실행:  python3 tools/build_sounds.py <mechvibes 폴더> <kbsim 폴더>
결과:  Shared/Sounds/{축}_{o|d}_{down1..5|up1..2|space|spaceup}.wav   (o = 기본, d = 흡음재)

하는 일: 키 하나의 녹음을 [누르는 소리 / 떼는 소리]로 나누고, 앞쪽 무음을 잘라
누르자마자 소리가 나게 한 뒤, 축끼리 음량을 맞춘다. 흡음재 버전은 같은 녹음에서
잔향과 고음을 줄여 만든다.
"""
import json, os, subprocess, sys, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Shared", "Sounds")
MS = SR / 1000

# Mechvibes 스프라이트 팩: 키 하나 = [시작ms, 길이ms], 그 안에 누름+뗌이 같이 들어 있다
SPRITE_PACKS = {
    "red": ("cherrymx-red-pbt", "sound.ogg"),
    "brown": ("cherrymx-brown-pbt", "sound.ogg"),
    "black": ("cherrymx-black-pbt", "sound.ogg"),
    "blue": ("cherrymx-blue-pbt", "sound.ogg"),
    "lavender": ("eg-crystal-purple", "purple.ogg"),   # 아크 라벤더 녹음이 없어 가장 가까운 택타일로 대체
}
LETTER_KEYS = [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 38, 44, 45, 46, 47, 48, 49, 50]
SPACE_KEY = 57
TARGET_RMS = 0.085     # 누르는 소리 앞 30ms 의 목표 음량 (축끼리 같게)


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<i2") / 32768


def smooth(x, ms=0.7):
    n = max(1, int(ms * MS))
    return np.convolve(np.abs(x), np.ones(n) / n, mode="same")


def onset(env, start, stop, ratio):
    """start~stop 구간에서 처음으로 (구간 최대값 x ratio)를 넘는 지점"""
    region = env[start:stop]
    if len(region) == 0 or region.max() <= 0:
        return None
    return start + int(np.argmax(region > region.max() * ratio))


def cut(x, a, b, max_ms):
    a = max(0, a - int(1.0 * MS))                       # 어택 직전 1ms 만 남김
    seg = x[a:min(b, a + int(max_ms * MS))].copy()
    fade = min(len(seg), int(6 * MS))
    seg[-fade:] *= np.linspace(1, 0, fade)
    return seg


def split(clip):
    """키 하나의 녹음 -> (누르는 소리, 떼는 소리). 떼는 소리가 불분명하면 None."""
    env = smooth(clip)
    p = onset(env, 0, len(clip), 0.25)
    if p is None:
        return None
    r = onset(env, p + int(55 * MS), len(clip), 0.2)
    if r is None or (r - p) / MS < 70 or (len(clip) - r) / MS < 35:
        return None
    return cut(clip, p, r - int(6 * MS), 110), cut(clip, r, len(clip), 90)


def trim(clip, max_ms):
    """이미 따로 녹음된 소리(kbsim): 앞 무음만 잘라낸다"""
    p = onset(smooth(clip), 0, len(clip), 0.25)
    return cut(clip, p or 0, len(clip), max_ms)


def clipped(x):
    """최대치에 3샘플 이상 연속으로 붙어 있으면 찌그러진 녹음으로 본다"""
    hot = (np.abs(x) > 0.995).astype(int)
    return bool(np.convolve(hot, np.ones(3, dtype=int), mode="valid").max() >= 3) if len(x) >= 3 else False


def rms30(x):
    return float(np.sqrt((x[: int(30 * MS)] ** 2).mean()))


def centroid(x):
    w = x[: int(40 * MS)]
    s = np.abs(np.fft.rfft(w * np.hanning(len(w))))
    return float((s * np.fft.rfftfreq(len(w), 1 / SR)).sum() / s.sum())


def pick(items, count, feats):
    """음량·음색이 중간값에 가까운 것부터 count 개 고른다 (튀는 녹음 제외)"""
    f = np.array(feats)
    z = np.abs((f - np.median(f, 0)) / (f.std(0) + 1e-9)).sum(1)
    return [items[i] for i in np.argsort(z)[:count]]


def dampen(x):
    """흡음재: 통울림(잔향)을 빨리 죽이고 고음을 눌러 낮고 단단하게"""
    t = np.arange(len(x)) / SR
    y = x * np.where(t < 0.006, 1.0, np.exp(-(t - 0.006) / 0.018))
    soft = sosfilt(butter(1, 5000, btype="low", fs=SR, output="sos"), y)
    low = sosfilt(butter(2, 400, btype="low", fs=SR, output="sos"), y)
    return (0.25 * y + 0.75 * soft + 0.3 * low) * 0.9


def save(name, x):
    peak = np.abs(x).max()
    if peak > 0.97:                 # 안전장치: 넘치는 파일만 살짝 줄임
        print("  (limited)", name, round(peak, 2))
        x = x * (0.97 / peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def export(switch, downs, ups, space, spaceup):
    level = np.median([rms30(d) for d in downs])
    gain = min(TARGET_RMS / level, 0.9 / max(np.abs(d).max() for d in downs))   # 축 하나에 게인 하나 → 누름/뗌 비율 보존
    fix = np.clip(rms30(space) / level, 1.0, 1.5) * level / rms30(space)   # 스페이스가 글자 키보다 작게 녹음된 경우 보정
    space, spaceup = space * fix, spaceup * fix
    parts = {f"down{i + 1}": d for i, d in enumerate(downs)}
    parts.update({f"up{i + 1}": u for i, u in enumerate(ups)})
    parts.update({"space": space, "spaceup": spaceup})
    for name, x in parts.items():
        save(f"{switch}_o_{name}", x * gain)
        save(f"{switch}_d_{name}", dampen(x * gain))
    print(f"{switch:9s} gain x{gain:4.1f}  down {len(downs)}  up {len(ups)}  "
          f"centroid {np.median([centroid(d) for d in downs]):5.0f}Hz")


def main(mechvibes, kbsim):
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".wav"):
            os.remove(os.path.join(OUT, f))

    for switch, (folder, sound) in SPRITE_PACKS.items():
        base = os.path.join(mechvibes, "src", "audio", folder)
        audio = decode(os.path.join(base, sound))
        defines = json.load(open(os.path.join(base, "config.json")))["defines"]

        starts = sorted(v[0] for v in defines.values() if v)

        def clip(key):
            # 팩에 적힌 길이는 떼는 소리 도중에 끊기므로, 다음 키가 시작되기 전까지 90ms 더 가져온다
            start, dur = defines[str(key)]
            following = [s for s in starts if s > start + dur]
            end = min(start + dur + 90, following[0] - 5 if following else start + dur + 90)
            return audio[int(start * MS): int(end * MS)]

        pairs = [s for s in (split(clip(k)) for k in LETTER_KEYS if defines.get(str(k))) if s]
        pairs = [(d, u) for d, u in pairs if not clipped(d)]                   # 찌그러진 녹음 제외
        downs = pick([d for d, _ in pairs], 5, [[rms30(d), centroid(d)] for d, _ in pairs])
        ups = pick([u for _, u in pairs], 2, [[rms30(u), centroid(u)] for _, u in pairs])
        space = split(clip(SPACE_KEY))
        export(switch, downs, ups, space[0], space[1])

    base = os.path.join(kbsim, "src", "assets", "audio", "cream")
    downs = [trim(decode(os.path.join(base, "press", f"GENERIC_R{i}.mp3")), 110) for i in range(5)]
    ups = [trim(decode(os.path.join(base, "release", "GENERIC.mp3")), 90)]
    export("cream", downs, ups,
           trim(decode(os.path.join(base, "press", "SPACE.mp3")), 140),
           trim(decode(os.path.join(base, "release", "SPACE.mp3")), 90))
    print("done:", len([f for f in os.listdir(OUT) if f.endswith(".wav")]), "files")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
