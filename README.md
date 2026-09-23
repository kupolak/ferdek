<img src="ferdek.png" width="300" alt="Ferdek programming language">

A humorous programming language based on the Polish sitcom "Świat według Kiepskich", implemented in OCaml.

## VS Code Extension

There's a [VS Code extension](https://github.com/kupolak/ferdek-vscode) with syntax highlighting, auto-completion, and snippets. Get it from the [marketplace](https://marketplace.visualstudio.com/items?itemName=JakubPolak.vscode-ferdek).

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
- `KARTA LUBI DYM(1, 6)` - random number (`KARTA LUBI DYM(seed)` sets the seed)
- `O KOGO MOJE PIĘKNE OCZY WIDZĄ moj_plik` - import `moj_plik.ferdek` next to your file (or a stdlib module)
- `3.14` - numbers with a decimal point (`7 / 2` is still `3`, `7.0 / 2` is `3.5`; `ZRÓB DŁUGI(3.9)` truncates)
- `[1, 2, 3]` - array literals work anywhere, e.g. as function arguments
- `"Piwa: " BABKA DAWAJ RENTĘ 6` - `+` with text concatenates; arithmetic on non-numeric text is an error
- `JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) x ROZDUPCĘ BANK 2` - anonymous function (local variables captured by value)
- `OTWÓRZ SZAFKĘ("piwo", 3, "wódka", 1)` - map with initial key/value pairs; `PO PIERWSZE PRIMO(3.14159, 2)` - `"3.14"`
- `ZNAK Z KANAPY(s, i)`, `KANAPA DO GÓRY(s)`, `KANAPA W DÓŁ(s)` - character at position, upper/lower case (Polish letters too)

Run your tests - every `*_test.ferdek` file under a directory (use BABKA for assertions):

```bash
ferdek test            # current directory
ferdek test tests/     # or a given one
```

Tidy up indentation (4 spaces per block; comments and strings untouched):

```bash
ferdek --fmt program.ferdek > program_ladny.ferdek
```

Check a program without running it (unknown names, wrong argument counts):

```bash
ferdek --check program.ferdek
```

Editors: `ferdek --lsp` is a Language Server (stdin/stdout) with go to definition, find references
and rename, within one file. Point any LSP client at it, e.g. in Neovim:

```lua
vim.lsp.start({ name = "ferdek", cmd = { "ferdek", "--lsp" } })
```

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
error messages - `make test` and a fuzzer check this. The only things it still rejects are a
class name used as a value and an object field used as a loop counter.

Compiled programs are optimized (`-O2`, 7-23x faster than the interpreter on `make bench`). If the
Boehm garbage collector is installed (`brew install bdw-gc`, `apt install libgc-dev`), `ferdek -c`
uses it automatically, so long-running programs keep a small memory footprint; without it memory
is never freed, which is fine for short programs.

## Example Program

```ferdek
CO JEST KURDE

RYM CYM CYM Declare a variable
CYCU PRZYNIEŚ NO piwa
TO NIE SĄ TANIE RZECZY 6

RYM CYM CYM Add 2 more
O KURDE MAM POMYSŁA piwa
A PROSZĘ BARDZO piwa
BABKA DAWAJ RENTĘ 2
NO I GITARA

PANIE SENSACJA REWELACJA piwa

MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

## Contributing

It's a joke project but PRs are welcome if you want to add more features or fix bugs.

## License

MIT

---

All quotes and character names from "Świat według Kiepskich" are property of their respective copyright holders. This project is for educational and entertainment purposes only.
