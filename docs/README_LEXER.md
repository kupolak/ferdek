# Ferdek Language Lexer

The lexer is implemented using OCamllex based on the EBNF specification of the Ferdek language.

## Project Structure

- `lexer.mll` - lexer definition in OCamllex
- `parser.mly` - token definitions (parser skeleton)
- `ferdek.ebnf` - language grammar specification

## Compilation

### Generating lexer and parser

```bash
ocamllex lexer.mll      # generates lexer.ml
menhir parser.mly       # generates parser.ml and parser.mli
```

### Compiling to bytecode

```bash
ocamlc -c parser.mli
ocamlc -c parser.ml
ocamlc -c lexer.ml
```

### Compiling the test program

```bash
ocamlc -o test_lexer parser.cmo lexer.cmo test_lexer.ml
```

## Tokens

The lexer recognizes the following token categories:

### Program structure
- `PROGRAM_START` - "CO JEST KURDE"
- `PROGRAM_END` - "MOJA NOGA JUŻ TUTAJ NIE POSTANIE"

### Variable declarations
- `VAR_DECL` - "CYCU PRZYNIEŚ NO"
- `VAR_INIT` - "TO NIE SĄ TANIE RZECZY"

### I/O statements
- `PRINT` - "PANIE SENSACJA REWELACJA"
- `READ` - "CO TAM U PANA SŁYCHAĆ"

### Assignment
- `ASSIGN_START` - "O KURDE MAM POMYSŁA"
- `ASSIGN_OP` - "A PROSZĘ BARDZO"
- `ASSIGN_END` - "NO I GITARA"

### Conditionals
- `IF` - "NO JAK NIE JAK TAK"
- `ELSE` - "A DUPA TAM"
- `END_IF` - "DO CHAŁUPY ALE JUŻ"

### Loops
- `WHILE` - "CHLUŚNIEM BO UŚNIEM"
- `END_WHILE` - "A ROBIĆ NI MA KOMU"

### Functions
- `FUNC_DECL` - "ALE WIE PAN JA ZASADNICZO"
- `FUNC_RETURNS` - "NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ"
- `FUNC_PARAMS` - "NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO"
- `FUNC_END` - "DO WIDZENIA PANU"
- `FUNC_CALL` - "W MORDĘ JEŻA"
- `FUNC_CALL_ASSIGN` - "AFERA JEST"
- `RETURN` - "I JA INFORMUJĘ ŻE WYCHODZĘ"

### Modules and imports
- `IMPORT` - "O KOGO MOJE PIĘKNE OCZY WIDZĄ"

### Arrays
- `ARRAY_DECL` - "PANIE TO JEST PRYWATNA PUBLICZNA TABLICA"
- `ARRAY_INDEX` - "WYPIERDZIELAJ PAN NA POZYCJĘ"

### Exception handling
- `TRY` - "HELENA MUSZĘ CI COŚ POWIEDZIEĆ"
- `CATCH` - "HELENA MAM ZAWAŁ"
- `THROW` - "O KARWASZ TWARZ"

### Control flow
- `BREAK` - "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ"
- `CONTINUE` - "AKUKARACZA"

### Object-oriented programming
- `CLASS` - "ALE JAJA"
- `NEW` - "DZIAD ZDZIADZIAŁY JEDEN"

### Null value
- `NULL` - "W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM"

### Arithmetic operators
- `PLUS` - "BABKA DAWAJ RENTĘ" (+)
- `MINUS` - "PASZOŁ WON" (-)
- `MULTIPLY` - "ROZDUPCĘ BANK" (*)
- `DIVIDE` - "MUSZĘ DO SRACZA" (/)
- `MODULO` - "PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ" (%)

### Comparison operators
- `EQUAL` - "TO PANU SIĘ CHCE WTEDY KIEDY MNIE" (==)
- `NOT_EQUAL` - "PAN TU NIE MIESZKASZ" (!=)
- `GREATER` - "MOJA NOGA JUŻ TUTAJ NIE POSTANIE" (>)
- `LESS` - "CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU" (<)

### Logical operators
- `AND` - "PIWO I TELEWIZOR"
- `OR` - "ALBO JUTRO U ADWOKATA"

### Boolean values
- `TRUE` - "A ŻEBYŚ PAN WIEDZIAŁ"
- `FALSE` - "GÓWNO PRAWDA"

### Separators
- `LPAREN` - (
- `RPAREN` - )
- `LBRACKET` - [
- `RBRACKET` - ]
- `COMMA` - ,

### Literals and identifiers
- `INTEGER` - integer numbers
- `STRING` - strings in quotes
- `IDENTIFIER` - variable and function identifiers

### Comments
- `RYM CYM CYM` - single-line comment (to end of line)

## Polish Character Support

The lexer supports Polish characters in keywords (ą, ę, ć, ł, ń, ó, ś, ź, ż).

## Helper Functions

- `token` - main lexer function
- `line_comment` - comment handling
- `read_string` - string parsing with escape sequence support (\n, \t, \\, \")
