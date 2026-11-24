# Changelog

## Unreleased

### Breaking changes
- `HELENA MAM ZAWAŁ` (catch) now ends with `DO CHAŁUPY ALE JUŻ`. Before, the catch block swallowed
  the rest of the enclosing block, so code after a try that did not throw never ran.
- No silent conversions: `+` with text concatenates, other arithmetic on non-numeric text is an
  error (it used to be 0). Only decimal text (`"12"`) counts as a number.
- Importing a module that does not exist is an error (it was a warning).
- Runtime errors (division by zero, index out of range, ...) inside `HELENA MUSZĘ CI COŚ POWIEDZIEĆ`
  are caught by `HELENA MAM ZAWAŁ`, which gets the error message as text. Before, they always
  stopped the program. Break/return outside a loop/function still stop it.
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
- Modules with a namespace: `O KOGO MOJE PIĘKNE OCZY WIDZĄ matma JAKO m`, then `m.dodaj(1, 2)`,
  `m.PI`. The module's top-level names get the `m.` prefix, so they cannot clash with yours;
  the plain import works as before. `JAKO` is now a keyword.
  Multi-word names work after the dot too: `s.OTWÓRZ SKRZYNKĘ(2, 10)`.
- Programs get their arguments (`CO PAN PRZYNIÓSŁ()`, `ferdek program.ferdek a b`), environment
  variables (`CO MÓWI SĄSIAD(nazwa)`) and can exit with a code (`ZAMYKAM INTERES(kod)`).
- Input: `NASTĘPNA LINIJKA()` (a line, or null at the end - for loops) and `CAŁE WEJŚCIE()`.
  `CO TAM U PANA SŁYCHAĆ` gives null at the end of input in both modes, and compiled programs read
  lines of any length.
- Math without import: `POTĘGA`, `TANGENS`, `LOGARYTM`, `PODŁOGA`, `SUFIT`, `MODUŁ ZE SKRZYNKI`.
- Patterns in text: `CZY KANAPA PASUJE`, `ZNAJDŹ NA KANAPIE`, `ZNAJDŹ WSZYSTKO NA KANAPIE`,
  `PODMIEŃ NA KANAPIE` with `.` `[a-z]` `[^...]` `\d` `\w` `\s` `*` `+` `?` `^` `$` on characters
  (Polish letters count as one), the same in both modes and checked against Python `re`.
- Standard library, built in (no import), same in both modes:
  - arrays: `WYTNIJ Z WERSALKI`, `GDZIE LEŻY NA WERSALCE`, `ZESTAW WERSALKI`, `ZSUMUJ WERSALKĘ`,
    `NAJMNIEJSZY/NAJWIĘKSZY NA WERSALCE`, `ZWIŃ WERSALKĘ` (reduce), `BEZ POWTÓREK`, `ZRÓB KOLEJKĘ`,
    `WYLOSUJ Z WERSALKI`;
  - text: `POWTÓRZ NA KANAPIE`, `CZY/GDZIE SIEDZI NA KANAPIE`, `ZACZYNA SIĘ OD`, `KOŃCZY SIĘ NA`,
    `ODWRÓĆ KANAPĘ`, `ROZCIĄGNIJ Z LEWEJ`;
  - maps: `WSZYSTKIE RZECZY`, `DOŁÓŻ SZAFKĘ`;
  - JSON: `ZAPAKUJ DO SŁOIKA(wartość)` / `WYJMIJ ZE SŁOIKA(tekst)` (maps, arrays, numbers, text, true/false,
    null; strict parser, errors with the position);
  - dates (text `RRRR-MM-DD`): `JAKI DZIŚ DZIEŃ`, `KTÓRA GODZINA`, `DZIEŃ TYGODNIA`, `DODAJ DNI`,
    `ILE DNI MIĘDZY`.
- Square brackets on maps: `WYPIERDZIELAJ PAN NA POZYCJĘ s["piwo"]` reads (null when the key is missing, like
  `WYJMIJ Z SZAFKI`) and `O KURDE MAM POMYSŁA s["piwo"] A PROSZĘ BARDZO 6 NO I GITARA` writes; they nest with
  arrays (`dane["kto"]["piwa"][0]`), so parsed JSON can be read directly.
- Text with values put in: `POWIEM PANU TAK "Piwa: {piwa}, jutro {piwa BABKA DAWAJ RENTĘ 2}"`. Any expression
  can stand in `{}` (calls and another `POWIEM PANU TAK` too); `\{` is a plain brace. It is the same as joining
  the pieces with `BABKA DAWAJ RENTĘ`, so both modes print the same. Errors inside `{}` point at the spot,
  and the editor colours, completes and renames names there like anywhere else.
- Negative array indexes count from the end: `t[-1]` is the last element, for reading and writing. Further
  left than the first element is still an error.
