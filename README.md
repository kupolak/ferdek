<img src="ferdek.png" width="300" alt="Ferdek programming language">

A humorous programming language based on the Polish sitcom "Świat według Kiepskich", implemented in OCaml.

## VS Code Extension

There's a [VS Code extension](https://github.com/kupolak/ferdek-vscode) with syntax highlighting, auto-completion, and snippets. Get it from the [marketplace](https://marketplace.visualstudio.com/items?itemName=JakubPolak.vscode-ferdek).

New to Ferdek? Start with the tutorial: [Ferdek w 15 minut](docs/SAMOUCZEK.md) (Polish).

## What's This?

Ferdek uses quotes from the TV show as keywords. Instead of boring `while` you write `CHLUŚNIEM BO UŚNIEM`, and instead of `print` you get `PANIE SENSACJA REWELACJA`.

Full list of keywords and builtins: [docs/JEZYK.md](docs/JEZYK.md).

Some examples:
- `CO JEST KURDE` - start program
- `PANIE SENSACJA REWELACJA` - print
- `PASZOŁ WON` - subtraction
- `CHLUŚNIEM BO UŚNIEM` - while loop
- `HELENA MAM ZAWAŁ` - catch exception
- `A POCAŁUJCIE MNIE WSZYSCY W DUPĘ` - break
- `W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM` - null
- `JEDZIEM Z TYM ŚLEDZIEM` - print without a newline (`NO TO ENTER` ends the line)
- `TAK BYĆ NIE BĘDZIE` - logical not; `JA JESTEM PONAD TO` - `>=`
- `AAA TO ZMIENIA POSTAĆ RZECZY` - else if
- `KRĘCI CEMENT BETONIARA i OD 1 DO 10 CO 2` ... `A ROBIĆ NI MA KOMU` - for loop
- `KRĘCI CEMENT BETONIARA piwo Z lodowka` ... `A ROBIĆ NI MA KOMU` - loop over array elements, map keys or characters
- `KARTA LUBI DYM(1, 6)` - random number (`KARTA LUBI DYM(seed)` sets the seed)
- `O KOGO MOJE PIĘKNE OCZY WIDZĄ moj_plik` - import `moj_plik.ferdek` next to your file (or a stdlib module);
  `... WIDZĄ matma JAKO m` keeps the module's names apart: `m.dodaj(1, 2)`, `m.PI`
- `3.14` - numbers with a decimal point (`7 / 2` is still `3`, `7.0 / 2` is `3.5`; `ZRÓB DŁUGI(3.9)` truncates)
- `[1, 2, 3]` - array literals work anywhere, e.g. as function arguments
- `"Piwa: " BABKA DAWAJ RENTĘ 6` - `+` with text concatenates; arithmetic on non-numeric text is an error
- `NO JAK NIE JAK TAK piwa GRUBA ŚWINIA 0 A PROSZĘ BARDZO "jest" A DUPA TAM "nie ma"` - one value or the other
  (an if as an expression; only the chosen side is evaluated)
- `CO TO JE dzien JAK JE "sobota", "niedziela" A PROSZĘ BARDZO "schabowy" A JAK NIC Z TEGO "zupa" KONIEC GADANIA` - a choice
  as a value (the cases can go on separate lines; without `A JAK NIC Z TEGO` the value is null when nothing fits)
- `DOLEJ 2 DO piwa` / `ULEJ 1 Z piwa` - add to / take from a variable, an array element, a map key or a field
- `POWIEM PANU TAK "Piwa: {piwa}, jutro {piwa BABKA DAWAJ RENTĘ 2}"` - text with values put in (any expression in `{}`)
- `JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) x ROZDUPCĘ BANK 2` - anonymous function (local variables captured as copies;
  to keep state between calls capture a map or an array and change what is inside: `stan["n"]`);
  with statements: `JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ` ... `DO WIDZENIA PANU`
