#!/usr/bin/env python3
"""Wbudowuje moduły stdlib i przykłady w plac zabaw: embedded.ml z listą (ścieżka, tekst)."""
import sys
from pathlib import Path

root = Path(sys.argv[1])
files = sorted(root.glob("stdlib/KLAMOTY/**/*.ferdek")) + [root / n for n in sys.argv[2:]]


def q(t):
    return "{ferdek_src|" + t + "|ferdek_src}"


print("(* Wygenerowane przez playground/embed.py *)")
print("let files = [")
for f in files:
    name = f.relative_to(root / "stdlib") if "stdlib" in f.parts else Path("przyklady") / f.name
    print(f"  {q(str(name))}, {q(f.read_text(encoding='utf-8'))};")
print("]")
