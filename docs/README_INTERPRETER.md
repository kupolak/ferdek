# Interpreter - Ferdek Programming Language

## Overview

The Ferdek interpreter executes programs directly from the Abstract Syntax Tree (AST). It provides a complete runtime environment with support for variables, functions, arrays, control flow, and error handling.

## Features

### ✅ Implemented Features

- **Variables**: Declaration, assignment, and retrieval
- **Data Types**:
  - Integers (`VInt`)
  - Strings (`VString`)
  - Booleans (`VBool`)
  - Null (`VNull`)
  - Arrays (`VArray`)
  - Functions (`VFunction`)
- **Arithmetic Operations**: `+`, `-`, `*`, `/`, `%`
- **Comparison Operations**: `==`, `!=`, `>`, `<`
- **Logical Operations**: `&&`, `||`
- **Control Flow**:
  - If/else statements
  - While loops
  - Break and continue
- **Functions**:
  - Function definitions
  - Parameters and return values
  - Closures
- **Arrays**:
  - Array declaration
  - Array indexing
- **I/O**:
  - Print statements
  - Read input
- **Exception Handling**: Try/catch/throw

### ⏳ Partial Implementation

- **Classes**: Basic structure defined, full OOP features pending
- **Imports**: Module system planned

## Architecture

### Runtime Values

```ocaml
type value =
  | VInt of int                         (* Integer value *)
  | VString of string                   (* String value *)
  | VBool of bool                       (* Boolean value *)
  | VNull                               (* Null value *)
  | VArray of value array               (* Array of values *)
  | VFunction of function_decl * environment  (* Function with closure *)
  | VObject of (string, value) Hashtbl.t      (* Object/class instance *)
```

### Environment

The interpreter uses a hierarchical environment system:

```ocaml
type environment = {
  mutable vars: (string, value) Hashtbl.t;  (* Variable bindings *)
  parent: environment option;                (* Parent scope *)
}
```

This enables:
- **Lexical scoping**: Variables are resolved in the current scope first, then parent scopes
- **Function closures**: Functions capture their defining environment
- **Local variables**: Each function call creates a new environment

### Execution Flow

```
Program → eval_program
  ├→ Top-level declarations → eval_top_level_decl
  │   ├→ Imports (TODO)
  │   ├→ Statements → eval_stmt
  │   ├→ Functions → stored in environment
  │   └→ Classes → stored in environment
  └→ Result (Ok () | Error msg)
```

## Usage

### Running a File

```bash
./ferdek program.ferdek
```

### Interactive REPL

```bash
./ferdek
```

The REPL automatically wraps your input in a program structure:

```
> PANIE SENSACJA REWELACJA "Hello"
Hello
> CYCU PRZYNIEŚ NO x TO NIE SĄ TANIE RZECZY 42
> PANIE SENSACJA REWELACJA x
42
```

### From OCaml Code

```ocaml
(* Parse and run a string *)
let code = "CO JEST KURDE
PANIE SENSACJA REWELACJA \"Hello\"
MOJA NOGA JUŻ TUTAJ NIE POSTANIE"

let lexbuf = Lexing.from_string code in
let ast = Parser.program Lexer.token lexbuf in
match Interpreter.eval_program ast with
| Ok () -> print_endline "Success!"
| Error msg -> Printf.eprintf "Error: %s\n" msg
```

## Examples

### Variables and Arithmetic

```ferdek
CO JEST KURDE

CYCU PRZYNIEŚ NO x
TO NIE SĄ TANIE RZECZY 10

O KURDE MAM POMYSŁA x
A PROSZĘ BARDZO x
BABKA DAWAJ RENTĘ 5
NO I GITARA

PANIE SENSACJA REWELACJA x  RYM CYM CYM Prints: 15

MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

### Control Flow

```ferdek
CO JEST KURDE

CYCU PRZYNIEŚ NO i
TO NIE SĄ TANIE RZECZY 5

CHLUŚNIEM BO UŚNIEM i GRUBA ŚWINIA 0
    PANIE SENSACJA REWELACJA i
    O KURDE MAM POMYSŁA i
    A PROSZĘ BARDZO i
    PASZOŁ WON 1
    NO I GITARA
A ROBIĆ NI MA KOMU

MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Output:
```
5
4
3
2
1
```

### Functions