- Choosing a variant: `CO TO JE x` / `JAK JE 1, 2` / `A JAK NIC Z TEGO` / `KONIEC GADANIA`.
- Default parameter values: `NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO komu, ile TO NIE SĄ TANIE RZECZY 1`;
  evaluated at the call, they can use earlier parameters.
- `I TAK TRZEBA POSPRZĄTAĆ` (finally) as the last part of a `HELENA MUSZĘ CI COŚ POWIEDZIEĆ` block: runs
  after the try, after the catch, on return/break/continue out of the block and when the catch fails
  (the error then continues outwards).
- Optional types: `TO JE LICZBA SYNEK`, `TO JE LICZBA Z PRZECINKIEM`, `TO SĄ STRINGI`,
  `TO JE TAK ALBO NIE`, `TO JE WERSALKA`, `TO JE SZAFKA`, `TO JE FUNKCJA` after a variable, constant or
  parameter name and after `NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ`. Every later assignment, parameter
  and result is checked while the program runs (same error in both modes); `--check` reports obvious
  mismatches before; the compiler keeps typed numbers as plain C numbers.
- Constants: `TO JE NA AMEN x` / `TO NIE SĄ TANIE RZECZY 5`. Changing one is reported before the
  program runs (both modes, `--check`, the editor); a local variable in a function may reuse the name.
- Loop over elements: `KRĘCI CEMENT BETONIARA x Z kolekcja` ... `A ROBIĆ NI MA KOMU` - array
  elements, map keys (sorted) or characters of a text. `Z` is now a keyword.
- Anonymous functions: `JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) x ROZDUPCĘ BANK 2`, or with statements:
  `JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ` ... `DO WIDZENIA PANU`.
  Local variables (and object fields in methods) are captured as copies when the function is
  created, and every call starts from those copies; globals are shared, like in named functions.
  A captured map or array is the same map or array in every call, so a lambda that has to remember
  something keeps it there (`stan["n"]`); a test and the tutorial now show it.
- Import your own files (relative to the importing file); every module runs once.
- New builtins: random numbers (`KARTA LUBI DYM`), time (`TRZEBA SPAĆ`, `JEST TRZECIA W NOCY`),
  math (`PIERWIASTEK/SINUS/COSINUS ZE SKRZYNKI`, real PI and rounding in SKRZYNKA), lists
  (`POSKŁADAJ/ODWRÓĆ/PRZERABIAJ/PRZEFILTRUJ WERSALKĘ`), text (`ZNAK Z KANAPY`,
  `KANAPA DO GÓRY/W DÓŁ`), shell quoting (`OPAKUJ W GAZETĘ`).

### Compiler to C
- Handles the whole language, including classes, structs, unions, pointers, exceptions, files,
  memory, maps, UDP and X11 graphics. Compiled programs print exactly what the interpreter prints,
  error messages included (checked by tests and a fuzzer).
- Nothing is left for the interpreter only: an object field can be the counter of a `KRĘCI CEMENT BETONIARA`
  loop in a method, and a class, struct or union name can be used as a value - printed, kept in a variable
  or an array, passed to a function and used there with `DZIAD ZDZIADZIAŁY JEDEN` / `ZMONTUJ MEBEL` /
  `WEJDŹ DO UNII`. `--check` and the editor no longer call such a variable an unknown class.
- Compiled programs are optimized (`-O2`, fast paths for integers, string literals without copying):
  8-43x faster than the interpreter on `make bench` (was 2-4x).
- Variables that always hold whole numbers compile to plain C `long long`, and so do the parameters
  and results of functions only ever called with numbers: fib(35) 0.15 s -> 0.03 s, a divisor-sum
  loop 0.44 s -> 0.04 s. Everything else stays as before, so results do not change.
- Numbers with a decimal point get the same treatment (plain C `double` for variables that always
  hold them; a Leibniz-series loop: 0.20 s -> 0.02 s), and so do results of builtins that always
  give numbers (`ILE NA WERSALCE`, `SINUS ZE SKRZYNKI`, ...). Array indexing with a whole-number
  index and comparisons in conditions skip the boxing too (bubble sort: 0.55 s -> 0.43 s).
- Whole numbers have 63 bits and wrap around on overflow the same way in both modes (compiled C
  used 64 bits). Shifts right are logical in both, a shift by less than 0 or more than 62 bits is
  an error, and text with a number outside that range is not a number.
- `ZRÓB DŁUGI` / `ZAMIEŃ NA FIXED` on a number too big for a whole number (or NaN) is an error
  in both modes; before, the result depended on the mode and the processor.
- The call path for error messages costs about 4% on a call-heavy program (frames live on the C
  stack; functions without a try block skip the handler bookkeeping).
