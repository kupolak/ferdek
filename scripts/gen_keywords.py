#!/usr/bin/env python3
"""Generuje z src/language/lexer.mll wszystko, co opisuje słowa kluczowe:
  - docs/JEZYK.md - słownik języka,
  - src/tools/keyword_docs.ml - opisy dla ferdek --lsp (podpowiedzi, uzupełnianie),
  - dla rozszerzenia VS Code: gramatykę TextMate (kolorowanie); opisy i uzupełnianie daje ferdek --lsp
    z src/tools/keyword_docs.ml.

Lekser jest jedynym źródłem prawdy o słowach kluczowych - uruchom po każdej zmianie:
    python3 scripts/gen_keywords.py [ferdek-vscode]
    python3 scripts/gen_keywords.py --check     # czy docs/JEZYK.md jest aktualny (make test)
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
    "keyword.control.ferdek": """IF ELSE ELSE_IF END_IF SWITCH CASE DEFAULT END_SWITCH FINALLY WHILE END_WHILE FOR FOR_FROM FOR_TO FOR_STEP FOR_IN
        TRY CATCH THROW BREAK CONTINUE RETURN PROGRAM_START PROGRAM_END""",
    "storage.type.ferdek": """VAR_DECL CONST VAR_INIT ARRAY_DECL FUNC_DECL FUNC_RETURNS FUNC_PARAMS FUNC_END
        CLASS EXTENDS STRUCT END_STRUCT UNION END_UNION ENUM END_ENUM IMPORT IMPORT_AS""",
    "keyword.other.ferdek": """PRINT PRINT_INLINE PRINT_NEWLINE READ ASSIGN_START ASSIGN_OP ASSIGN_END
        FUNC_CALL FUNC_CALL_ASSIGN LAMBDA ARRAY_INDEX NEW NEW_STRUCT NEW_UNION POINTER_REF POINTER_DEREF
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
    lexer = (ROOT / "src" / "language" / "lexer.mll").read_text(encoding="utf-8")
    found = {}
    for text, action in re.findall(r'\|\s*"([^"]+)"\s*\{\s*([^}]*)\}', lexer):
        tok = action.strip()
        if tok.startswith("IDENTIFIER"):
            scope = BUILTIN_SCOPE
        elif tok.startswith("TYPE "):
            scope = "storage.type.ferdek"
        elif tok in TOKEN_SCOPE:
            scope = TOKEN_SCOPE[tok]
        elif "interp_start" in tok:   # POWIEM PANU TAK: tokeny robi dopiero czytanie tekstu
            scope = "keyword.other.ferdek"
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


