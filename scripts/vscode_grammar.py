#!/usr/bin/env python3
"""Generuje dla rozszerzenia VS Code gramatykę TextMate (kolorowanie) i keywords.json
(podpowiedzi, uzupełnianie) z src/lexer.mll.

Lekser jest jedynym źródłem prawdy o słowach kluczowych - uruchom po każdej zmianie:
    python3 scripts/vscode_grammar.py ferdek-vscode
Nowe słowo bez opisu w DOCS przerywa generowanie. Jeśli ferdek jest zbudowany,
każdy snippet przechodzi przez parser (zepsuty snippet też przerywa).
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Token z leksera -> zakres kolorowania
SCOPES = {
    "keyword.control.ferdek": """IF ELSE ELSE_IF END_IF WHILE END_WHILE FOR FOR_FROM FOR_TO FOR_STEP
        TRY CATCH THROW BREAK CONTINUE RETURN PROGRAM_START PROGRAM_END""",
    "storage.type.ferdek": """VAR_DECL VAR_INIT ARRAY_DECL FUNC_DECL FUNC_RETURNS FUNC_PARAMS FUNC_END
        CLASS EXTENDS STRUCT END_STRUCT UNION END_UNION ENUM END_ENUM IMPORT""",
    "keyword.other.ferdek": """PRINT PRINT_INLINE PRINT_NEWLINE READ ASSIGN_START ASSIGN_OP ASSIGN_END
        FUNC_CALL FUNC_CALL_ASSIGN ARRAY_INDEX NEW NEW_STRUCT NEW_UNION POINTER_REF POINTER_DEREF
        POINTER_ADDR POINTER_STEP_FORWARD POINTER_STEP_BACK TO_FIXED FROM_FIXED""",
    "keyword.operator.arithmetic.ferdek": "PLUS MINUS MULTIPLY DIVIDE MODULO",
    "keyword.operator.comparison.ferdek": "EQUAL NOT_EQUAL GREATER LESS GREATER_EQUAL",
    "keyword.operator.logical.ferdek": "AND OR NOT",
    "keyword.operator.bitwise.ferdek": "BIT_AND BIT_OR BIT_XOR BIT_SHIFT_LEFT BIT_SHIFT_RIGHT BIT_NOT",
    "constant.language.ferdek": "TRUE FALSE NULL",
}
TOKEN_SCOPE = {tok: scope for scope, toks in SCOPES.items() for tok in toks.split()}
BUILTIN_SCOPE = "support.function.builtin.ferdek"

# Litera/cyfra z polskimi znakami - \b w Oniguruma nie zawsze zna ą, ł...
W = r"[\p{L}\p{N}_]"


def keywords():
    lexer = (ROOT / "src" / "lexer.mll").read_text(encoding="utf-8")
    found = {}
    for text, action in re.findall(r'\|\s*"([^"]+)"\s*\{\s*([^}]*)\}', lexer):
        tok = action.strip()
        if tok.startswith("IDENTIFIER"):
            scope = BUILTIN_SCOPE
        elif tok in TOKEN_SCOPE:
            scope = TOKEN_SCOPE[tok]
        else:
            continue  # np. "..." - znaki interpunkcyjne kolorować nie trzeba
        found.setdefault(text, scope)
    unknown = sorted({a.strip() for _, a in re.findall(r'\|\s*"([^"]+)"\s*\{\s*([A-Z_]+)\s*\}', lexer)}
                     - set(TOKEN_SCOPE) - {"ELLIPSIS", "IDENTIFIER"})
    if unknown:
        sys.exit(f"Tokeny bez zakresu kolorowania, dopisz je do SCOPES: {unknown}")
    return found


def grammar():
    kws = keywords()
    # Najdłuższe najpierw: przy tej samej pozycji wygrywa pierwszy wzorzec,
    # więc "DO WIDZENIA PANU" musi być przed "DO", a "GRUBA ŚWINIA" przed "ŚWINIA"
    patterns = [{"name": scope, "match": f"(?<!{W}){re.escape(text)}(?!{W})"}
                for text, scope in sorted(kws.items(), key=lambda kv: (-len(kv[0]), kv[0]))]
    return {
        "$schema": "https://raw.githubusercontent.com/martinring/tmlanguage/master/tmlanguage.json",
        "name": "Ferdek",
        "scopeName": "source.ferdek",
        "comment": "Wygenerowane przez scripts/vscode_grammar.py w repo ferdek - nie edytuj ręcznie",
        "patterns": [
            {"name": "comment.line.ferdek", "match": "RYM CYM CYM.*$"},
            {"name": "string.quoted.double.ferdek", "begin": '"', "end": '"',
             "patterns": [{"name": "constant.character.escape.ferdek", "match": r"\\."}]},
            *patterns,
            {"name": "constant.numeric.float.ferdek", "match": rf"(?<!{W})-?\d+\.\d+(?!{W})"},
            {"name": "constant.numeric.integer.ferdek", "match": rf"(?<!{W})-?\d+(?!{W})"},
            {"name": "entity.name.module.ferdek", "match": r"\bKLAMOTY/[\p{L}_/]+"},
        ],
    }


# Opis każdego słowa (polska pisownia). Dla funkcji sygnatura to tekst wstawiany przy uzupełnianiu.
DOCS = {
    # Program
    "CO JEST KURDE": "Początek programu",
    "MOJA NOGA JUŻ TUTAJ NIE POSTANIE": "Koniec programu",
    "O KOGO MOJE PIĘKNE OCZY WIDZĄ": "Import: plik obok (moj_plik) albo moduł stdlib (KLAMOTY/SKRZYNKA)",
    "CYCU PRZYNIEŚ": "Import, krótsza forma: CYCU PRZYNIEŚ BABKA",
    # Zmienne i wypisywanie
    "CYCU PRZYNIEŚ NO": "Deklaracja zmiennej: CYCU PRZYNIEŚ NO x / TO NIE SĄ TANIE RZECZY 5",
    "TO NIE SĄ TANIE RZECZY": "Wartość początkowa w deklaracji",
    "PANIE TO JEST PRYWATNA PUBLICZNA TABLICA": "Deklaracja tablicy",
    "O KURDE MAM POMYSŁA": "Przypisanie: O KURDE MAM POMYSŁA x A PROSZĘ BARDZO 5 NO I GITARA",
    "A PROSZĘ BARDZO": "Nowa wartość w przypisaniu",
    "NO I GITARA": "Koniec przypisania",
    "PANIE SENSACJA REWELACJA": "Wypisz wartość i zakończ linię",
    "JEDZIEM Z TYM ŚLEDZIEM": "Wypisz wartość bez końca linii",
    "NO TO ENTER": "Zakończ linię",
    "CO TAM U PANA SŁYCHAĆ": "Wczytaj linię z wejścia do zmiennej",
    "WYPIERDZIELAJ PAN NA POZYCJĘ": "Element tablicy: WYPIERDZIELAJ PAN NA POZYCJĘ t[0]",
    # Sterowanie
    "NO JAK NIE JAK TAK": "if",
    "AAA TO ZMIENIA POSTAĆ RZECZY": "else if",
    "A DUPA TAM": "else",
    "DO CHAŁUPY ALE JUŻ": "Koniec if / bloku catch",
    "CHLUŚNIEM BO UŚNIEM": "Pętla while",
    "KRĘCI CEMENT BETONIARA": "Pętla for: KRĘCI CEMENT BETONIARA i OD 1 DO 10 CO 2",
    "OD": "Początek zakresu pętli for",
    "DO": "Koniec zakresu pętli for (włącznie)",
    "CO": "Krok pętli for (domyślnie 1, ujemny liczy w dół)",
    "A ROBIĆ NI MA KOMU": "Koniec pętli",
    "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ": "break",
    "AKUKARACZA": "continue",
    "HELENA MUSZĘ CI COŚ POWIEDZIEĆ": "try",
    "HELENA MAM ZAWAŁ": "catch (zmienna z wyjątkiem); blok kończy DO CHAŁUPY ALE JUŻ",
    "O KARWASZ TWARZ": "Rzuć wyjątek",
    # Funkcje
    "ALE WIE PAN JA ZASADNICZO": "Definicja funkcji",
    "NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ": "Funkcja zwraca wartość",
    "NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO": "Parametry funkcji (a, b albo a, ... dla zmiennej liczby)",
    "DO WIDZENIA PANU": "Koniec funkcji / klasy",
    "I JA INFORMUJĘ ŻE WYCHODZĘ": "return",
    "W MORDĘ JEŻA": "Wywołanie funkcji: W MORDĘ JEŻA f(1, 2)",
    "AFERA JEST": "Wynik funkcji do zmiennej: AFERA JEST x W MORDĘ JEŻA f()",
    # Typy złożone
    "ALE JAJA": "Definicja klasy",
    "RENTA BABKI": "Dziedziczenie (extends)",
    "DZIAD ZDZIADZIAŁY JEDEN": "Nowy obiekt klasy",
    "MEBEL": "Definicja struktury",
    "KONIEC MEBLA": "Koniec struktury",
    "ZMONTUJ MEBEL": "Nowa struktura",
    "WCHODZIMY DO UNII": "Definicja unii",
    "KONIEC UNII EUROPEJSKIEJ": "Koniec unii",
    "WEJDŹ DO UNII": "Nowa unia",
    "PANIE LISTA": "Definicja enuma",
    "KONIEC LISTY": "Koniec enuma",
    # Wskaźniki i fixed-point
    "PALCEM POKAZUJĘ": "Wskaźnik do wartości albo funkcja jako wartość",
    "CO TAM JEST": "Wartość spod wskaźnika",
    "GDZIE STOI": "Adres zmiennej",
    "KROK DALEJ": "Przesunięcie wskaźnika do przodu",
    "KROK WSTECZ": "Przesunięcie wskaźnika do tyłu",
    "ZAMIEŃ NA FIXED": "Liczba na fixed-point 16.16",
    "WYJMIJ Z FIXED": "Fixed-point 16.16 na liczbę",
    # Operatory
    "BABKA DAWAJ RENTĘ": "+ (z tekstem skleja)",
    "PASZOŁ WON": "-",
    "ROZDUPCĘ BANK": "*",
    "MUSZĘ DO SRACZA": "/ (na liczbach całkowitych dzielenie całkowite)",
    "PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ": "% (reszta z dzielenia)",
    "TO PANU SIĘ CHCE WTEDY KIEDY MNIE": "==",
    "PAN TU NIE MIESZKASZ": "!=",
    "GRUBA ŚWINIA": ">",
    "ŁYSA PAŁA": "<",
    "ŚWINIA": "<",
    "JA JESTEM PONAD TO": ">=",
    "PIWO I TELEWIZOR": "and",
    "ALBO JUTRO U ADWOKATA": "or",
    "TAK BYĆ NIE BĘDZIE": "not",
    "WSZYSTKO MUSI BYĆ": "& (bitowe)",
    "COKOLWIEK MOŻE BYĆ": "| (bitowe)",
    "TYLKO JEDNO Z TEGO": "^ (bitowe)",
    "RUSZ SIĘ W LEWO": "<< (przesunięcie bitowe)",
    "RUSZ SIĘ W PRAWO": ">> (przesunięcie bitowe)",
    "NA OPAK": "~ (negacja bitowa)",
    # Stałe
    "A ŻEBYŚ PAN WIEDZIAŁ": "true",
    "GÓWNO PRAWDA": "false",
    "W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM": "null",
    # KANAPA - tekst
    "USIĄDŹ NA KANAPIE(a, b, ...)": "Sklej teksty",
    "ILE MIEJSCA NA KANAPIE(tekst)": "Długość tekstu (w bajtach)",
    "POTNIJ KANAPĘ(tekst, od, do)": "Fragment tekstu",
    "ROZCIĄGNIJ KANAPĘ(tekst, długość)": "Dopełnij spacjami do długości",
    "PRZESUŃ NA KANAPIE(tekst, separator)": "Podziel tekst na tablicę",
    "POSKŁADAJ KANAPĘ(tablica, separator)": "Sklej tablicę w tekst",
    "WYTRZEP KANAPĘ(tekst)": "Usuń białe znaki z brzegów",
    "ZAMIEŃ NA KANAPIE(tekst, stary, nowy)": "Zamień wszystkie wystąpienia",
    "ZNAK Z KANAPY(tekst, i)": "Znak na pozycji i",
    "KANAPA DO GÓRY(tekst)": "Wielkie litery (także polskie)",
    "KANAPA W DÓŁ(tekst)": "Małe litery (także polskie)",
    # WERSALKA - tablice
    "ILE NA WERSALCE(tablica)": "Długość tablicy",
    "POŁÓŻ NA WERSALCE(tablica, element)": "Nowa tablica z elementem na końcu",
    "ZDEJMIJ Z WERSALKI(tablica)": "Ostatni element",
    "CZY LEŻY NA WERSALCE(tablica, element)": "Czy tablica zawiera element",
    "TABLICA 2D(wiersze, kolumny)": "Tablica 2D wypełniona zerami",
    "TABLICA 3D(x, y, z)": "Tablica 3D wypełniona zerami",
    # SZAFKA - mapy
    "OTWÓRZ SZAFKĘ()": "Nowa, pusta mapa",
    "WŁÓŻ DO SZAFKI(mapa, klucz, wartość)": "Zapisz wartość pod kluczem",
    "WYJMIJ Z SZAFKI(mapa, klucz)": "Wartość spod klucza (null, gdy brak)",
    "WYRZUĆ ZE SZAFKI(mapa, klucz)": "Usuń klucz",
    "CZY W SZAFCE(mapa, klucz)": "Czy klucz istnieje",
    "WSZYSTKIE SZUFLADKI(mapa)": "Posortowana tablica kluczy",
    "ILE W SZAFCE(mapa)": "Liczba kluczy",
    # Typy liczbowe i losowanie
    "ZRÓB BAJCIK(x)": "Bajt 0-255",
    "ZRÓB KRÓTKI(x)": "Liczba 16-bitowa ze znakiem",
    "ZRÓB DŁUGI(x)": "Liczba całkowita (obcina liczbę z przecinkiem, tekst zamienia na liczbę)",
    "ZRÓB UŁAMEK(x)": "Fixed-point 16.16",
    "CO TO ZA TYP(x)": "Nazwa typu wartości",
    "KARTA LUBI DYM(min, max)": "Losowa liczba z zakresu; KARTA LUBI DYM(ziarno) ustawia ziarno",
    # KIBEL - pliki
    "OTWÓRZ KIBEL(ścieżka)": "Otwórz plik do odczytu",
    "OTWÓRZ KIBEL DO ZAPISU(ścieżka)": "Otwórz plik do zapisu",
    "ZAMKNIJ KIBEL(uchwyt)": "Zamknij plik",
    "SPUŚĆ WODĘ(uchwyt, dane)": "Zapisz do pliku",
    "WYPOMPUJ(uchwyt)": "Przeczytaj cały plik",
    "CZY KIBEL ZAJĘTY(ścieżka)": "Czy plik istnieje",
    "ZRÓB KIBEL(ścieżka)": "Utwórz katalog",
    "WYWAL KIBEL(ścieżka)": "Usuń katalog",
    "CO W KIBLU(ścieżka)": "Pliki w katalogu",
    "CZY TO KIBEL(ścieżka)": "Czy to katalog",
    "PRZEKOPIUJ KIBEL(skąd, dokąd)": "Skopiuj plik",
    "PRZENIEŚ KIBEL(skąd, dokąd)": "Przenieś plik",
    "WYKOP WSZYSTKIE KIBLE(ścieżka)": "Usuń katalog z zawartością",
    # Pamięć (alokator strefowy w stylu DOOM)
    "DAJ MI HAJS(rozmiar, tag)": "Zaalokuj blok pamięci",
    "ODDAJ WSZYSTKO(blok)": "Zwolnij blok",
    "KOMORNICZY WINDYKACJA(tag_od, tag_do)": "Zwolnij bloki o tagach z zakresu",
    "ZAPISZ DO BLOKU(blok, indeks, wartość)": "Zapisz w bloku",
    "CZYTAJ Z BLOKU(blok, indeks)": "Czytaj z bloku",
    "ROZMIAR BLOKU(blok)": "Rozmiar bloku",
    "ILE KASY LECI()": "Statystyki alokatora",
    "PISZ BAJT(blok, indeks, bajt)": "Zapisz bajt",
    "CZYTAJ BAJT(blok, indeks)": "Czytaj bajt",
    "KOPIUJ PAMIĘĆ(skąd, dokąd, rozmiar)": "Kopiuj pamięć (memcpy)",
    # TELEWIZOR - framebuffer i tablice
    "WŁĄCZ TELEWIZOR(szerokość, wysokość)": "Utwórz framebuffer",
    "WYŁĄCZ TELEWIZOR(ekran)": "Usuń framebuffer",
    "ZMIEŃ KANAŁ(ekran, x, y, kolor)": "Ustaw piksel",
    "CO LECI W TELEWIZORZE(ekran, x, y)": "Odczytaj piksel",
    "STWÓRZ TABELĘ(rozmiar)": "Utwórz tablicę wyszukiwania",
    "WPISZ DO TABELI(tabela, indeks, wartość)": "Zapisz w tablicy wyszukiwania",
    "SPRAWDŹ W TABELI(tabela, indeks)": "Odczytaj z tablicy wyszukiwania",
    # SKRZYNKA (import KLAMOTY/SKRZYNKA)
    "ILE W SKRZYNCE()": "SKRZYNKA: przybliżenie PI (liczba całkowita)",
    "POLICZ SKRZYNKI(liczba)": "SKRZYNKA: wartość bezwzględna",
    "ZAOKRĄGLIJ DO SKRZYNKI(liczba)": "SKRZYNKA: zaokrąglenie",
    "OTWÓRZ SKRZYNKĘ(podstawa, wykładnik)": "SKRZYNKA: potęga",
    "PODZIEL SKRZYNKI(a, b)": "SKRZYNKA: dzielenie całkowite",
    "RESZTA ZE SKRZYNKI(a, b)": "SKRZYNKA: reszta z dzielenia",
    "LOSUJ ZE SKRZYNKI(min, max)": "SKRZYNKA: losowa liczba",
    # KLATKA (import KLAMOTY/KLATKA)
    "WYJDŹ NA KLATKĘ(url)": "KLATKA: HTTP GET",
    "ZAPUKAJ DO SĄSIADA(url, dane)": "KLATKA: HTTP POST",
    "KTO NA KLATCE()": "KLATKA: twój publiczny adres IP",
    "CZY SĄSIAD W DOMU(host)": "KLATKA: ping",
    # BABKA - testy (import BABKA)
    "TAK JEST I KROPKA(warunek)": "BABKA: asercja prawdy",
    "GUZIK PRAWDA(warunek)": "BABKA: asercja fałszu",
    "MA BYĆ RÓWNE(oczekiwane, rzeczywiste)": "BABKA: asercja równości",
    "MOJE LEPSZE(nieoczekiwane, rzeczywiste)": "BABKA: asercja różności",
    "TEN SAM BAJZEL(a, b)": "BABKA: to samo",
    "DZIŚ GORSZY BAJZEL(a, b)": "BABKA: nie to samo",
    "ZERO(wartość)": "BABKA: asercja null",
    "PIENIĄDZE SĄ(wartość)": "BABKA: asercja nie-null",
    "JA TU RZĄDZĘ(wynik)": "BABKA: asercja wyniku operacji",
    "NIKT LEPIEJ ODE MNIE(wynik)": "BABKA: zaprzeczenie wyniku operacji",
    "WSZYSCY OBLANI(wiadomość)": "BABKA: oblej test",
    "OLEWAM TO(wiadomość)": "BABKA: pomiń test",
    "WYGRAŁAM()": "BABKA: zalicz test",
    "BABKA PODSUMUJ()": "BABKA: raport; błąd, jeśli coś oblano",
}


def keyword_docs():
    """Lista {word, insert, doc, kind} dla każdego słowa z leksera (bez wariantów ASCII)."""
    kws = keywords()
    by_word = {k.split("(")[0]: (k, v) for k, v in DOCS.items()}
    ascii_of = str.maketrans("ĄĆĘŁŃÓŚŹŻ", "ACELNOSZZ")
    # Warianty bez polskich znaków o nieregularnej pisowni (PRZYNES zamiast PRZYNIES)
    polish = {w.translate(ascii_of) for w in kws if w != w.translate(ascii_of)} | {"CYCU PRZYNES", "CYCU PRZYNES NO"}
    out, missing = [], []
    for word, scope in sorted(kws.items()):
        if word in polish and word not in by_word:
            continue  # wariant bez polskich znaków - opisany przy polskiej pisowni
        if word not in by_word:
            missing.append(word)
            continue
        insert, doc = by_word[word]
        out.append({"word": word, "insert": insert, "doc": doc,
                    "kind": "function" if scope == BUILTIN_SCOPE else "keyword"})
    if missing:
        sys.exit(f"Słowa bez opisu, dopisz je do DOCS: {missing}")
    return out


def snippet_programs(body):
    """Snippet po wstawieniu wartości domyślnych: jako instrukcje i jako wyrażenie."""
    text = "\n".join(body if isinstance(body, list) else [body])
    text = re.sub(r"\$\{\d+\|([^,|}]*)[^}]*\|\}", r"\1", text)      # ${1|a,b|} -> a
    while re.search(r"\$\{\d+:([^${}]*)\}", text):
        text = re.sub(r"\$\{\d+:([^${}]*)\}", r"\1", text)             # ${1:x} -> x
    text = re.sub(r"\$\{?\d+\}?", "x", text)
    if text.startswith("CO JEST KURDE"):
        return [text]
    wrap = lambda t: f"CO JEST KURDE\n{t}\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE\n"
    return [wrap(text), wrap("PANIE SENSACJA REWELACJA " + text)]


def check_snippets(path):
    ferdek = ROOT / "_build" / "default" / "src" / "ferdek.exe"
    if not ferdek.exists():
        print("Pomijam sprawdzanie snippetów - najpierw zbuduj ferdka (make)")
        return
    broken = []
    for name, snip in json.loads(path.read_text(encoding="utf-8")).items():
        errors = []
        for prog in snippet_programs(snip["body"]):
            with tempfile.NamedTemporaryFile("w", suffix=".ferdek", delete=False, encoding="utf-8") as f:
                f.write(prog)
            r = subprocess.run([str(ferdek), "--check", f.name], capture_output=True, text=True)
            os.unlink(f.name)
            if not re.search("Parsowania|Leksera|Preprocesora", r.stderr):
                break
            errors.append(r.stderr.strip().splitlines()[0])
        else:
            broken.append(f"{name}: {errors[0]}")
    if broken:
        sys.exit("Zepsute snippety:\n" + "\n".join(broken))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Użycie: python3 scripts/vscode_grammar.py <katalog ferdek-vscode>")
    ext = Path(sys.argv[1])
    dump = lambda data: json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    (ext / "syntaxes" / "ferdek.tmLanguage.json").write_text(dump(grammar()), encoding="utf-8")
    (ext / "keywords.json").write_text(dump(keyword_docs()), encoding="utf-8")
    check_snippets(ext / "snippets" / "ferdek.json")