- `FERDEK_CC` picks the C compiler for `ferdek -c`/`-r`. The whole test suite and the fuzzer also
  pass with GCC 15, not only clang.
- C compiler warnings about the generated code are no longer shown.
- Compiled programs evaluate operands, function arguments and array elements left to right, like
  the interpreter (C leaves the order open; with gcc a function changing a variable used in the
  same expression could give a different result).
- With the Boehm GC installed, compiled programs free memory (a 2M-iteration text loop: 3 MB instead
  of 32 MB and growing). It is found through `pkg-config bdw-gc` too; `ferdek -c` warns when it is
  missing.
- Numbers turn into text without `snprintf` (a concatenation loop: 0.10 s -> 0.04 s).
- Maps with more than 8 keys (and objects with many fields) use a hash index: 20 000 keys inserted,
  read and half removed in 0.02 s instead of 1.2 s.

### Interpreter
- About 3-5x faster (`make bench`: loops 1.24 s -> 0.24 s, fib 0.40 s -> 0.09 s, objects 0.30 s ->
  0.06 s, text 0.24 s -> 0.07 s): the program is compiled once to OCaml closures, a function's
  variables live in slots, variables and object fields are read through a cached table cell, the
  current line is kept as an int, and numbers turn into text without C printf. Results and error
  messages are unchanged (checked against the previous interpreter on all tests and fuzzed programs).

### Tools
- `ferdek nowy nazwa`: a new project - program, a module, a BABKA test and a README.
- `ferdek --dap`: the debugger for editors (Debug Adapter Protocol) - breakpoints, stepping, call
  stack, variables and hover evaluation in VS Code; program output shows in the debug console.
  Program input for `CO TAM U PANA SŁYCHAĆ` comes from `input` or `inputFile` in the launch
  configuration.
- `ferdek --debug program.ferdek`: step through a program (step, next, step out), breakpoints,
  evaluate expressions, list variables and the call path.
- Tutorial `docs/SAMOUCZEK.md` ("Ferdek w 15 minut"): every program in it is run in both modes by
  `make test` and must print what the tutorial shows.
- Browser playground (`make playground`): the interpreter as JavaScript in a Web Worker, with
  examples, stdlib, program input and a formatter button, syntax highlighting (by the real lexer)
  and share links (the program, compressed, after `#`).
- `ferdek --check` (unknown names, wrong argument counts), `ferdek test` (runs `*_test.ferdek`),
  `ferdek --fmt` (indentation).
- Errors report file and line; syntax errors say what was expected; all messages in Polish.
- The language server warns about local variables that are never read.
- `ferdek --lsp`: Language Server with errors as you type (syntax and `--check`), hover docs for
  keywords, builtins and your names, completion (multi-word keywords too), go to definition
  (also into imported modules, any number of import levels deep), find references and rename -
  across all files of the workspace that import the module. Also argument hints while typing a call,
  document formatting (as `ferdek --fmt`) and semantic colouring by the real lexer (multi-word
  keywords, spellings without Polish letters, builtins, your functions, parameters and variables).
  Needs the `yojson` opam package.
- Lexer and preprocessor messages are in Polish too.
- Errors show the program line they are about. Syntax errors point with `^` at the spot, and when a
  statement is cut short, at the end of that line instead of the start of the next one. Runtime
  errors show the call path (`w funkcji dziel, wywołanej w linii 10`, recursion folded into
  `(12 razy)`), the same in the interpreter and compiled programs.
- Unknown names get a suggestion: `Nieznana zmienna: licnzik. Może chodziło o 'licznik'?`, also for
  misspelled multi-word builtins (`ILE MIEJSCA NA KANAPE` -> `ILE MIEJSCA NA KANAPIE`).
- Several syntax errors are reported at once (up to 10): the broken statement is skipped and
  parsing goes on, stopping early where a block is broken to avoid made-up follow-up errors.
- The REPL keeps state between lines and accepts multi-line statements.
- Full keyword reference in [docs/JEZYK.md](docs/JEZYK.md), generated from the lexer.

### Fixes
- Compiled programs: a function parameter changed inside a try block and read in the catch block
  could come back with its old value (setjmp/longjmp); parameters of functions with try are now
  `volatile`, and the fuzzer generates such cases.
- Security: KLATKA ran URLs/hosts as shell commands; arguments are now quoted.
- String comparison treated any two texts as equal; object methods saw a stale copy of fields;
  the preprocessor defined every platform macro and expanded macros inside strings; about 30
  spellings without Polish letters and `POLAŁA SIĘ KREW` could not be called; stdlib modules
  (SKRZYNKA, WERSALKA) did not parse; `LOSUJ ZE SKRZYNKI` and `CZY SĄSIAD W DOMU` were stubs.
- `make install` / `install.sh` install the stdlib; `install-full.sh` copies the right binary.