# Opis każdego słowa (polska pisownia), w sekcjach dokumentacji.
# Dla funkcji sygnatura to tekst wstawiany przy uzupełnianiu.
SECTIONS = [
    ("Program", {
        "CO JEST KURDE": "Początek programu",
        "MOJA NOGA JUŻ TUTAJ NIE POSTANIE": "Koniec programu",
        "O KOGO MOJE PIĘKNE OCZY WIDZĄ": "Import: plik obok (moj_plik) albo moduł stdlib (KLAMOTY/SKRZYNKA)",
        "JAKO": "Import z przestrzenią nazw: O KOGO MOJE PIĘKNE OCZY WIDZĄ matma JAKO m, potem m.dodaj(1, 2), m.PI",
        "CYCU PRZYNIEŚ": "Import, krótsza forma: CYCU PRZYNIEŚ BABKA",
    }),
    ("Zmienne i wypisywanie", {
        "CYCU PRZYNIEŚ NO": "Deklaracja zmiennej: CYCU PRZYNIEŚ NO x / TO NIE SĄ TANIE RZECZY 5",
        "TO NIE SĄ TANIE RZECZY": "Wartość początkowa w deklaracji; w liście parametrów - wartość domyślna (ile TO NIE SĄ TANIE RZECZY 1)",
        "PANIE TO JEST PRYWATNA PUBLICZNA TABLICA": "Deklaracja tablicy",
        "O KURDE MAM POMYSŁA": "Przypisanie: O KURDE MAM POMYSŁA x A PROSZĘ BARDZO 5 NO I GITARA",
        "A PROSZĘ BARDZO": "Nowa wartość w przypisaniu",
        "NO I GITARA": "Koniec przypisania",
        "PANIE SENSACJA REWELACJA": "Wypisz wartość i zakończ linię",
        "JEDZIEM Z TYM ŚLEDZIEM": "Wypisz wartość bez końca linii",
        "POWIEM PANU TAK": "Tekst z wstawkami: POWIEM PANU TAK \"Piwa: {piwa}, jutro {piwa BABKA DAWAJ RENTĘ 2}\" - w {} dowolne wyrażenie; zwykły nawias klamrowy to \\{",
        "NO TO ENTER": "Zakończ linię",
        "CO TAM U PANA SŁYCHAĆ": "Wczytaj linię z wejścia do zmiennej",
        "WYPIERDZIELAJ PAN NA POZYCJĘ": "Element tablicy albo szafki: WYPIERDZIELAJ PAN NA POZYCJĘ t[0], t[-1] (ostatni), s[\"klucz\"] (null, gdy klucza nie ma)",
    }),
    ("Sterowanie", {
        "NO JAK NIE JAK TAK": "if",
        "AAA TO ZMIENIA POSTAĆ RZECZY": "else if",
        "A DUPA TAM": "else",
        "DO CHAŁUPY ALE JUŻ": "Koniec if / bloku catch",
        "CHLUŚNIEM BO UŚNIEM": "Pętla while",
        "KRĘCI CEMENT BETONIARA": "Pętla for: KRĘCI CEMENT BETONIARA i OD 1 DO 10 CO 2",
        "OD": "Początek zakresu pętli for",
        "DO": "Koniec zakresu pętli for (włącznie)",
        "CO": "Krok pętli for (domyślnie 1, ujemny liczy w dół)",
        "TO JE LICZBA SYNEK": "Typ: liczba całkowita (po nazwie zmiennej, parametru albo po NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ)",
        "TO JE LICZBA Z PRZECINKIEM": "Typ: liczba z przecinkiem",
        "TO SĄ STRINGI": "Typ: tekst",
        "TO JE TAK ALBO NIE": "Typ: prawda albo fałsz",
        "TO JE WERSALKA": "Typ: tablica",
        "TO JE SZAFKA": "Typ: szafka (mapa)",
        "TO JE FUNKCJA": "Typ: funkcja",
        "I TAK TRZEBA POSPRZĄTAĆ": "Ostatnia część bloku HELENA: wykonywana zawsze - także po błędzie, return i break",
        "TO JE NA AMEN": "Stała: TO JE NA AMEN x / TO NIE SĄ TANIE RZECZY 5 - później nie wolno przypisać",
        "CO TO JE": "Wybór wariantu: CO TO JE x / JAK JE 1, 2 / A JAK NIC Z TEGO / KONIEC GADANIA",
        "JAK JE": "Przypadek w CO TO JE - jedna albo kilka wartości po przecinku",
        "A JAK NIC Z TEGO": "Gdy żaden przypadek CO TO JE nie pasuje",
        "KONIEC GADANIA": "Koniec CO TO JE",
        "Z": "Pętla po elementach: KRĘCI CEMENT BETONIARA x Z kolekcja - tablica (elementy), szafka (klucze, posortowane) albo tekst (znaki)",
        "A ROBIĆ NI MA KOMU": "Koniec pętli",
        "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ": "break",
        "AKUKARACZA": "continue",
        "HELENA MUSZĘ CI COŚ POWIEDZIEĆ": "try",
        "HELENA MAM ZAWAŁ": "catch (zmienna z wyjątkiem albo tekstem błędu wykonania, np. \"Dzielenie przez zero\"); blok kończy DO CHAŁUPY ALE JUŻ",
        "O KARWASZ TWARZ": "Rzuć wyjątek",
    }),
    ("Funkcje", {
        "ALE WIE PAN JA ZASADNICZO": "Definicja funkcji",
        "NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ": "Funkcja zwraca wartość",
        "NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO": "Parametry funkcji (a, b albo a, ... dla zmiennej liczby)",
        "DO WIDZENIA PANU": "Koniec funkcji / klasy",
        "I JA INFORMUJĘ ŻE WYCHODZĘ": "return",
        "W MORDĘ JEŻA": "Wywołanie funkcji: W MORDĘ JEŻA f(1, 2)",
        "AFERA JEST": "Wynik funkcji do zmiennej: AFERA JEST x W MORDĘ JEŻA f()",
        "JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ": "Funkcja bez nazwy (lambda): JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) x ROZDUPCĘ BANK 2, albo z instrukcjami: (x) NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ ... DO WIDZENIA PANU. Zmienne lokalne łapie jako kopie z chwili utworzenia (każde wywołanie zaczyna od nich), globalne są wspólne. Stan między wywołaniami: złap szafkę albo tablicę i zmieniaj jej zawartość (stan[\"n\"])",
    }),
    ("Typy złożone", {
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
    }),
    ("Wskaźniki i fixed-point", {
        "PALCEM POKAZUJĘ": "Wskaźnik do wartości albo funkcja jako wartość",
        "CO TAM JEST": "Wartość spod wskaźnika",
        "GDZIE STOI": "Adres zmiennej",
        "KROK DALEJ": "Przesunięcie wskaźnika do przodu",
        "KROK WSTECZ": "Przesunięcie wskaźnika do tyłu",
        "ZAMIEŃ NA FIXED": "Liczba na fixed-point 16.16",
        "WYJMIJ Z FIXED": "Fixed-point 16.16 na liczbę",
    }),
    ("Operatory", {
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
    }),
    ("Stałe", {
        "A ŻEBYŚ PAN WIEDZIAŁ": "true",
        "GÓWNO PRAWDA": "false",
        "W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM": "null",
    }),
    ("KANAPA - tekst", {
        "USIĄDŹ NA KANAPIE(a, b, ...)": "Sklej teksty",
        "ILE MIEJSCA NA KANAPIE(tekst)": "Długość tekstu w znakach (ż to jeden znak)",
        "POTNIJ KANAPĘ(tekst, od, do)": "Fragment tekstu (znaki od..do-1)",
        "ROZCIĄGNIJ KANAPĘ(tekst, długość)": "Dopełnij spacjami do długości",
        "PRZESUŃ NA KANAPIE(tekst, separator)": "Podziel tekst na tablicę",
        "POSKŁADAJ KANAPĘ(tablica, separator)": "Sklej tablicę w tekst",
        "WYTRZEP KANAPĘ(tekst)": "Usuń białe znaki z brzegów",
        "ZAMIEŃ NA KANAPIE(tekst, stary, nowy)": "Zamień wszystkie wystąpienia",
        "ZNAK Z KANAPY(tekst, i)": "Znak na pozycji i",
        "KANAPA DO GÓRY(tekst)": "Wielkie litery (także polskie)",
        "CZY KANAPA PASUJE(tekst, wzór)": "Czy wzór występuje w tekście (wzory: . [a-z] [^a] \\d \\w \\s * + ? ^ $)",
        "ZNAJDŹ NA KANAPIE(tekst, wzór)": "Pierwszy fragment pasujący do wzoru albo null",
        "ZNAJDŹ WSZYSTKO NA KANAPIE(tekst, wzór)": "Wszystkie fragmenty pasujące do wzoru (tablica)",
        "PODMIEŃ NA KANAPIE(tekst, wzór, na)": "Każdy fragment pasujący do wzoru zamieniony na tekst na",
        "KANAPA W DÓŁ(tekst)": "Małe litery (także polskie)",
        "POWTÓRZ NA KANAPIE(tekst, n)": "Tekst powtórzony n razy (\"la\", 3 -> \"lalala\")",
        "CZY SIEDZI NA KANAPIE(tekst, fragment)": "Czy tekst zawiera fragment",
        "GDZIE SIEDZI NA KANAPIE(tekst, fragment)": "Pozycja fragmentu (w znakach) albo -1",
        "ZACZYNA SIĘ OD(tekst, początek)": "Czy tekst zaczyna się od podanego początku",
        "KOŃCZY SIĘ NA(tekst, koniec)": "Czy tekst kończy się podanym końcem",
        "ODWRÓĆ KANAPĘ(tekst)": "Tekst od tyłu (polskie znaki zostają całe)",
        "ROZCIĄGNIJ Z LEWEJ(tekst, długość)": "Dopełnia spacjami z lewej do podanej długości - do wyrównywania liczb",
    }),
    ("WERSALKA - tablice", {
        "ILE NA WERSALCE(tablica)": "Długość tablicy",
        "POŁÓŻ NA WERSALCE(tablica, element)": "Nowa tablica z elementem na końcu",
        "ZDEJMIJ Z WERSALKI(tablica)": "Ostatni element",
        "CZY LEŻY NA WERSALCE(tablica, element)": "Czy tablica zawiera element",
    "POSKŁADAJ WERSALKĘ(tablica)": "Posortowana kopia; z funkcją f(a, b) zwracającą <0, 0, >0 - własna kolejność",
    "ODWRÓĆ WERSALKĘ(tablica)": "Odwrócona kopia",
    "PRZERABIAJ WERSALKĘ(tablica, funkcja)": "Nowa tablica z f(x) dla każdego elementu (map)",
    "PRZEFILTRUJ WERSALKĘ(tablica, funkcja)": "Elementy, dla których f(x) jest prawdą (filter)",
        "TABLICA 2D(wiersze, kolumny)": "Tablica 2D wypełniona zerami",
        "TABLICA 3D(x, y, z)": "Tablica 3D wypełniona zerami",
        "WYTNIJ Z WERSALKI(tablica, od, do)": "Kawałek tablicy: elementy od indeksu od do indeksu do (bez niego)",
        "GDZIE LEŻY NA WERSALCE(tablica, element)": "Indeks pierwszego takiego elementu albo -1",
        "ZESTAW WERSALKI(a, b)": "Nowa tablica: elementy a, potem b",
        "ZSUMUJ WERSALKĘ(tablica)": "Suma elementów (jak kolejne BABKA DAWAJ RENTĘ); pusta tablica to 0",
        "NAJMNIEJSZY NA WERSALCE(tablica)": "Najmniejszy element (liczby albo teksty)",
        "NAJWIĘKSZY NA WERSALCE(tablica)": "Największy element (liczby albo teksty)",
        "ZWIŃ WERSALKĘ(tablica, start, funkcja)": "Zwija tablicę funkcją f(dotąd, element), zaczynając od start",
        "BEZ POWTÓREK(tablica)": "Tablica bez powtórzonych elementów, w kolejności pierwszego wystąpienia",
        "ZRÓB KOLEJKĘ(od, do)": "Tablica liczb od..do włącznie ([] gdy od > do)",
        "WYLOSUJ Z WERSALKI(tablica)": "Losowy element (ten sam generator co KARTA LUBI DYM)",
    }),
    ("SZAFKA - mapy", {
        "OTWÓRZ SZAFKĘ(k1, w1, ...)": "Nowa mapa; bez argumentów pusta, z parami klucz, wartość wypełniona",
        "WŁÓŻ DO SZAFKI(mapa, klucz, wartość)": "Zapisz wartość pod kluczem",
        "WYJMIJ Z SZAFKI(mapa, klucz)": "Wartość spod klucza (null, gdy brak)",
        "WYRZUĆ ZE SZAFKI(mapa, klucz)": "Usuń klucz",
        "CZY W SZAFCE(mapa, klucz)": "Czy klucz istnieje",
        "WSZYSTKIE SZUFLADKI(mapa)": "Posortowana tablica kluczy",
        "ILE W SZAFCE(mapa)": "Liczba kluczy",
        "ZAPAKUJ DO SŁOIKA(wartość)": "JSON: szafki, tablice, liczby, teksty, prawda/fałsz jako tekst JSON (klucze posortowane)",
        "WYJMIJ ZE SŁOIKA(tekst)": "JSON z tekstu: obiekty jako szafki, tablice jako wersalki",
        "WSZYSTKIE RZECZY(mapa)": "Wartości, w kolejności posortowanych kluczy",
        "DOŁÓŻ SZAFKĘ(a, b)": "Nowa mapa: a, nadpisane tym, co jest w b",
    }),
    ("Typy liczbowe i losowanie", {
        "ZRÓB BAJCIK(x)": "Bajt 0-255",
        "ZRÓB KRÓTKI(x)": "Liczba 16-bitowa ze znakiem",
        "ZRÓB DŁUGI(x)": "Liczba całkowita (obcina liczbę z przecinkiem, tekst zamienia na liczbę)",
        "ZRÓB UŁAMEK(x)": "Fixed-point 16.16",
        "CO TO ZA TYP(x)": "Nazwa typu wartości",
        "KARTA LUBI DYM(min, max)": "Losowa liczba z zakresu; KARTA LUBI DYM(ziarno) ustawia ziarno",
    "POLAŁA SIĘ KREW(format, ...)": "Zatrzymaj program z błędem (jak I_Error w DOOM); %s, %d w formacie",
    "PO PIERWSZE PRIMO(liczba, miejsca)": "Liczba jako tekst z podaną liczbą miejsc po przecinku (3.14159, 2 -> \"3.14\")",
    "TRZEBA SPAĆ(ms)": "Uśpij program na podaną liczbę milisekund",
    "CO PAN PRZYNIÓSŁ()": "Argumenty programu (ferdek program.ferdek a b) jako tablica tekstów",
    "CO MÓWI SĄSIAD(nazwa)": "Zmienna środowiska (tekst) albo null, gdy jej nie ma",
    "NASTĘPNA LINIJKA()": "Następna linia wejścia jako tekst albo null na końcu wejścia (do czytania w pętli)",
    "CAŁE WEJŚCIE()": "Reszta wejścia jako jeden tekst (każda linia zakończona nową linią)",
    "ZAMYKAM INTERES(kod)": "Zakończ program od razu z kodem wyjścia 0-255 (bez sprzątania, jak exit)",
    "JEST TRZECIA W NOCY()": "Milisekundy od startu programu (do mierzenia czasu)",
    "PIERWIASTEK ZE SKRZYNKI(x)": "Pierwiastek kwadratowy (wbudowana, bez importu)",
    "SINUS ZE SKRZYNKI(x)": "Sinus kąta w radianach (wbudowana)",
    "COSINUS ZE SKRZYNKI(x)": "Cosinus kąta w radianach (wbudowana)",
    "TANGENS ZE SKRZYNKI(x)": "Tangens kąta w radianach (wbudowana)",
    "POTĘGA ZE SKRZYNKI(a, b)": "a do potęgi b; całkowite do nieujemnej całkowitej daje całkowitą, inaczej liczbę z przecinkiem",
    "LOGARYTM ZE SKRZYNKI(x)": "Logarytm naturalny (x > 0); dziesiętny: LOGARYTM(x) / LOGARYTM(10)",
    "PODŁOGA ZE SKRZYNKI(x)": "Zaokrąglenie w dół do liczby całkowitej",
    "SUFIT ZE SKRZYNKI(x)": "Zaokrąglenie w górę do liczby całkowitej",
    "MODUŁ ZE SKRZYNKI(x)": "Wartość bezwzględna (typ jak argument)",
    }),
    ("KALENDARZ - daty", {
        "JAKI DZIŚ DZIEŃ()": "Dzisiejsza data jako tekst RRRR-MM-DD",
        "KTÓRA GODZINA()": "Aktualna godzina jako tekst GG:MM:SS",
        "DZIEŃ TYGODNIA(data)": "Nazwa dnia tygodnia (\"1999-03-16\" -> \"wtorek\")",
        "DODAJ DNI(data, n)": "Data o n dni późniejsza (n ujemne - wcześniejsza)",
        "ILE DNI MIĘDZY(a, b)": "Liczba dni od daty a do daty b",
    }),
    ("KIBEL - pliki", {
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
    "OPAKUJ W GAZETĘ(tekst)": "Zacytuj tekst jako jeden argument powłoki - używaj przy sklejaniu poleceń dla SYSTEM",
    }),
    ("Pamięć (alokator strefowy w stylu DOOM)", {
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
    }),
    ("TELEWIZOR - framebuffer i tablice", {
        "WŁĄCZ TELEWIZOR(szerokość, wysokość)": "Utwórz framebuffer",
        "WYŁĄCZ TELEWIZOR(ekran)": "Usuń framebuffer",
        "ZMIEŃ KANAŁ(ekran, x, y, kolor)": "Ustaw piksel",
        "CO LECI W TELEWIZORZE(ekran, x, y)": "Odczytaj piksel",
        "STWÓRZ TABELĘ(rozmiar)": "Utwórz tablicę wyszukiwania",
        "WPISZ DO TABELI(tabela, indeks, wartość)": "Zapisz w tablicy wyszukiwania",
        "SPRAWDŹ W TABELI(tabela, indeks)": "Odczytaj z tablicy wyszukiwania",
    }),
    ("SKRZYNKA (import KLAMOTY/SKRZYNKA)", {
        "ILE W SKRZYNCE()": "SKRZYNKA: PI (3.141592653589793)",
        "POLICZ SKRZYNKI(liczba)": "SKRZYNKA: wartość bezwzględna",
        "ZAOKRĄGLIJ DO SKRZYNKI(liczba)": "SKRZYNKA: zaokrąglenie do liczby całkowitej (połówki od zera)",
    "MNIEJSZA ZE SKRZYNEK(a, b)": "SKRZYNKA: mniejsza z dwóch liczb",
    "WIĘKSZA ZE SKRZYNEK(a, b)": "SKRZYNKA: większa z dwóch liczb",
        "OTWÓRZ SKRZYNKĘ(podstawa, wykładnik)": "SKRZYNKA: potęga (wykładnik całkowity, nieujemny)",
        "PODZIEL SKRZYNKI(a, b)": "SKRZYNKA: dzielenie całkowite",
        "RESZTA ZE SKRZYNKI(a, b)": "SKRZYNKA: reszta z dzielenia",
        "LOSUJ ZE SKRZYNKI(min, max)": "SKRZYNKA: losowa liczba",
    }),
    ("KLATKA (import KLAMOTY/KLATKA)", {
        "WYJDŹ NA KLATKĘ(url)": "KLATKA: HTTP GET",
        "ZAPUKAJ DO SĄSIADA(url, dane)": "KLATKA: HTTP POST",
        "KTO NA KLATCE()": "KLATKA: twój publiczny adres IP",
        "CZY SĄSIAD W DOMU(host)": "KLATKA: ping",
    }),
    ("BABKA - testy (import BABKA)", {
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
    }),
]
DOCS = {k: v for _, entries in SECTIONS for k, v in entries.items()}


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


