#!/usr/bin/env python3
"""Wzorce (ZNAJDŹ WSZYSTKO NA KANAPIE, PODMIEŃ NA KANAPIE, ...): losowe wzory i teksty w jednym programie,
interpreter i skompilowany C muszą dać to samo, a wynik taki jak Python re dla tego podzbioru.
    python3 scripts/test_patterns.py [ile] [ziarno] [ferdek.exe]
"""
import json
import random
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COUNT = int(sys.argv[1]) if len(sys.argv) > 1 else 300
SEED = int(sys.argv[2]) if len(sys.argv) > 2 else 2026
FERDEK = sys.argv[3] if len(sys.argv) > 3 else str(ROOT / "_build" / "default" / "src" / "ferdek.exe")
rnd = random.Random(SEED)

ATOMS = ["a", "b", "ż", "1", " ", ".", "[ab]", "[^a]", "[a-c]", "[ż1]", "\\d", "\\w", "\\s", "\\D", "\\W", "\\.", "[\\d ]"]
TEXT = "abżc1 .9"


def pattern():
    parts = []
    for _ in range(rnd.randint(1, 4)):
        parts.append(rnd.choice(ATOMS) + rnd.choice(["", "", "*", "+", "?"]))
    p = "".join(parts)
    if rnd.random() < 0.2:
        p = "^" + p
    if rnd.random() < 0.2:
        p = p + "$"
    return p


def lit(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


cases = [(pattern(), "".join(rnd.choice(TEXT) for _ in range(rnd.randint(0, 8)))) for _ in range(COUNT)]
lines = ["CO JEST KURDE"]
for p, t in cases:
    lines.append(f"PANIE SENSACJA REWELACJA W MORDĘ JEŻA ZNAJDŹ WSZYSTKO NA KANAPIE({lit(t)}, {lit(p)})")
    lines.append(f"PANIE SENSACJA REWELACJA W MORDĘ JEŻA PODMIEŃ NA KANAPIE({lit(t)}, {lit(p)}, \"<>\")")
lines.append("MOJA NOGA JUŻ TUTAJ NIE POSTANIE\n")
with tempfile.NamedTemporaryFile("w", suffix=".ferdek", delete=False, encoding="utf-8") as f:
    f.write("\n".join(lines))


def run(mode):
    r = subprocess.run([FERDEK] + mode + [f.name], capture_output=True, text=True)
    return [l for l in (r.stdout + r.stderr).splitlines() if "Piwo dla Pana" not in l]


interp, compiled = run([]), run(["-r"])
Path(f.name).unlink()
fails = 0
if interp != compiled:
    fails += 1
    print("FAIL: interpreter i C się różnią")
for k, (p, t) in enumerate(cases):
    py = re.compile(p)
    want_all = "[" + ", ".join(py.findall(t)) + "]"
    want_sub = py.sub("<>", t)
    got_all, got_sub = interp[2 * k], interp[2 * k + 1]
    if (got_all, got_sub) != (want_all, want_sub):
        fails += 1
        if fails <= 10:
            print(f"FAIL wzór {p!r} tekst {t!r}: {got_all!r} {got_sub!r}, Python: {want_all!r} {want_sub!r}")
if fails:
    sys.exit(1)
print(f"--- wzorce: {COUNT} losowych przypadków jak w Python re, oba tryby zgodne")
