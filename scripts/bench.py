#!/usr/bin/env python3
"""Porównanie czasu: interpreter vs skompilowany C (bench/*.ferdek).

Wyniki (wyjście programu) muszą być identyczne; czasy to najlepszy z 3 przebiegów.
    python3 scripts/bench.py
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FERDEK = ROOT / "_build" / "default" / "src" / "ferdek.exe"


def best_time(cmd):
    best, out = None, None
    for _ in range(3):
        t = time.perf_counter()
        r = subprocess.run(cmd, capture_output=True, text=True)
        dt = time.perf_counter() - t
        out = "\n".join(l for l in r.stdout.splitlines() if "Piwo dla Pana" not in l)
        best = dt if best is None else min(best, dt)
    return best, out


def main():
    print(f"{'program':<12}{'interpreter':>13}{'C':>9}{'przyspieszenie':>16}")
    ok = True
    for prog in sorted((ROOT / "bench").glob("*.ferdek")):
        exe = ROOT / "_build" / f"bench_{prog.stem}"
        subprocess.run([str(FERDEK), "-c", str(prog), "-o", str(exe)], check=True, capture_output=True)
        ti, oi = best_time([str(FERDEK), str(prog)])
        tc, oc = best_time([str(exe)])
        same = oi == oc
        ok &= same
        print(f"{prog.stem:<12}{ti:>12.3f}s{tc:>8.3f}s{ti / tc:>15.1f}x" + ("" if same else "  RÓŻNE WYNIKI!"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