def docs():
    """docs/JEZYK.md: słownik pogrupowany w sekcje, tylko słowa, które zna lekser."""
    known = {d["word"] for d in keyword_docs()}
    lines = [
        "# Ferdek - słownik języka",
        "",
        "> Wygenerowane przez `scripts/gen_keywords.py` z leksera - nie edytuj ręcznie.",
        "",
        "Każde słowo z polskimi znakami można też napisać bez nich (np. `ZROB DLUGI` = `ZRÓB DŁUGI`).",
        "Funkcje z sekcji SKRZYNKA, KLATKA i BABKA wymagają importu modułu, reszta jest wbudowana.",
        "Przykładowe programy: katalog [`examples/`](../examples).",
        "",
        "## Wartości i liczby",
        "",
        "- Liczby całkowite (`5`, `-3`), z przecinkiem (`3.14`), tekst (`\"piwo\"`), prawda/fałsz, null, tablice (`[1, 2]`),",
        "  mapy (SZAFKA), obiekty, funkcje jako wartości, wskaźniki.",
        "- Działanie z liczbą z przecinkiem daje liczbę z przecinkiem; `7 / 2` to `3`, a `7.0 / 2` to `3.5`.",
        "- `+` z tekstem skleja (`\"Piwa: \" + 6`); inne działania na tekście, który nie jest liczbą, to błąd.",
        "- **Zakres liczb całkowitych:** 63 bity (do ok. 4,6 · 10^18) w interpreterze i w skompilowanym programie;",
        "  przy przepełnieniu liczba zawija się tak samo w obu trybach.",
        "- Tekst liczy się w znakach UTF-8 - `ż` to jeden znak.",
        "",
    ]
    for title, entries in SECTIONS:
        rows = [(k, v) for k, v in entries.items() if k.split("(")[0] in known]
        if not rows:
            continue
        lines += [f"## {title}", "", "| Słowo | Znaczenie |", "|---|---|"]
        lines += [f"| `{k}` | {v.replace('|', chr(92) + '|')} |" for k, v in rows]
        lines.append("")
    return "\n".join(lines)


