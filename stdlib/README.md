# KLAMOTY - Standardowa Biblioteka Ferdeka

**KLAMOTY** to standardowa biblioteka języka Ferdek - zestaw modułów i funkcji, które ułatwiają programowanie.

## Status Implementacji

### ✅ ZAIMPLEMENTOWANE

#### Moduł SKRZYNKA (matematyka)
Operacje matematyczne dostępne przez import `KLAMOTY/SKRZYNKA`:
- `DODAJ(a, b)` - dodawanie
- `MNOZ(a, b)` - mnożenie

Przykład:
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/SKRZYNKA

AFERA JEST suma W MORDĘ JEŻA DODAJ(5, 3)
PANIE SENSACJA REWELACJA suma  RYM CYM CYM 8
```

#### Funkcje Stringowe (wbudowane)
Dostępne globalnie bez importu:
- `KONKATENUJ(str1, str2, ...)` - łączenie stringów
- `DLUGOSC(str)` - długość stringa
- `SUBSTRING(str, start, len)` - podciąg
- `UPPERCASE(str)` - wielkie litery
- `LOWERCASE(str)` - małe litery
- `TRIM(str)` - usuwanie białych znaków
- `REPLACE(str, old, new)` - zamiana tekstu

Przykład:
```ferdek
AFERA JEST tekst W MORDĘ JEŻA KONKATENUJ("Ferdek ", "ma ", "piwo")
AFERA JEST wielkie W MORDĘ JEŻA UPPERCASE(tekst)
PANIE SENSACJA REWELACJA wielkie  RYM CYM CYM "FERDEK MA PIWO"
```

### 📝 PLANOWANE (TODO)

Moduły, które są opisane w dokumentacji ale jeszcze nie zaimplementowane:
- LODÓWKA - zmienne, stałe
- TELEWIZOR - dodatkowe operacje I/O
- KIBEL - operacje na plikach
- WERSALKA - listy i kolekcje
- SZAFKA - słowniki/mapy
- KLATKA - networking

## Jak używać

### Import modułu

```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/SKRZYNKA
```

### Uruchomienie przykładów

```bash
# Test modułu matematycznego
.build/ferdek examples/test_stdlib.ferdek

# Test funkcji stringowych
.build/ferdek examples/test_strings.ferdek

# Pełny test stdlib
.build/ferdek examples/test_stdlib_full.ferdek
```

## Architektura

- `stdlib/KLAMOTY/` - katalog z modułami stdlib
- Każdy moduł to plik `.ferdek` z funkcjami
- Moduły są ładowane dynamicznie przez interpreter
- Niektóre funkcje (jak stringowe) są wbudowane w interpreter dla wydajności

## Rozwój

Aby dodać nowy moduł:
1. Utwórz plik `stdlib/KLAMOTY/NAZWA.ferdek`
2. Zdefiniuj funkcje w języku Ferdek
3. Dokumentuj w `docs/KLAMOTY.md`
4. Dodaj testy w `examples/`

Aby dodać wbudowane funkcje (jak stringowe):
1. Zmodyfikuj `src/interpreter.ml` - funkcja `eval_function_call`
2. Dodaj obsługę nowej funkcji w pattern matching
3. Przebuduj projekt: `make clean && make`
