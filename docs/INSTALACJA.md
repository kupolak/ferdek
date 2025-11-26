# Instalacja Ferdek

## Szybka instalacja

1. **Zbuduj projekt:**
   ```bash
   make
   ```

2. **Zainstaluj komendę `ferdek`:**
   ```bash
   ./install.sh
   ```

Komenda `ferdek` zostanie zainstalowana w `/usr/local/bin` (jeśli masz uprawnienia) lub w `~/.local/bin`.

## Użycie

### Wyświetl pomoc
```bash
ferdek
ferdek --help
```

### Interpretuj plik
```bash
ferdek program.ferdek
ferdek -i program.ferdek
```

### Kompiluj do C
```bash
# Kompiluj do pliku .c
ferdek -c program.ferdek

# Kompiluj do wykonywalnego pliku
ferdek -c program.ferdek -o moj_program
```

### Szybkie uruchomienie (compile & run)
```bash
ferdek --run program.ferdek
ferdek -r program.ferdek
```

### Tryb interaktywny (REPL)
```bash
ferdek --repl
```

## Przykłady

```bash
# Hello World
ferdek examples/hello.ferdek

# Program ze zmiennymi
ferdek examples/variables.ferdek

# Warunki
ferdek examples/conditional.ferdek

# Zaawansowane funkcje
ferdek examples/advanced_features.ferdek
```

## Deinstalacja

```bash
./uninstall.sh
```

## Dostępne komendy

- `ferdek` - Główna komenda (interpreter + kompilator)
- `.build/ferdek` - Tylko interpreter (stary interfejs)
- `.build/ferdecc` - Tylko kompilator (stary interfejs)

## Opcje

```
  -h, --help              Wyświetla pomoc
  -v, --version           Wyświetla wersję języka Ferdek
  -i, --interpret <plik>  Interpretuje plik .ferdek (domyślnie)
  -c, --compile <plik>    Kompiluje plik .ferdek do C
  -o <wyjście>            Określa nazwę pliku wyjściowego
  -r, --run               Kompiluje i uruchamia (tryb quick run)
  --repl                  Uruchamia interaktywny REPL
```

## Wymagania

- OCaml 4.08+
- ocamllex
- Menhir
- gcc (dla kompilacji do C)

## Budowanie ze źródeł

```bash
# Zbuduj wszystko
make

# Zbuduj tylko interpreter
make .build/ferdek

# Zbuduj tylko kompilator
make .build/ferdecc

# Uruchom testy
make test

# Wyczyść pliki pośrednie
make clean
```