def ocaml_docs():
    """src/tools/keyword_docs.ml - opisy dla ferdek --lsp (podpowiedzi i uzupełnianie)"""
    q = lambda t: '"' + t.replace("\\", "\\\\").replace('"', '\\"') + '"'
    rows = [f"  {q(e['word'])}, {q(e['insert'])}, {q(e['doc'])}, {'true' if e['kind'] == 'function' else 'false'};"
            for e in keyword_docs()]
    return ("(* Wygenerowane przez scripts/gen_keywords.py - nie edytuj ręcznie *)\n\n"
            "(* słowo, tekst do wstawienia (z sygnaturą), opis, czy funkcja wbudowana *)\n"
            "let entries = [\n" + "\n".join(rows) + "\n]\n")


if __name__ == "__main__":
    dump = lambda data: json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    doc_path = ROOT / "docs" / "JEZYK.md"
    ml_path = ROOT / "src" / "tools" / "keyword_docs.ml"
    if sys.argv[1:] == ["--check"]:
        keyword_docs()  # przerwie, jeśli jakieś słowo nie ma opisu
        if not doc_path.exists() or doc_path.read_text(encoding="utf-8") != docs():
            sys.exit("docs/JEZYK.md jest nieaktualny - uruchom: python3 scripts/gen_keywords.py")
        if ml_path.read_text(encoding="utf-8") != ocaml_docs():
            sys.exit("src/tools/keyword_docs.ml jest nieaktualny - uruchom: python3 scripts/gen_keywords.py")
        sys.exit(0)
    doc_path.parent.mkdir(exist_ok=True)
    doc_path.write_text(docs(), encoding="utf-8")
    ml_path.write_text(ocaml_docs(), encoding="utf-8")
    if sys.argv[1:]:
        ext = Path(sys.argv[1])
        (ext / "syntaxes" / "ferdek.tmLanguage.json").write_text(dump(grammar()), encoding="utf-8")
        check_snippets(ext / "snippets" / "ferdek.json")
