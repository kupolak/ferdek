#!/usr/bin/env python3
"""Sprawdza docs/SAMOUCZEK.md: każdy program (```ferdek) uruchamiamy interpreterem i skompilowany,
a wynik ma się zgadzać z blokiem pod nim. --update wpisuje aktualne wyniki (przejrzyj git diff).
    python3 scripts/test_tutorial.py [--update] [ferdek.exe]
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "SAMOUCZEK.md"
args = [a for a in sys.argv[1:] if a != "--update"]
FERDEK = args[0] if args else str(ROOT / "_build" / "default" / "src" / "ferdek.exe")
UPDATE = "--update" in sys.argv

# program, potem "Wynik:" i blok z wyjściem
PAIR = re.compile(r"```ferdek\n(.*?)```\n\nWynik:\n\n```\n(.*?)```", re.S)


def run(mode, src):
    with tempfile.NamedTemporaryFile("w", suffix=".ferdek", delete=False, encoding="utf-8") as f:
        f.write(src)
    r = subprocess.run([FERDEK] + mode + [f.name], capture_output=True, text=True, cwd=ROOT)
    Path(f.name).unlink()
    return "".join(l + "\n" for l in (r.stdout + r.stderr).splitlines() if "Piwo dla Pana" not in l)


text = DOC.read_text(encoding="utf-8")
failures = 0


def check(m):
    global failures
    src, expected = m.group(1), m.group(2)
    got = run([], src)
    compiled = run(["-r"], src)
    if got != compiled:
        failures += 1
        print(f"FAIL: interpreter i kompilator różnią się dla programu:\n{src}\n{got!r}\n{compiled!r}")
    if not UPDATE and got != expected:
        failures += 1
        print(f"FAIL: inny wynik niż w samouczku dla programu:\n{src}\noczekiwane: {expected!r}\njest: {got!r}")
    return m.group(0).replace("\n\n```\n" + expected + "```", "\n\n```\n" + got + "```", 1) if UPDATE else m.group(0)


new = PAIR.sub(check, text)
count = len(PAIR.findall(text))
if UPDATE:
    DOC.write_text(new, encoding="utf-8")
if failures:
    sys.exit(1)
print(f"--- samouczek: {count} programów OK")