- `WYPIERDZIELAJ PAN NA POZYCJĘ t[-1]` - last array element; `s["piwo"]` reads a map (null when the key is missing),
  `O KURDE MAM POMYSŁA s["piwo"] A PROSZĘ BARDZO 6 NO I GITARA` writes it; they nest: `dane["kto"]["piwa"][0]`;
  `tekst[0]` is a character; a call result can be indexed too: `WYPIERDZIELAJ PAN NA POZYCJĘ W MORDĘ JEŻA f()[0]`
- `DZIAD ZDZIADZIAŁY JEDEN Kot("Mruczek", 3)` - the arguments go to the class's `NA DZIEŃ DOBRY` method (its constructor)
- `kot.imie`, `W MORDĘ JEŻA kot.miaucz(2)`, `O KURDE MAM POMYSŁA kot.imie A PROSZĘ BARDZO "Filemon" NO I GITARA` - fields and
  methods of an object with a dot (the same as `kot["imie"]`; works on maps too: `dane.kto.imie`)
- `OTWÓRZ SZAFKĘ("piwo", 3, "wódka", 1)` - map with initial key/value pairs; `PO PIERWSZE PRIMO(3.14159, 2)` - `"3.14"`
- Library for arrays (`ZSUMUJ WERSALKĘ`, `WYTNIJ Z WERSALKI`, `ZWIŃ WERSALKĘ`...), text (`CZY SIEDZI NA KANAPIE`,
  `ODWRÓĆ KANAPĘ`...), maps, dates (`JAKI DZIŚ DZIEŃ`, `DODAJ DNI`, `DZIEŃ TYGODNIA`) and JSON (`ZAPAKUJ DO SŁOIKA`, `WYJMIJ ZE SŁOIKA`) - see `docs/JEZYK.md`
- `ZNAK Z KANAPY(s, i)`, `KANAPA DO GÓRY(s)`, `KANAPA W DÓŁ(s)` - character at position, upper/lower case (Polish letters too)

Start a project: `ferdek nowy moj_projekt` (program, module, test and README).

Run your tests - every `*_test.ferdek` file under a directory (use BABKA for assertions):

```bash
ferdek test            # current directory
ferdek test tests/     # or a given one
```

Tidy up indentation (4 spaces per block; comments and strings untouched):

```bash
ferdek --fmt program.ferdek > program_ladny.ferdek
```

Pick the C compiler with `FERDEK_CC` (default `cc`), e.g. `FERDEK_CC=gcc-15 ferdek -c program.ferdek -o app`.

Check a program without running it (unknown names, wrong argument counts):

```bash
ferdek --check program.ferdek
```

Debug step by step: `ferdek --debug program.ferdek` - `k` step, `n` next line, `w` step out, `b 12` breakpoint,
`c` continue, `p expr` show a value, `z` variables, `g` call path (`h` lists everything).

`ferdek --dap` is the same debugger for editors (Debug Adapter Protocol) - the VS Code extension uses it
for breakpoints and stepping (F5 on a `.ferdek` file).

Editors: `ferdek --lsp` is a Language Server (stdin/stdout): errors as you type, hover docs,
completion, argument hints, formatting, colouring by the real lexer (semantic tokens), go to definition
(also into imported modules), find references and rename (across the files that import a module). Point any LSP client at it, e.g. in Neovim:

```lua
vim.lsp.start({ name = "ferdek", cmd = { "ferdek", "--lsp" } })
```

## Playground

Ferdek in the browser: the interpreter compiled to JavaScript (js_of_ocaml), running in a Web Worker,
with examples and the stdlib built in. Build it with `make playground` (needs
`opam install js_of_ocaml js_of_ocaml-compiler`) and serve `_build/playground/` with any static
file server. Everything works except networking and files. Graphics programs (`OKNO_OTWORZ`,
`PIKSEL_MALUJ`, `EKRAN_ODSWIEZ`...) draw on a canvas on the page - without keyboard and mouse events,
see the `telewizor.ferdek` example. `make test-playground` checks it with node.