```ferdek
CO JEST KURDE

ALE WIE PAN JA ZASADNICZO fibonacci
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO n
    NO JAK NIE JAK TAK n CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU 2
        I JA INFORMUJĘ ŻE WYCHODZĘ n
    DO CHAŁUPY ALE JUŻ

    CYCU PRZYNIEŚ NO a
    TO NIE SĄ TANIE RZECZY 0
    CYCU PRZYNIEŚ NO b
    TO NIE SĄ TANIE RZECZY 0

    AFERA JEST a W MORDĘ JEŻA fibonacci(n PASZOŁ WON 1)
    AFERA JEST b W MORDĘ JEŻA fibonacci(n PASZOŁ WON 2)

    CYCU PRZYNIEŚ NO result
    TO NIE SĄ TANIE RZECZY 0
    O KURDE MAM POMYSŁA result
    A PROSZĘ BARDZO a
    BABKA DAWAJ RENTĘ b
    NO I GITARA

    I JA INFORMUJĘ ŻE WYCHODZĘ result
DO WIDZENIA PANU

CYCU PRZYNIEŚ NO fib10
TO NIE SĄ TANIE RZECZY 0
AFERA JEST fib10 W MORDĘ JEŻA fibonacci(10)
PANIE SENSACJA REWELACJA fib10

MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

### Arrays

```ferdek
CO JEST KURDE

PANIE TO JEST PRYWATNA PUBLICZNA TABLICA numbers
TO NIE SĄ TANIE RZECZY [1, 2, 3, 4, 5]

PANIE SENSACJA REWELACJA numbers

CYCU PRZYNIEŚ NO first
TO NIE SĄ TANIE RZECZY 0
O KURDE MAM POMYSŁA first
A PROSZĘ BARDZO WYPIERDZIELAJ PAN NA POZYCJĘ numbers[0]
NO I GITARA

PANIE SENSACJA REWELACJA first  RYM CYM CYM Prints: 1

MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

## Error Handling

The interpreter provides several types of errors:

### Runtime Errors

```ocaml
exception RuntimeError of string
```

Common runtime errors:
- Undefined variable
- Division by zero
- Array index out of bounds
- Type errors
- Function argument mismatch

### Control Flow Exceptions

```ocaml
exception ReturnValue of value      (* Function return *)
exception BreakLoop                 (* Break from loop *)
exception ContinueLoop             (* Continue loop *)
exception ThrowException of value   (* User-thrown exception *)
```

### Error Messages

```bash
$ ./ferdek bad_program.ferdek
Runtime error: Undefined variable: x

$ ./ferdek
> O KURDE MAM POMYSŁA x A PROSZĘ BARDZO 10 PASZOŁ WON 0 NO I GITARA
Runtime error: Division by zero
```

## Type Coercion

The interpreter performs automatic type coercion in certain contexts:

### To Boolean
- `VBool b` → `b`
- `VInt 0` → `false`, other integers → `true`
- `VString ""` → `false`, non-empty strings → `true`
- `VNull` → `false`
- Other values → `true`

### To Integer
- `VInt n` → `n`
- `VBool true` → `1`, `false` → `0`
- `VString s` → parsed as integer, or `0` if invalid
- `VNull` → `0`

## Performance Considerations

The interpreter is designed for clarity and correctness rather than performance:

- **Hashtable lookups**: O(1) average for variable access
- **Environment chain**: O(d) where d is scope depth
- **Function calls**: Create new environment (allocation overhead)
- **No optimizations**: Direct AST traversal, no bytecode

For production use, consider:
- Compiler backend for better performance
- Bytecode interpreter with optimizations
- JIT compilation

## Implementation Details

### Variable Resolution

Variables are resolved using lexical scoping:

1. Check current environment
2. If not found, check parent environment recursively
3. If still not found, raise RuntimeError

### Function Closures

Functions capture their defining environment:

```ocaml
let eval_function_call env name args =
  let func = get_var env name in
  match func with
  | VFunction (fdecl, closure_env) ->
      let func_env = create_env (Some closure_env) in
      (* Execute with closure environment *)
```

This enables proper closure behavior and nested function definitions.

### Loop Control

Break and continue are implemented using exceptions:

```ocaml
let rec loop () =
  if condition then
    try
      execute_body ();
      loop ()
    with
    | BreakLoop -> ()              (* Exit loop *)
    | ContinueLoop -> loop ()      (* Next iteration *)
```

## Extending the Interpreter

### Adding New Built-in Functions

1. Define the function in the global environment:

```ocaml
let global_env () =
  let env = create_env None in
  (* Add built-in functions *)
  define_var env "len" (VFunction ({ ... }, env));
  env
```

2. Handle special forms in `eval_function_call`

### Adding New Data Types

1. Extend the `value` type:

```ocaml
type value =
  | ...
  | VMyType of my_type
```

2. Update `string_of_value`, `to_bool`, `to_int`

3. Handle in expression evaluation and operations

## See Also

- [AST Documentation](README_AST.md) - Structure of the Abstract Syntax Tree
- [Parser Documentation](README_PARSER.md) - Parsing Ferdek code
- [Language Specification](ferdek.ebnf) - Complete grammar
