# 🍰 BABKA - Framework testowy dla Ferdek

Framework testowy w stylu Ruby minitest, z nazwami funkcji w stylu Kiepskich.

## Instalacja

Zaimportuj bibliotekę BABKA na początku pliku testowego:

```ferdek
CYCU PRZYNIEŚ BABKA
```

## Asercje (Assert)

| Funkcja | Odpowiednik Ruby | Opis |
|---------|------------------|------|
| `TAK JEST I KROPKA(warunek)` | `assert` | Sprawdza czy warunek jest prawdziwy |
| `MA BYĆ RÓWNE(oczekiwane, rzeczywiste)` | `assert_equal` | Sprawdza równość dwóch wartości |
| `ZERO(wartość)` | `assert_nil` | Sprawdza czy wartość jest null |
| `TEN SAM BAJZEL(a, b)` | `assert_same` | Sprawdza identyczność wartości |
| `JA TU RZĄDZĘ(wynik)` | `assert_operator` | Sprawdza wynik operacji |

## Refutacje (Refute)

| Funkcja | Odpowiednik Ruby | Opis |
|---------|------------------|------|
| `GUZIK PRAWDA(warunek)` | `refute` | Sprawdza czy warunek jest fałszywy |
| `MOJE LEPSZE(nieoczekiwane, rzeczywiste)` | `refute_equal` | Sprawdza nierówność wartości |
| `PIENIĄDZE SĄ(wartość)` | `refute_nil` | Sprawdza czy wartość NIE jest null |
| `DZIŚ GORSZY BAJZEL(a, b)` | `refute_same` | Sprawdza że wartości NIE są identyczne |
| `NIKT LEPIEJ ODE MNIE(wynik)` | `refute_operator` | Sprawdza że operacja jest fałszywa |

## Funkcje pomocnicze

| Funkcja | Odpowiednik Ruby | Opis |
|---------|------------------|------|
| `WSZYSCY OBLANI(wiadomość)` | `flunk` | Wymusza niepowodzenie testu |
| `OLEWAM TO(wiadomość)` | `skip` | Pomija test |
| `WYGRAŁAM()` | `pass` | Wymusza zaliczenie testu |

## Raport

Na końcu testów wywołaj `BABKA PODSUMUJ()` aby zobaczyć raport:

```ferdek
BABKA PODSUMUJ()
```

## Przykład użycia

```ferdek
CO JEST KURDE

CYCU PRZYNIEŚ BABKA

RYM CYM CYM Testujemy dodawanie
CYCU PRZYNIEŚ NO wynik
TO NIE SĄ TANIE RZECZY 2 BABKA DAWAJ RENTĘ 2

MA BYĆ RÓWNE(4, wynik)

RYM CYM CYM Testujemy warunek
TAK JEST I KROPKA(wynik FAJNIEJSZE NIŻ 3)

RYM CYM CYM Testujemy nierówność
GUZIK PRAWDA(wynik TO PANU SIĘ CHCE WTEDY KIEDY MNIE 5)

RYM CYM CYM Raport końcowy
BABKA PODSUMUJ()

MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

## Wynik testów

```
✓ BABKA: Test zaliczony!
✗ BABKA MA BYĆ RÓWNE: Wartości różne!
  Oczekiwano: 5
  Otrzymano: 4
○ BABKA OLEWAM TO: Jeszcze nie zaimplementowane

========================================
        BABKA - RAPORT TESTÓW
========================================
Testy zaliczone (✓): 2
Testy niezaliczone (✗): 1
Testy pominięte (○): 1
========================================
WYNIK: BABKA NIEZADOWOLONA! 😤
========================================
```

## Filozofia

> "W testowaniu jak w życiu - albo się ma rację, albo jest się fałszywym!"
> -- Halinka

---

**BABKA** - Bo testowanie to nie tylko praca, to pasja!