## Installation

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/kupolak/ferdek/main/scripts/install-full.sh | bash
```

### Build from source

You'll need:

- OCaml (4.08+) and opam
- Menhir

Then:

```bash
# macOS
brew install ocaml opam
opam init && opam install menhir menhirLib yojson

# Linux
sudo apt-get install ocaml opam
opam init && opam install menhir menhirLib yojson

# Build
git clone https://github.com/kupolak/ferdek.git
cd ferdek
make
./scripts/install.sh
```

Run tests with `make test` (fails if any test fails).

You can create a local wrapper/symlink with:

```bash
make link   # creates `.build/ferdek` pointing at the built binary
./.build/ferdek examples/hello.ferdek
```

To make `ferdek` available system-wide (or for your user), run the installer which will copy the `ferdek` binary to `$HOME/.local/bin` or `/usr/local/bin`:

```bash
./scripts/install.sh
# then ensure that ~/.local/bin is in your PATH (or run as root to install to /usr/local/bin)
```

If you prefer, you can also install via the quick installer:

```bash
curl -fsSL https://raw.githubusercontent.com/kupolak/ferdek/main/scripts/install-full.sh | bash
```


## Usage

Run a file:

```bash
ferdek examples/hello.ferdek
```

REPL:
```bash
ferdek --repl
```

Compile to executable:
```bash
ferdek -c examples/hello.ferdek -o my_program
./my_program
```

Compile and run:
```bash
ferdek -r examples/hello.ferdek
```

Generate C source only (any `-o` ending in `.c`):
```bash
ferdek -c examples/hello.ferdek -o hello.c
```

The compiler (needs `cc` on your PATH) handles the whole language: classes, structs, unions,
pointers, files, memory, maps, UDP networking and X11 graphics included (graphics programs are
linked with `-lX11`). Compiled programs print exactly what the interpreter prints, including
error messages - `make test` and a fuzzer check this.

Compiled programs are optimized (`-O2`, 7-23x faster than the interpreter on `make bench`). If the
Boehm garbage collector is installed (`brew install bdw-gc`, `apt install libgc-dev`), `ferdek -c`
uses it automatically, so long-running programs keep a small memory footprint; without it memory
is never freed, which is fine for short programs.

## Example Program

```ferdek
CO JEST KURDE

ALE JAJA Lodowka
    CYCU PRZYNIEŚ NO piwa
    TO NIE SĄ TANIE RZECZY 0

    RYM CYM CYM Constructor: gets the arguments of DZIAD ZDZIADZIAŁY JEDEN Lodowka(...)
    ALE WIE PAN JA ZASADNICZO NA DZIEŃ DOBRY
    NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO ile
        O KURDE MAM POMYSŁA piwa A PROSZĘ BARDZO ile NO I GITARA
    DO WIDZENIA PANU

    ALE WIE PAN JA ZASADNICZO wypij
        ULEJ 1 Z piwa
    DO WIDZENIA PANU
DO WIDZENIA PANU

CYCU PRZYNIEŚ NO lodowka
TO NIE SĄ TANIE RZECZY DZIAD ZDZIADZIAŁY JEDEN Lodowka(3)

CHLUŚNIEM BO UŚNIEM lodowka.piwa GRUBA ŚWINIA 0
    W MORDĘ JEŻA lodowka.wypij()
    PANIE SENSACJA REWELACJA POWIEM PANU TAK "Chlup! Zostało {lodowka.piwa}"
A ROBIĆ NI MA KOMU

PANIE SENSACJA REWELACJA NO JAK NIE JAK TAK lodowka.piwa GRUBA ŚWINIA 0 A PROSZĘ BARDZO "Jeszcze jest" A DUPA TAM "Helena, piwo się skończyło!"

MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

A longer one, with maps, loops, lambdas and exceptions: [examples/lodowka.ferdek](examples/lodowka.ferdek).

## Contributing

It's a joke project but PRs are welcome if you want to add more features or fix bugs.

## License

MIT

---

All quotes and character names from "Świat według Kiepskich" are property of their respective copyright holders. This project is for educational and entertainment purposes only.
