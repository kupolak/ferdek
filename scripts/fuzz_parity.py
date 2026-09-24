#!/usr/bin/env python3
"""Losowe programy Ferdka uruchamiane w interpreterze i po kompilacji do C.

Wyjście (stdout + komunikat błędu) i kod wyjścia muszą być identyczne. Ziarno
czyni przebieg powtarzalnym; rozbieżny program ląduje w _build/fuzz_rozjazd_N.ferdek.

    python3 scripts/fuzz_parity.py [liczba_programow] [ziarno]
"""
import random
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FERDEK = ROOT / "_build" / "default" / "src" / "ferdek.exe"
BUILD = ROOT / "_build"

WORDS = ["piwo", "Ferdek", "kanapa", "żółw", "Halina", "a b", ""]


class Gen:
    def __init__(self, rnd):
        self.r = rnd
        # i0/i1 to liczniki pętli: czytać wolno, przypisywać nie (inaczej pętla bez końca)
        self.vars = {"int": ["i0", "i1", "i2", "k0", "k1"], "float": ["f0"], "str": ["s0"], "arr": ["t0"]}
        self.assignable = {"int": ["i2"], "float": ["f0"], "str": ["s0"], "arr": ["t0"]}
        self.funcs = []   # (nazwa, typ zwracany: "int" albo "mixed" - raz liczba, raz tekst)
        self.has_class = False

    def pick(self, xs):
        return self.r.choice(xs)

    # ---- wyrażenia danego typu ----
    def expr(self, t, d=0):
        leaf = d >= 3 or self.r.random() < 0.3
        g = getattr(self, "e_" + t)
        return g(leaf, d + 1)

    def e_int(self, leaf, d):
        if leaf:
            return self.pick([str(self.r.randint(-20, 20)), self.pick(self.vars["int"])])
        a, b = self.expr("int", d), self.expr("int", d)
        return self.pick([
            f"({a} BABKA DAWAJ RENTĘ {b})", f"({a} PASZOŁ WON {b})", f"({a} ROZDUPCĘ BANK {b})",
            f"({a} MUSZĘ DO SRACZA {self.r.choice([1, 2, 3, -4, 7])})",
            f"({a} MUSZĘ DO SRACZA i2)",   # i2 bywa zerem - błąd też musi być identyczny
            f"({a} PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ {self.r.choice([2, 3, -5])})",
            f"({a} WSZYSTKO MUSI BYĆ {b})", f"({a} TYLKO JEDNO Z TEGO {b})",
            f"W MORDĘ JEŻA ILE MIEJSCA NA KANAPIE({self.expr('str', d)})",
            f"W MORDĘ JEŻA ILE NA WERSALCE({self.expr('arr', d)})",
            f"W MORDĘ JEŻA ZRÓB DŁUGI({self.expr('float', d)})",
            *[f"W MORDĘ JEŻA {n}({self.expr('int', d)})" for n, rt in self.funcs if rt == "int"],
            *[f"W MORDĘ JEŻA {n}({self.expr('float', d)})" for n, rt in self.funcs if rt == "int" and self.r.random() < 0.1],
            *(["W MORDĘ JEŻA ile0()"] if self.has_class else []),
            f'W MORDĘ JEŻA ILE W SZAFCE(W MORDĘ JEŻA OTWÓRZ SZAFKĘ("a", {self.expr("int", d)}, "b", 2))',
        ])

    def e_float(self, leaf, d):
        if leaf:
            return self.pick([f"{self.r.uniform(-9, 9):.2f}", self.pick(self.vars["float"])])
        a, b = self.expr("float", d), self.expr(self.pick(["float", "int"]), d)
        return self.pick([
            f"({a} BABKA DAWAJ RENTĘ {b})", f"({a} PASZOŁ WON {b})", f"({a} ROZDUPCĘ BANK {b})",
            f"({a} MUSZĘ DO SRACZA {self.r.choice(['2.5', '4', '-0.5'])})",
            f"W MORDĘ JEŻA PIERWIASTEK ZE SKRZYNKI({a} ROZDUPCĘ BANK {a})",
            f"W MORDĘ JEŻA SINUS ZE SKRZYNKI({a})",
        ])

    def e_str(self, leaf, d):
        if leaf:
            return self.pick([f'"{self.pick(WORDS)}"', self.pick(self.vars["str"])])
        a = self.expr("str", d)
        return self.pick([
            f"({a} BABKA DAWAJ RENTĘ {self.expr(self.pick(['str', 'int', 'float']), d)})",
            f"W MORDĘ JEŻA KANAPA DO GÓRY({a})", f"W MORDĘ JEŻA KANAPA W DÓŁ({a})",
            f'W MORDĘ JEŻA ZAMIEŃ NA KANAPIE({a}, "a", "O")',
            f"W MORDĘ JEŻA USIĄDŹ NA KANAPIE({a}, {self.expr('int', d)}, {self.expr('str', d)})",
            f'W MORDĘ JEŻA POSKŁADAJ KANAPĘ({self.expr("arr", d)}, "-")',
            f"W MORDĘ JEŻA CO TO ZA TYP({self.expr(self.pick(['int', 'float', 'arr']), d)})",
            f"W MORDĘ JEŻA POTNIJ KANAPĘ({a}, {self.r.randint(0, 2)}, {self.r.randint(1, 4)})",
            f"W MORDĘ JEŻA ZNAK Z KANAPY({a}, {self.r.randint(0, 3)})",
            *[f"W MORDĘ JEŻA {n}({self.expr('int', d)})" for n, rt in self.funcs if rt == "mixed"],
        ])

    def e_bool(self, leaf, d):
        t = self.pick(["int", "float", "str"])
        op = self.pick(["TO PANU SIĘ CHCE WTEDY KIEDY MNIE", "PAN TU NIE MIESZKASZ", "GRUBA ŚWINIA",
                        "ŁYSA PAŁA", "JA JESTEM PONAD TO"])
        cmp = f"({self.expr(t, d)} {op} {self.expr(t, d)})"
        if leaf:
            return cmp
        return self.pick([cmp, f"(TAK BYĆ NIE BĘDZIE {cmp})",
                          f"({cmp} PIWO I TELEWIZOR {self.expr('bool', d)})",
                          f"({cmp} ALBO JUTRO U ADWOKATA {self.expr('bool', d)})"])

    def e_arr(self, leaf, d):
        if leaf:
            if self.r.random() < 0.5:
                return self.pick(self.vars["arr"])
            return "[" + ", ".join(str(self.r.randint(-9, 9)) for _ in range(self.r.randint(0, 4))) + "]"
        a = self.expr("arr", d)
        return self.pick([
            f"W MORDĘ JEŻA POSKŁADAJ WERSALKĘ({a})", f"W MORDĘ JEŻA ODWRÓĆ WERSALKĘ({a})",
            f"W MORDĘ JEŻA POŁÓŻ NA WERSALCE({a}, {self.expr('int', d)})",
            f"[{self.expr('int', d)}, {self.expr('int', d)}]",
            f"W MORDĘ JEŻA PRZERABIAJ WERSALKĘ({a}, {self.lam(d)})",
        ])

    # Lambda int -> int; ciało sięga też po zmienne z otoczenia (w funkcji: łapanie przez wartość)
    def lam(self, d):
        self.vars["int"].append("x")
        body = self.expr("int", d)
        # Z ciałem z instrukcjami; przypisania do globalnych tworzą w lambdzie lokalne
        block = self.stmts(1, 2, "    ") if self.r.random() < 0.3 else None
        self.vars["int"].remove("x")
        if block is not None:
            return ("JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ\n"
                    + "\n".join(block) + f"\n    I JA INFORMUJĘ ŻE WYCHODZĘ {body}\nDO WIDZENIA PANU")
        return f"JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) {body}"

    # ---- instrukcje ----
    def stmts(self, n, d, ind):
        return [s for _ in range(n) for s in self.stmt(d, ind)]

    def stmt(self, d, ind):
        t = self.pick(["int", "float", "str", "arr"])
        kinds = ["print", "print", "print", "assign", "assign", "map"] + (["if", "for", "while", "try"] if d < 2 else [])
        k = self.pick(kinds)
        if k == "print":
            return [f"{ind}PANIE SENSACJA REWELACJA {self.expr(self.pick(['int', 'float', 'str', 'arr', 'bool']), 0)}"]
        if k == "assign":
            return [f"{ind}O KURDE MAM POMYSŁA {self.pick(self.assignable[t])} A PROSZĘ BARDZO {self.expr(t, 0)} NO I GITARA"]
        if k == "map":
            return self.pick([
                [f"{ind}W MORDĘ JEŻA WŁÓŻ DO SZAFKI(m0, {self.expr('str', 1)}, {self.expr('int', 1)})"],
                [f"{ind}KRĘCI CEMENT BETONIARA klucz{d} Z m0",
                 f"{ind}    PANIE SENSACJA REWELACJA klucz{d} BABKA DAWAJ RENTĘ \"=\" BABKA DAWAJ RENTĘ W MORDĘ JEŻA WYJMIJ Z SZAFKI(m0, klucz{d})",
                 f"{ind}A ROBIĆ NI MA KOMU"],
                [f"{ind}O KURDE MAM POMYSŁA kasa0[\"stan\"] A PROSZĘ BARDZO {self.expr('int', 1)} NO I GITARA"]
                if self.has_class else [f"{ind}PANIE SENSACJA REWELACJA m0"],
            ])
        if k == "if":
            out = [f"{ind}NO JAK NIE JAK TAK {self.expr('bool', 0)}"] + self.stmts(2, d + 1, ind + "    ")
            if self.r.random() < 0.5:
                out += [f"{ind}AAA TO ZMIENIA POSTAĆ RZECZY {self.expr('bool', 0)}"] + self.stmts(1, d + 1, ind + "    ")
            if self.r.random() < 0.5:
                out += [f"{ind}A DUPA TAM"] + self.stmts(1, d + 1, ind + "    ")
            return out + [f"{ind}DO CHAŁUPY ALE JUŻ"]
        if k == "for":
            lo, hi = self.r.randint(-3, 3), self.r.randint(-3, 5)
            step = self.pick(["", " CO 2", " CO -1"])
            body = self.stmts(2, d + 1, ind + "    ")
            if self.r.random() < 0.3:
                body.append(f"{ind}    NO JAK NIE JAK TAK {self.expr('bool', 1)}")
                body.append(f"{ind}        {self.pick(['AKUKARACZA', 'A POCAŁUJCIE MNIE WSZYSCY W DUPĘ'])}")
                body.append(f"{ind}    DO CHAŁUPY ALE JUŻ")
            if self.r.random() < 0.4:   # pętla po elementach tablicy albo znakach tekstu
                coll = self.expr(self.pick(["arr", "str"]), 1)
                return ([f"{ind}KRĘCI CEMENT BETONIARA e{d} Z {coll}", f"{ind}    PANIE SENSACJA REWELACJA e{d}"]
                        + body + [f"{ind}A ROBIĆ NI MA KOMU"])
            # Każdy poziom zagnieżdżenia ma własny licznik - wspólny cofałby zewnętrzną pętlę w nieskończoność
            return [f"{ind}KRĘCI CEMENT BETONIARA k{d} OD {lo} DO {hi}{step}"] + body + [f"{ind}A ROBIĆ NI MA KOMU"]
        if k == "while":
            return ([f"{ind}O KURDE MAM POMYSŁA i0 A PROSZĘ BARDZO {self.r.randint(0, 4)} NO I GITARA",
                     f"{ind}CHLUŚNIEM BO UŚNIEM i0 GRUBA ŚWINIA 0"]
                    + self.stmts(1, d + 1, ind + "    ")
                    + [f"{ind}    O KURDE MAM POMYSŁA i0 A PROSZĘ BARDZO i0 PASZOŁ WON 1 NO I GITARA",
                       f"{ind}A ROBIĆ NI MA KOMU"])
        # try
        body = self.stmts(1, d + 1, ind + "    ")
        if self.r.random() < 0.6:
            body.append(f"{ind}    O KARWASZ TWARZ {self.expr(self.pick(['str', 'int']), 1)}")
        return ([f"{ind}HELENA MUSZĘ CI COŚ POWIEDZIEĆ"] + body
                + [f"{ind}HELENA MAM ZAWAŁ blad", f"{ind}    PANIE SENSACJA REWELACJA blad", f"{ind}DO CHAŁUPY ALE JUŻ"])

    # Funkcja z parametrem i0, zmienną lokalną a0, czasem pętlą i zmianą globalnej i2.
    # "mixed" zwraca raz liczbę, raz tekst - kompilator nie może jej wtedy traktować jak liczby.
    def function(self, name, kind):
        # a0 dopiero po deklaracji: odczyt przed nią to błąd tylko w interpreterze (C daje 0)
        body = [f"ALE WIE PAN JA ZASADNICZO {name}", "NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ",
                "NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO i0",
                "    CYCU PRZYNIEŚ NO a0", f"    TO NIE SĄ TANIE RZECZY {self.expr('int', 1)}"]
        self.vars["int"].append("a0")
        if self.r.random() < 0.5:
            body += [f"    KRĘCI CEMENT BETONIARA q OD 1 DO {self.r.randint(0, 4)}",
                     "        O KURDE MAM POMYSŁA a0 A PROSZĘ BARDZO a0 BABKA DAWAJ RENTĘ q NO I GITARA",
                     "    A ROBIĆ NI MA KOMU"]
        if self.r.random() < 0.3:
            body.append(f"    O KURDE MAM POMYSŁA i2 A PROSZĘ BARDZO {self.expr('int', 2)} NO I GITARA")
        other = self.expr("str", 1) if kind == "mixed" else self.expr("int", 1)
        if self.r.random() < 0.6 or kind == "mixed":
            body += [f"    NO JAK NIE JAK TAK {self.expr('bool', 1)}",
                     f"        I JA INFORMUJĘ ŻE WYCHODZĘ {self.expr('int', 1)}",
                     "    A DUPA TAM", f"        I JA INFORMUJĘ ŻE WYCHODZĘ {other}", "    DO CHAŁUPY ALE JUŻ"]
        else:
            body.append(f"    I JA INFORMUJĘ ŻE WYCHODZĘ {self.expr('int', 1)}")
        self.vars["int"].remove("a0")
        return body + ["DO WIDZENIA PANU"]

    def program(self):
        lines = ["CO JEST KURDE",
                 "CYCU PRZYNIEŚ NO i0", "TO NIE SĄ TANIE RZECZY 3",
                 "CYCU PRZYNIEŚ NO i1", "TO NIE SĄ TANIE RZECZY -2",
                 "CYCU PRZYNIEŚ NO i2", "TO NIE SĄ TANIE RZECZY 7",
                 "CYCU PRZYNIEŚ NO k0", "TO NIE SĄ TANIE RZECZY 0",
                 "CYCU PRZYNIEŚ NO k1", "TO NIE SĄ TANIE RZECZY 0",
                 "CYCU PRZYNIEŚ NO f0", "TO NIE SĄ TANIE RZECZY 1.5",
                 'CYCU PRZYNIEŚ NO s0', 'TO NIE SĄ TANIE RZECZY "Kiepski"',
                 "CYCU PRZYNIEŚ NO t0", "TO NIE SĄ TANIE RZECZY [3, 1, 2]"]
        lines += ['AFERA JEST m0 W MORDĘ JEŻA OTWÓRZ SZAFKĘ("piwo", 1, "wódka", 2)']
        for k in range(self.r.randint(0, 3)):
            name = f"fun{k}"
            kind = self.pick(["int", "int", "mixed"])
            lines += self.function(name, kind)   # zanim trafi do self.funcs - bez rekurencji
            self.funcs.append((name, kind))
        if self.r.random() < 0.5:
            self.vars["int"].append("stan")
            method = self.expr("int", 1)
            self.vars["int"].remove("stan")
            lines += ["ALE JAJA Kasa", "    CYCU PRZYNIEŚ NO stan", f"    TO NIE SĄ TANIE RZECZY {self.r.randint(-9, 9)}",
                      "    ALE WIE PAN JA ZASADNICZO ile", "    NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ",
                      f"        I JA INFORMUJĘ ŻE WYCHODZĘ {method}", "    DO WIDZENIA PANU", "DO WIDZENIA PANU",
                      "CYCU PRZYNIEŚ NO kasa0", "TO NIE SĄ TANIE RZECZY DZIAD ZDZIADZIAŁY JEDEN Kasa",
                      "CYCU PRZYNIEŚ NO ile0", 'TO NIE SĄ TANIE RZECZY WYPIERDZIELAJ PAN NA POZYCJĘ kasa0["ile"]']
            self.has_class = True
        lines += self.stmts(self.r.randint(8, 16), 0, "")
        return "\n".join(lines + ["MOJA NOGA JUŻ TUTAJ NIE POSTANIE", ""])


def run(args):
    try:
        r = subprocess.run([str(FERDEK)] + args, capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        return ("przekroczony czas", "")
    out = "\n".join(l for l in (r.stdout + r.stderr).splitlines() if "Piwo dla Pana" not in l)
    return r.returncode, out


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 2026
    rnd = random.Random(seed)
    bad = 0
    for n in range(count):
        src = Gen(rnd).program()
        path = BUILD / "fuzz_program.ferdek"
        path.write_text(src, encoding="utf-8")
        interp = run([str(path)])
        compiled = run(["-r", str(path)])
        if interp != compiled:
            bad += 1
            keep = BUILD / f"fuzz_rozjazd_{n}.ferdek"
            keep.write_text(src, encoding="utf-8")
            print(f"ROZJAZD w programie {n} (zapisany: {keep})")
            print(f"  interpreter (kod {interp[0]}): {interp[1][-300:]!r}")
            print(f"  kompilator  (kod {compiled[0]}): {compiled[1][-300:]!r}")
    print(f"--- fuzz: {count - bad}/{count} programów zgodnych (ziarno {seed})")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
