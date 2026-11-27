# KLAMOTY - biblioteka standardowa Ferdka

Większość biblioteki jest wbudowana i działa bez importu: tekst (KANAPA), tablice (WERSALKA),
mapy i JSON (SZAFKA), pliki (KIBEL), daty, matematyka, wzorce, pamięć, framebuffer.
Pełna lista słów z opisami: [docs/JEZYK.md](../docs/JEZYK.md) (generowana, `make test` pilnuje aktualności).

## Moduły do zaimportowania

| Moduł | Import | Co daje |
|---|---|---|
| SKRZYNKA | `O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/SKRZYNKA` | matematyka: `DODAJ`, `MNOZ`, potęga, min/max, PI... |
| KLATKA | `O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/KLATKA` | HTTP GET/POST przez curl, ping, publiczny IP |
| TELEWIZOR | `O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/TELEWIZOR` | `PRZEŁĄCZ_KANAŁ(wiadomość)` - wypisywanie jako funkcja |
| PIWNICA | `O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/PIWNICA` | pliki WAD (DOOM): katalog, wpisy jako bajty, paleta, obrazki; przykład: `playground/przyklady/piwnica.ferdek` |
| BABKA | `O KOGO MOJE PIĘKNE OCZY WIDZĄ BABKA` | asercje do testów (`ferdek test`), opis w [KLAMOTY/BABKA/README.md](KLAMOTY/BABKA/README.md) |

Z `JAKO` nazwy modułu dostają przedrostek:

```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/SKRZYNKA JAKO s
PANIE SENSACJA REWELACJA W MORDĘ JEŻA s.DODAJ(5, 3)
```

## Nowy moduł

1. Plik `stdlib/KLAMOTY/NAZWA.ferdek` (albo `KLAMOTY/NAZWA/NAZWA.ferdek`) z funkcjami w Ferdku.
2. Test w `tests/integration/stdlib/` i oczekiwane wyjście (`make update-expected`).

Wbudowane funkcje żyją w `src/interpreter/builtins/` i `src/compiler/runtime/` - muszą dawać to samo
w obu trybach (`make test`, `make test-fuzz`).
