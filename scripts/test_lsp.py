#!/usr/bin/env python3
"""Test serwera ferdek --lsp: definicje, użycia i zmiana nazwy na małym programie."""
import json
import subprocess
import sys

FERDEK = sys.argv[1] if len(sys.argv) > 1 else "_build/default/src/ferdek.exe"
URI = "file:///test.ferdek"
PROGRAM = """CO JEST KURDE
CYCU PRZYNIEŚ NO x
TO NIE SĄ TANIE RZECZY 1
ALE WIE PAN JA ZASADNICZO f
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO x, żółw
    CYCU PRZYNIEŚ NO y
    TO NIE SĄ TANIE RZECZY x BABKA DAWAJ RENTĘ żółw
    I JA INFORMUJĘ ŻE WYCHODZĘ y
DO WIDZENIA PANU
ALE JAJA Licznik
    CYCU PRZYNIEŚ NO stan
    TO NIE SĄ TANIE RZECZY 0
    ALE WIE PAN JA ZASADNICZO dodaj
        O KURDE MAM POMYSŁA stan A PROSZĘ BARDZO stan BABKA DAWAJ RENTĘ x NO I GITARA
    DO WIDZENIA PANU
DO WIDZENIA PANU
CYCU PRZYNIEŚ NO g
TO NIE SĄ TANIE RZECZY JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) x ROZDUPCĘ BANK 2
PANIE SENSACJA REWELACJA W MORDĘ JEŻA f(x, 2)
PANIE SENSACJA REWELACJA W MORDĘ JEŻA ILE MIEJSCA NA KANAPIE("a")
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
"""

proc = subprocess.Popen([FERDEK, "--lsp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
next_id = 0


def send(method, params, request=True):
    global next_id
    msg = {"jsonrpc": "2.0", "method": method, "params": params}
    if request:
        next_id += 1
        msg["id"] = next_id
    body = json.dumps(msg).encode()
    proc.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    proc.stdin.flush()
    if not request:
        return None
    length = None
    while True:
        line = proc.stdout.readline().strip()
        if not line:
            break
        k, v = line.split(b":", 1)
        if k.lower() == b"content-length":
            length = int(v)
    resp = json.loads(proc.stdout.read(length))
    assert resp["id"] == next_id, resp
    return resp


LINES = PROGRAM.split("\n")


def find(line, word, n=1):
    """(linia, kolumna) n-tego wystąpienia słowa w linii; kolumna w UTF-16 = w znakach (BMP)"""
    import re
    return (line, [m.start() for m in re.finditer(rf"(?<!\w){re.escape(word)}(?!\w)", LINES[line])][n - 1])


def at(spot):
    line, ch = spot
    return {"textDocument": {"uri": URI}, "position": {"line": line, "character": ch}}


def spots(locs):
    return sorted((l["range"]["start"]["line"], l["range"]["start"]["character"]) for l in locs)


failures = 0


def check(what, got, want):
    global failures
    if got != want:
        failures += 1
        print(f"FAIL {what}: {got} != {want}")


caps = send("initialize", {"capabilities": {}})["result"]["capabilities"]
check("capabilities", (caps["definitionProvider"], caps["renameProvider"]), (True, True))
send("initialized", {}, request=False)
send("textDocument/didOpen", {"textDocument": {"uri": URI, "languageId": "ferdek", "version": 1,
                                               "text": PROGRAM}}, request=False)

# Globalne x: deklaracja, użycie w metodzie i w wywołaniu; nie parametr f ani lambdy
x_decl = find(1, "x")
d = send("textDocument/definition", at(find(19, "x")))["result"]
check("definicja globalnego x", spots([d]), [x_decl])
check("użycia globalnego x", spots(send("textDocument/references", at(x_decl))["result"]),
      sorted([x_decl, find(14, "x"), find(19, "x")]))

# Parametr x funkcji f przesłania globalne
check("definicja parametru x", spots([send("textDocument/definition", at(find(7, "x")))["result"]]), [find(5, "x")])
# Polska nazwa: pozycje w jednostkach UTF-16
check("użycia żółw", spots(send("textDocument/references", at(find(5, "żółw")))["result"]),
      [find(5, "żółw"), find(7, "żółw")])

# Pole klasy w metodzie (drugie "stan" w linii 14 to odczyt)
check("pole w metodzie", spots([send("textDocument/definition", at(find(14, "stan", 2)))["result"]]), [find(11, "stan")])

# Parametr lambdy
check("parametr lambdy", spots([send("textDocument/definition", at(find(18, "x", 2)))["result"]]), [find(18, "x")])

# Zmiana nazwy funkcji: deklaracja + wywołanie
r = send("textDocument/rename", dict(at(find(3, "f")), newName="policz"))["result"]
edits = r["changes"][URI]
check("zmiana nazwy f", spots(edits), [find(3, "f"), find(19, "f")])
check("nowy tekst", {e["newText"] for e in edits}, {"policz"})

# Nie wolno: słowo kluczowe jako nazwa, nazwa wbudowana
check("zła nowa nazwa", "error" in send("textDocument/rename", dict(at(find(3, "f")), newName="NO JAK NIE JAK TAK")), True)
check("wbudowana", "error" in send("textDocument/rename", dict(at(find(20, "KANAPIE")), newName="z")), True)

send("shutdown", None)
send("exit", None, request=False)
check("kod wyjścia", proc.wait(timeout=5), 0)

if failures:
    sys.exit(1)
print("--- lsp: OK")
