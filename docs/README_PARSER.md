# Parser - Ferdek Programming Language

## Overview

The Ferdek parser is implemented using [Menhir](http://gallium.inria.fr/~fpottier/menhir/), an LR(1) parser generator for OCaml. It takes a stream of tokens from the lexer and constructs an Abstract Syntax Tree (AST) that represents the structure of the program.

## Implementation

The parser is defined in [src/parser.mly](../src/parser.mly) using Menhir's declarative syntax.

### Key Features

- **LR(1) parsing** with lookahead for resolving ambiguities
- **Type-safe AST construction** using OCaml's type system
- **Error recovery** with clear error messages
- **Operator precedence** handling for arithmetic and logical operations

### Grammar Structure

The parser implements the complete Ferdek grammar with the following main components:

#### Program Structure
```ocaml
program:
  | PROGRAM_START decls=list(top_level_decl) PROGRAM_END EOF
    { { declarations = decls } }
```

A Ferdek program consists of:
- Program start marker: `CO JEST KURDE`
- List of top-level declarations
- Program end marker: `MOJA NOGA JUŻ TUTAJ NIE POSTANIE`

#### Top-Level Declarations

- **Imports**: `O KOGO MOJE PIĘKNE OCZY WIDZĄ module_name`
- **Statements**: Variable declarations, assignments, control flow
- **Functions**: Function definitions with parameters and return values
- **Classes**: Class definitions with fields and methods

#### Statements

The parser recognizes the following statement types:

1. **Variable Declaration**
   ```ferdek
   CYCU PRZYNIEŚ NO x TO NIE SĄ TANIE RZECZY 42
   ```

2. **Array Declaration**
   ```ferdek
   PANIE TO JEST PRYWATNA PUBLICZNA TABLICA arr TO NIE SĄ TANIE RZECZY [1, 2, 3]
   ```

3. **Print Statement**
   ```ferdek
   PANIE SENSACJA REWELACJA "Hello World"
   ```

4. **Assignment**
   ```ferdek
   O KURDE MAM POMYSŁA x A PROSZĘ BARDZO 10 NO I GITARA
   ```

5. **If Statement**
   ```ferdek
   NO JAK NIE JAK TAK x GRUBA ŚWINIA 0
       PANIE SENSACJA REWELACJA "Positive"
   A DUPA TAM
       PANIE SENSACJA REWELACJA "Non-positive"
   DO CHAŁUPY ALE JUŻ
   ```

6. **While Loop**
   ```ferdek
   CHLUŚNIEM BO UŚNIEM x GRUBA ŚWINIA 0
       PANIE SENSACJA REWELACJA x
       O KURDE MAM POMYSŁA x A PROSZĘ BARDZO x PASZOŁ WON 1 NO I GITARA
   A ROBIĆ NI MA KOMU
   ```

7. **Function Call**
   ```ferdek
   W MORDĘ JEŻA funkcja(arg1, arg2)
   ```

8. **Exception Handling**
   ```ferdek
   HELENA MUSZĘ CI COŚ POWIEDZIEĆ
       PANIE SENSACJA REWELACJA "Try this"
   HELENA MAM ZAWAŁ err
       PANIE SENSACJA REWELACJA "Caught error"
   ```

#### Expressions

The parser supports a rich expression language with proper operator precedence:

**Precedence levels (from lowest to highest):**
1. Logical OR (`ALBO JUTRO U ADWOKATA`)
2. Logical AND (`PIWO I TELEWIZOR`)
3. Comparison operators (`==`, `!=`, `>`, `<`)
4. Addition and subtraction (`+`, `-`)
5. Multiplication, division, and modulo (`*`, `/`, `%`)

**Expression types:**
- Literals: integers, strings, booleans, null
- Identifiers: variable references
- Binary operations: arithmetic, comparison, logical
- Array access: `WYPIERDZIELAJ PAN NA POZYCJĘ arr[index]`
- Function calls: `W MORDĘ JEŻA func(args)`
- Object creation: `DZIAD ZDZIADZIAŁY JEDEN ClassName(args)`
- Parenthesized expressions

#### Functions

Functions can be declared with or without parameters and return values:

```ferdek
ALE WIE PAN JA ZASADNICZO funkcja
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO param1, param2
    CYCU PRZYNIEŚ NO result TO NIE SĄ TANIE RZECZY 0
    O KURDE MAM POMYSŁA result A PROSZĘ BARDZO param1 BABKA DAWAJ RENTĘ param2 NO I GITARA
    I JA INFORMUJĘ ŻE WYCHODZĘ result
DO WIDZENIA PANU
```

#### Classes

Classes can contain fields and methods:

```ferdek
ALE JAJA ClassName
    CYCU PRZYNIEŚ NO field1 TO NIE SĄ TANIE RZECZY 0

    ALE WIE PAN JA ZASADNICZO method1
        PANIE SENSACJA REWELACJA "Method called"
    DO WIDZENIA PANU
DO WIDZENIA PANU
```

### Operator Mapping

The parser maps Ferdek's colorful operators to standard operations:

| Ferdek Operator | Standard | Type |
|----------------|----------|------|
| `BABKA DAWAJ RENTĘ` | `+` | Addition |
| `PASZOŁ WON` | `-` | Subtraction |
| `ROZDUPCĘ BANK` | `*` | Multiplication |
| `MUSZĘ DO SRACZA` | `/` | Division |
| `PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ` | `%` | Modulo |
| `TO PANU SIĘ CHCE WTEDY KIEDY MNIE` | `==` | Equal |
| `PAN TU NIE MIESZKASZ` | `!=` | Not equal |
| `GRUBA ŚWINIA` | `>` | Greater than |
| `CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU` | `<` | Less than |
| `PIWO I TELEWIZOR` | `&&` | Logical AND |
| `ALBO JUTRO U ADWOKATA` | `\|\|` | Logical OR |

## Usage

### Parsing from a String

```ocaml
let code = "CO JEST KURDE
PANIE SENSACJA REWELACJA \"Hello\"
MOJA NOGA JUŻ TUTAJ NIE POSTANIE"

let lexbuf = Lexing.from_string code in
try
  let ast = Parser.program Lexer.token lexbuf in
  (* Use the AST *)
  print_endline (Ast.string_of_program ast)
with
| Lexer.LexError msg ->
    Printf.eprintf "Lexer error: %s\n" msg
| Parser.Error ->
    Printf.eprintf "Parse error\n"
```

### Parsing from a File

```ocaml
let parse_file filename =
  let ic = open_in filename in
  let lexbuf = Lexing.from_channel ic in
  try
    let ast = Parser.program Lexer.token lexbuf in
    close_in ic;
    Some ast
  with
  | Lexer.LexError msg ->
      close_in ic;
      Printf.eprintf "Lexer error: %s\n" msg;
      None
  | Parser.Error ->
      close_in ic;
      Printf.eprintf "Parse error\n";
      None
```

## Building

The parser is built using Menhir with type inference enabled:

```bash
make
```

This will:
1. Generate the parser from `src/parser.mly`
2. Compile the parser with the AST module
3. Link everything together

## Testing

Run the parser tests:

```bash
make test_parser
./test_parser
```

Or run all tests:

```bash
make test
```

## Error Handling

The parser provides error handling through:

1. **Lexer Errors**: Caught as `Lexer.LexError` exceptions with descriptive messages
2. **Parse Errors**: Caught as `Parser.Error` exceptions when the input doesn't match the grammar

## Implementation Details

### Menhir Flags

The parser is compiled with the following Menhir flags:

- `--infer`: Enable type inference for non-terminal symbols
- `-la 1`: Enable lookahead annotations

### Conflict Resolution

The parser has some shift/reduce conflicts that are resolved using operator precedence declarations. These are normal and expected in expression grammars.

## See Also

- [AST Documentation](README_AST.md) - Structure of the Abstract Syntax Tree
- [Lexer Documentation](README_LEXER.md) - Token generation
- [Ferdek Grammar](ferdek.ebnf) - EBNF grammar specification
