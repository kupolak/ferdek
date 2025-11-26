# Ferdek Lexer Usage Guide

## Requirements

- OCaml (version 4.08 or newer)
- OCamllex
- Menhir (parser generator)

### Installation on macOS

```bash
brew install ocaml opam
opam init
opam install menhir
```

### Installation on Linux (Ubuntu/Debian)

```bash
sudo apt-get install ocaml opam
opam init
opam install menhir
```

## Compilation

### Step 1: Generate code from lexer and parser

```bash
make
```

This command automatically:
1. Generates `parser.ml` and `parser.mli` from `parser.mly`
2. Generates `lexer.ml` from `lexer.mll`
3. Compiles all files
4. Creates the `test_lexer` executable

### Step 2: Run tests

```bash
make test
```

Or directly:

```bash
./test_lexer
```

## Testing with Files

### Testing a single file

```bash
./test_lexer examples/hello.ferdek
```

### Testing other examples

```bash
./test_lexer examples/variables.ferdek
./test_lexer examples/conditional.ferdek
```

## Usage Example in Your Own Code

```ocaml
(* Tokenizing a string *)
let input = "CO JEST KURDE\nPANIE SENSACJA REWELACJA \"Hello\"\nTRZEBA SPAĆ ŻEBY RANO DO ROBOTY WSTAĆ" in
let lexbuf = Lexing.from_string input in
let rec tokenize () =
  match Lexer.token lexbuf with
  | Parser.EOF -> []
  | tok -> tok :: tokenize ()
in
let tokens = tokenize ()

(* Tokenizing a file *)
let ic = open_in "program.ferdek" in
let lexbuf = Lexing.from_channel ic in
let rec tokenize () =
  match Lexer.token lexbuf with
  | Parser.EOF -> close_in ic; []
  | tok -> tok :: tokenize ()
in
let tokens = tokenize ()
```

## Token Structure

Each token is a value of the type defined in `parser.mly`:

```ocaml
type token =
  | PROGRAM_START
  | PROGRAM_END
  | VAR_DECL
  | IDENTIFIER of string
  | INTEGER of int
  | STRING of string
  (* ... and others *)
```

## Error Handling

The lexer throws a `Lexer.LexError of string` exception in case of:
- Unrecognized characters
- Unterminated strings

Error handling example:

```ocaml
try
  let tokens = tokenize lexbuf in
  (* process tokens *)
with
| Lexer.LexError msg ->
    Printf.eprintf "Lexical error: %s\n" msg
```

## Cleanup

### Cleaning intermediate files

```bash
make clean
```

This command removes:
- Compiled files (`.cmi`, `.cmo`, `.cmx`, `.o`)
- Generated files (`lexer.ml`, `parser.ml`, `parser.mli`)
- The `test_lexer` executable

## Extending the Lexer

### Adding new tokens

1. Add the token definition in `parser.mly`:
```ocaml
%token NEW_TOKEN
```

2. Add the rule in `lexer.mll`:
```ocaml
| "NEW KEYWORD" { NEW_TOKEN }
```

3. Add handling in the `string_of_token` function in `test_lexer.ml`:
```ocaml
| NEW_TOKEN -> "NEW_TOKEN"
```

4. Recompile:
```bash
make clean
make
```

## Debugging

### Enabling debug mode in OCamllex

You can add `Printf.eprintf` calls in the `lexer.mll` file for debugging:

```ocaml
| "CO JEST KURDE" {
    Printf.eprintf "Found PROGRAM_START\n";
    PROGRAM_START
  }
```

### Checking file position

Lexbuf contains position information:

```ocaml
let pos = lexbuf.lex_curr_p in
Printf.printf "Line: %d, Column: %d\n"
  pos.pos_lnum
  (pos.pos_cnum - pos.pos_bol)
```

## Known Limitations

1. Comments are single-line only (from `RYM CYM CYM` to end of line)
2. Strings must be in quotes and cannot contain multi-line text (unless using `\n`)
3. Identifiers must start with a letter

## Next Steps

After completing the lexer, the next step is to implement a parser that:
1. Accepts the token stream from the lexer
2. Builds an abstract syntax tree (AST)
3. Checks the syntactic correctness of the program

An example AST structure might look like this:

```ocaml
type expr =
  | Int of int
  | Bool of bool
  | Var of string
  | BinOp of expr * binop * expr
  | ...

type stmt =
  | VarDecl of string * expr
  | Assign of string * expr
  | Print of expr
  | If of expr * stmt list * stmt list option
  | ...

type program = stmt list
```
