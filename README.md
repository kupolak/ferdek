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

See [docs/ferdek.ebnf](docs/ferdek.ebnf) for the complete grammar specification and [docs/NEW_FEATURES.md](docs/NEW_FEATURES.md) for detailed documentation of advanced features.

## Project Structure

```
ferdek/
├── src/
│   ├── lexer.mll        # Lexer implementation (OCamllex)
│   ├── parser.mly       # Parser token definitions (Menhir)
│   ├── ast.ml           # Abstract Syntax Tree definition
│   └── ast.mli          # AST interface
├── tests/
│   ├── test_lexer.ml    # Lexer test program
│   └── test_ast.ml      # AST test program
├── docs/
│   ├── ferdek.ebnf      # Grammar specification in EBNF
│   ├── INSTRUKCJA.md    # Detailed usage guide
│   ├── README_LEXER.md  # Lexer documentation
│   ├── README_AST.md    # AST documentation
│   └── NEW_FEATURES.md  # Advanced features documentation
├── examples/            # Example programs
│   ├── hello.ferdek
│   ├── variables.ferdek
│   ├── conditional.ferdek
│   └── advanced_features.ferdek
├── Makefile             # Build automation
└── README.md            # This file
```

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

### Build

```bash
make
```

### Run Tests

```bash
make test
```

### Test with Example Files

```bash
./test_lexer examples/hello.ferdek
./test_lexer examples/variables.ferdek
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

## Documentation

- [docs/INSTRUKCJA.md](docs/INSTRUKCJA.md) - Complete usage guide
- [docs/README_LEXER.md](docs/README_LEXER.md) - Lexer implementation details
- [docs/README_AST.md](docs/README_AST.md) - AST (Abstract Syntax Tree) documentation
- [docs/NEW_FEATURES.md](docs/NEW_FEATURES.md) - Advanced features (arrays, classes, exceptions, etc.)
- [docs/ferdek.ebnf](docs/ferdek.ebnf) - Language grammar specification

## Current Status

✅ Lexer - Complete
✅ AST - Complete
⏳ Parser - In progress
⏳ Interpreter - Planned
⏳ Compiler - Planned

## Contributing

This is an educational/humorous project. Feel free to experiment and extend it!

## License

Open source - use freely for educational purposes.
