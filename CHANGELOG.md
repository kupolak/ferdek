# Changelog

## 2.0.0 (unreleased)

### Breaking changes
- `HELENA MAM ZAWAŁ` (catch) now ends with `DO CHAŁUPY ALE JUŻ`. Before, the catch block swallowed
  the rest of the enclosing block, so code after a try that did not throw never ran.
- No silent conversions: `+` with text concatenates, other arithmetic on non-numeric text is an
  error (it used to be 0). Only decimal text (`"12"`) counts as a number.
- Importing a module that does not exist is an error (it was a warning).
- `OD`, `DO`, `CO` are keywords (for loops) and cannot be variable names.
- Maps print, and `WSZYSTKIE SZUFLADKI` returns, keys in sorted order.
- KANAPA counts characters, not bytes (`"żółw"` has length 4).
- `ferdecc` is gone - use `ferdek -c`. `ferdek -c x -o app` builds an executable, `-o x.c` writes C.

### Language
- Print without a newline (`JEDZIEM Z TYM ŚLEDZIEM`, `NO TO ENTER`), logical not
  (`TAK BYĆ NIE BĘDZIE`), `>=` (`JA JESTEM PONAD TO`), else if (`AAA TO ZMIENIA POSTAĆ RZECZY`),
  for loops (`KRĘCI CEMENT BETONIARA i OD 1 DO 10 CO 2`).
- Numbers with a decimal point, array literals anywhere, names starting with Polish letters.
- `PO PIERWSZE PRIMO(x, miejsca)` formats a number with a fixed number of decimal places.
- Map literals: `OTWÓRZ SZAFKĘ("a", 1, "b", 2)` creates a map filled with key/value pairs.
- Anonymous functions: `JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) x ROZDUPCĘ BANK 2`. Local variables
  (and object fields in methods) are captured by value when the function is created; globals stay live.
- Import your own files (relative to the importing file); every module runs once.
- New builtins: random numbers (`KARTA LUBI DYM`), time (`TRZEBA SPAĆ`, `JEST TRZECIA W NOCY`),
  math (`PIERWIASTEK/SINUS/COSINUS ZE SKRZYNKI`, real PI and rounding in SKRZYNKA), lists
  (`POSKŁADAJ/ODWRÓĆ/PRZERABIAJ/PRZEFILTRUJ WERSALKĘ`), text (`ZNAK Z KANAPY`,
  `KANAPA DO GÓRY/W DÓŁ`), shell quoting (`OPAKUJ W GAZETĘ`).

### Compiler to C
- Handles the whole language, including classes, structs, unions, pointers, exceptions, files,
  memory, maps, UDP and X11 graphics. Compiled programs print exactly what the interpreter prints,
  error messages included (checked by tests and a fuzzer).
- Compiled programs are optimized (`-O2`, fast paths for integers, string literals without copying):
  7-23x faster than the interpreter on `make bench` (was 2-4x).
- With the Boehm GC installed, compiled programs free memory (a 2M-iteration text loop: 3 MB instead
  of 32 MB and growing).

### Tools
- `ferdek --check` (unknown names, wrong argument counts), `ferdek test` (runs `*_test.ferdek`),
  `ferdek --fmt` (indentation).
- Errors report file and line; syntax errors say what was expected; all messages in Polish.
- `ferdek --lsp`: Language Server with go to definition, find references and rename (one file;
  scopes: global, class, function, lambda). Needs the `yojson` opam package to build.
- Several syntax errors are reported at once (up to 10): the broken statement is skipped and
  parsing goes on, stopping early where a block is broken to avoid made-up follow-up errors.
- The REPL keeps state between lines and accepts multi-line statements.
- Full keyword reference in [docs/JEZYK.md](docs/JEZYK.md), generated from the lexer.

### Fixes
- Security: KLATKA ran URLs/hosts as shell commands; arguments are now quoted.
- String comparison treated any two texts as equal; object methods saw a stale copy of fields;
  the preprocessor defined every platform macro and expanded macros inside strings; about 30
  spellings without Polish letters and `POLAŁA SIĘ KREW` could not be called; stdlib modules
  (SKRZYNKA, WERSALKA) did not parse; `LOSUJ ZE SKRZYNKI` and `CZY SĄSIAD W DOMU` were stubs.
- `make install` / `install.sh` install the stdlib; `install-full.sh` copies the right binary.
