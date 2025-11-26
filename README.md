# Ferdek Programming Language

A humorous programming language based on the Polish sitcom, implemented with OCaml.

## Language Features

Ferdek is an esoteric programming language that uses colorful Polish expressions as keywords. For example:

### Basic Features
- `CO JEST KURDE` - Program start
- `PANIE SENSACJA REWELACJA` - Print statement
- `PASZOŁ WON` - Subtraction operator
- `CHLUŚNIEM BO UŚNIEM` - While loop

### Advanced Features
- `O KOGO MOJE PIĘKNE OCZY WIDZĄ` - Import module
- `PANIE TO JEST PRYWATNA PUBLICZNA TABLICA` - Array declaration
- `HELENA MAM ZAWAŁ` - Catch exception
- `ALE JAJA` - Class declaration
- `A POCAŁUJCIE MNIE WSZYSCY W DUPĘ` - Break statement
- `W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM` - Null value

## Quick Start

### Prerequisites

- OCaml (4.08+)
- OCamllex
- Menhir

### Installation

macOS:
```bash
brew install ocaml opam
opam init
opam install menhir
```

Linux (Ubuntu/Debian):
```bash
sudo apt-get install ocaml opam
opam init
opam install menhir
```

### Build & Install

```bash
# Build the project
make

# Install the 'ferdek' command (globally or locally in ~/.local/bin)
./install.sh
```

More information: [docs/INSTALACJA.md](docs/INSTALACJA.md)

### Run Tests

```bash
make test
```

### Run Ferdek Programs

**Main command** - Display help:
```bash
ferdek
ferdek --help
```

**Interpreter** - Run a Ferdek file:
```bash
ferdek examples/hello.ferdek
ferdek examples/variables.ferdek
ferdek -i examples/conditional.ferdek
```

**Interpreter** - Interactive mode (REPL):
```bash
ferdek --repl
```

**Compiler** - Quick run (compile and execute):
```bash
ferdek --run examples/hello.ferdek
ferdek -r examples/variables.ferdek
```

**Compiler** - Compile to executable:
```bash
ferdek -c examples/hello.ferdek -o my_program
./my_program
```

**Compiler** - Compile to C only:
```bash
ferdek -c examples/hello.ferdek
# Creates examples/hello.c
```

### Legacy interfaces (in .build folder)

If you prefer using the old separate commands:
```bash
# Interpreter only (REPL or file)
.build/ferdek examples/hello.ferdek

# Compiler only
.build/ferdecc -r examples/hello.ferdek
```

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

## Current Status

✅ Lexer - Complete
✅ AST - Complete
✅ Parser - Complete
✅ Interpreter - Complete
✅ Compiler - Complete (Ferdek → C)

## Contributing

This is an educational/humorous project. Feel free to experiment and extend it!

## License

Open source - use freely for educational purposes.
