#!/usr/bin/env python3
"""Test serwera ferdek --lsp: definicje, użycia i zmiana nazwy na małym programie."""
import json
import os
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
CYCU PRZYNIEŚ NO h
TO NIE SĄ TANIE RZECZY JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(licz) NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
    I JA INFORMUJĘ ŻE WYCHODZĘ licz BABKA DAWAJ RENTĘ x
DO WIDZENIA PANU
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
"""

proc = subprocess.Popen([FERDEK, "--lsp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
next_id = 0
notifications = []


def read():
    length = None
    while True:
        line = proc.stdout.readline().strip()
        if not line:
            break
        k, v = line.split(b":", 1)
        if k.lower() == b"content-length":
            length = int(v)
    return json.loads(proc.stdout.read(length))


def diagnostics(uri):
    """Ostatnie publishDiagnostics dla dokumentu (serwer wysyła je od razu po didOpen/didChange)"""
    while True:
        for n in reversed(notifications):
            if n["method"] == "textDocument/publishDiagnostics" and n["params"]["uri"] == uri:
                notifications.remove(n)
                return n["params"]["diagnostics"]
        notifications.append(read())


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
    while True:
        resp = read()
        if "id" not in resp:
            notifications.append(resp)
            continue
        assert resp["id"] == next_id, resp
        return resp


LINES = PROGRAM.split("\n")


def find(line, word, n=1):
    """(linia, kolumna) n-tego wystąpienia słowa w linii; kolumna w UTF-16 = w znakach (BMP)"""
    import re
    return (line, [m.start() for m in re.finditer(rf"(?<!\w){re.escape(word)}(?!\w)", LINES[line])][n - 1])


def at(spot, uri=URI):
    line, ch = spot
    return {"textDocument": {"uri": uri}, "position": {"line": line, "character": ch}}


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
      sorted([x_decl, find(14, "x"), find(19, "x"), find(23, "x")]))

# Lambda z blokiem: parametr widać w kolejnych liniach ciała
check("parametr lambdy z blokiem", spots([send("textDocument/definition", at(find(23, "licz")))["result"]]),
      [find(22, "licz")])

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

check("bez błędów", diagnostics(URI), [])

# Błędy na bieżąco: składnia (kilka naraz) i --check
BAD = "file:///zly.ferdek"
send("textDocument/didOpen", {"textDocument": {"uri": BAD, "text":
     "CO JEST KURDE\nCYCU PRZYNIEŚ NO a\nTO NIE SĄ TANIE RZECZY 1 BABKA DAWAJ RENTĘ\n"
     "PANIE SENSACJA REWELACJA a\nPANIE SENSACJA REWELACJA ( a\nPANIE SENSACJA REWELACJA 1\n"
     "MOJA NOGA JUŻ TUTAJ NIE POSTANIE\n"}}, request=False)
check("błędy składni", [d["range"]["start"]["line"] for d in diagnostics(BAD)], [2, 4])
send("textDocument/didChange", {"textDocument": {"uri": BAD}, "contentChanges": [{"text":
     "CO JEST KURDE\nPANIE SENSACJA REWELACJA nie_ma\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE\n"}]}, request=False)
d = diagnostics(BAD)
check("--check", [(x["range"]["start"]["line"], "Nieznana zmienna: nie_ma" in x["message"]) for x in d], [(1, True)])

# Podpowiedzi: słowo kluczowe, wbudowana funkcja, nazwa z pliku
hover = lambda spot: (send("textDocument/hover", at(spot))["result"] or {}).get("contents", {}).get("value", "")
check("hover słowo kluczowe", "Wypisz" in hover(find(20, "SENSACJA")), True)
check("hover wbudowana", "ILE MIEJSCA NA KANAPIE" in hover(find(20, "MIEJSCA")), True)
check("hover funkcja", hover(find(19, "f")).startswith("funkcja f(x, żółw)"), True)

# Uzupełnianie: "W MO" -> W MORDĘ JEŻA, podmieniając napisane "W MO"
send("textDocument/didChange", {"textDocument": {"uri": URI}, "contentChanges": [{"text":
     PROGRAM.replace("PANIE SENSACJA REWELACJA W MORDĘ JEŻA ILE", "PANIE SENSACJA REWELACJA W MO\nILE")}]}, request=False)
items = send("textDocument/completion", at((20, len("PANIE SENSACJA REWELACJA W MO"))))["result"]
w = [i for i in items if i["label"] == "W MORDĘ JEŻA"]
check("uzupełnianie słowa", [i["textEdit"]["range"]["start"]["character"] for i in w], [len("PANIE SENSACJA REWELACJA ")])
check("uzupełnianie nazw z pliku", {"f", "Licznik", "g"} <= {i["label"] for i in items}, True)

# Import JAKO: definicja l.dodaj w pliku modułu, uzupełnianie l.nazw
here = os.path.abspath("tests/integration/features/lsp_import.ferdek")
MURI = "file://" + here
send("textDocument/didOpen", {"textDocument": {"uri": MURI, "text":
     "CO JEST KURDE\nO KOGO MOJE PIĘKNE OCZY WIDZĄ moduly/licznik JAKO l\n"
     "PANIE SENSACJA REWELACJA W MORDĘ JEŻA l.dodaj(1)\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE\n"}}, request=False)
check("import bez błędów", diagnostics(MURI), [])
d = send("textDocument/definition", at((2, 40), MURI))["result"]
check("definicja w module", (d["uri"].endswith("moduly/licznik.ferdek"), d["range"]["start"]["line"]), (True, 11))
labels = {i["label"] for i in send("textDocument/completion", at((2, 38), MURI))["result"]}
check("uzupełnianie z modułu", {"l.dodaj", "l.stan", "l.Skarbonka"} <= labels, True)

send("shutdown", None)
send("exit", None, request=False)
check("kod wyjścia", proc.wait(timeout=5), 0)

if failures:
    sys.exit(1)
print("--- lsp: OK")
