# AST - Abstract Syntax Tree dla języka Ferdek

## Wprowadzenie

Moduł `ast.ml` definiuje strukturę Abstract Syntax Tree (AST) dla języka Ferdek. AST to reprezentacja drzewa składniowego programu, która jest tworzona przez parser i używana przez interpreter/kompilator do wykonania kodu.

## Struktura AST

### Operatory

#### Operatory arytmetyczne (`arith_op`)
- `Plus` - dodawanie (`BABKA DAWAJ RENTĘ`)
- `Minus` - odejmowanie (`PASZOŁ WON`)
- `Multiply` - mnożenie (`ROZDUPCĘ BANK`)
- `Divide` - dzielenie (`MUSZĘ DO SRACZA`)
- `Modulo` - reszta z dzielenia (`PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ`)

#### Operatory porównania (`comparison_op`)
- `Equal` - równość (`TO PANU SIĘ CHCE WTEDY KIEDY MNIE`)
- `NotEqual` - nierówność (`PAN TU NIE MIESZKASZ`)
- `Greater` - większe niż (`MOJA NOGA JUŻ TUTAJ NIE POSTANIE`)
- `Less` - mniejsze niż (`CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU`)

#### Operatory logiczne (`logical_op`)
- `And` - koniunkcja (`PIWO I TELEWIZOR`)
- `Or` - alternatywa (`ALBO JUTRO U ADWOKATA`)

### Wyrażenia (`expr`)

Wyrażenia reprezentują obliczenia i wartości:

- `IntLiteral of int` - literal całkowity (np. `42`)
- `StringLiteral of string` - literal tekstowy (np. `"Cześć!"`)
- `BoolLiteral of bool` - literal logiczny (`A ŻEBYŚ PAN WIEDZIAŁ` / `GÓWNO PRAWDA`)
- `NullLiteral` - wartość null (`W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM`)
- `Identifier of string` - identyfikator zmiennej
- `BinaryOp of expr * arith_op * expr` - operacja arytmetyczna
- `ComparisonOp of expr * comparison_op * expr` - porównanie
- `LogicalOp of expr * logical_op * expr` - operacja logiczna
- `ArrayAccess of string * expr` - dostęp do elementu tablicy
- `FunctionCall of string * expr list` - wywołanie funkcji
- `NewObject of string * expr list` - utworzenie nowego obiektu
- `Parenthesized of expr` - wyrażenie w nawiasach

### Instrukcje (`stmt`)

Instrukcje reprezentują akcje do wykonania:

- `VarDecl of string * expr` - deklaracja zmiennej
  ```ferdek
  CYCU PRZYNIEŚ NO piwa TO NIE SĄ TANIE RZECZY 6
  ```

- `ArrayDecl of string * expr list` - deklaracja tablicy
  ```ferdek
  PANIE TO JEST PRYWATNA PUBLICZNA TABLICA liczby TO NIE SĄ TANIE RZECZY [1, 2, 3]
  ```

- `Print of expr` - wypisanie wartości
  ```ferdek
  PANIE SENSACJA REWELACJA "Cześć!"
  ```

- `Read of string` - wczytanie wartości
  ```ferdek
  CO TAM U PANA SŁYCHAĆ x
  ```

- `Assign of string * expr` - przypisanie wartości
  ```ferdek
  O KURDE MAM POMYSŁA piwa A PROSZĘ BARDZO 10 NO I GITARA
  ```

- `If of expr * stmt list * stmt list option` - instrukcja warunkowa
  ```ferdek
  NO JAK NIE JAK TAK warunek
      instrukcje
  A DUPA TAM
      instrukcje_else
  DO CHAŁUPY ALE JUŻ
  ```

- `While of expr * stmt list` - pętla while
  ```ferdek
  CHLUŚNIEM BO UŚNIEM warunek
      instrukcje
  A ROBIĆ NI MA KOMU
  ```

- `FunctionCallStmt of string * expr list` - wywołanie funkcji jako instrukcja
  ```ferdek
  W MORDĘ JEŻA funkcja(arg1, arg2)
  ```

- `FunctionCallWithAssign of string * string * expr list` - wywołanie funkcji z przypisaniem
  ```ferdek
  AFERA JEST wynik W MORDĘ JEŻA funkcja(arg1, arg2)
  ```

- `Return of expr option` - zwrócenie wartości
  ```ferdek
  I JA INFORMUJĘ ŻE WYCHODZĘ wynik
  ```

- `Try of stmt list * string * stmt list` - obsługa wyjątków
  ```ferdek
  HELENA MUSZĘ CI COŚ POWIEDZIEĆ
      instrukcje
  HELENA MAM ZAWAŁ err
      instrukcje_catch
  ```

- `Throw of expr` - rzucenie wyjątku
  ```ferdek
  O KARWASZ TWARZ błąd
  ```

- `Break` - przerwanie pętli
  ```ferdek
  A POCAŁUJCIE MNIE WSZYSCY W DUPĘ
  ```

- `Continue` - kontynuacja pętli
  ```ferdek
  AKUKARACZA
  ```

### Deklaracje wysokopoziomowe

#### Funkcje (`function_decl`)

```ocaml
type function_decl = {
  name: string;           (* nazwa funkcji *)
  params: param list;     (* parametry *)
  has_return: bool;       (* czy funkcja zwraca wartość *)
  body: stmt list;        (* ciało funkcji *)
}
```

Przykład w języku Ferdek:
```ferdek
ALE WIE PAN JA ZASADNICZO dolej_browarka
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO ile
    CYCU PRZYNIEŚ NO wynik TO NIE SĄ TANIE RZECZY 0
    O KURDE MAM POMYSŁA wynik A PROSZĘ BARDZO ile BABKA DAWAJ RENTĘ 2 NO I GITARA
    I JA INFORMUJĘ ŻE WYCHODZĘ wynik
DO WIDZENIA PANU
```

#### Klasy (`class_decl`)

```ocaml
type class_decl = {
  name: string;                    (* nazwa klasy *)
  fields: (string * expr) list;    (* pola klasy *)
  methods: function_decl list;     (* metody klasy *)
}
```

Przykład w języku Ferdek:
```ferdek
ALE JAJA Ferdek
    CYCU PRZYNIEŚ NO wiek TO NIE SĄ TANIE RZECZY 50

    ALE WIE PAN JA ZASADNICZO powitanie
        PANIE SENSACJA REWELACJA "Cześć!"
    DO WIDZENIA PANU
DO WIDZENIA PANU
```

#### Import (`import_stmt`)

```ocaml
type import_stmt = string
```

Przykład:
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ modul
```

### Program (`program`)

Program składa się z listy deklaracji najwyższego poziomu:

```ocaml
type top_level_decl =
  | Import of import_stmt
  | Statement of stmt
  | FunctionDecl of function_decl
  | ClassDecl of class_decl

type program = {
  declarations: top_level_decl list;
}
```

## Funkcje pomocnicze

### Tworzenie programu

```ocaml
val empty_program : unit -> program
val add_declaration : program -> top_level_decl -> program
```

Przykład użycia:
```ocaml
let prog = empty_program ()
let prog = add_declaration prog (Statement (VarDecl ("x", IntLiteral 42)))
let prog = add_declaration prog (Statement (Print (Identifier "x")))
```

### Konwersja do string

Moduł dostarcza funkcje do konwersji struktur AST na czytelny tekst:

```ocaml
val string_of_expr : expr -> string
val string_of_stmt : string -> stmt -> string
val string_of_function_decl : string -> function_decl -> string
val string_of_class_decl : string -> class_decl -> string
val string_of_program : program -> string
```

Te funkcje są przydatne do debugowania i wyświetlania struktury AST.

## Przykład użycia

```ocaml
open Ast

(* Tworzymy program: var piwa = 6; print piwa; *)
let prog =
  let p = empty_program () in
  let p = add_declaration p (Statement (VarDecl ("piwa", IntLiteral 6))) in
  let p = add_declaration p (Statement (Print (Identifier "piwa"))) in
  p

(* Wyświetlamy program *)
let () = print_endline (string_of_program prog)
```

Wyjście:
```
program:
var piwa = 6
print piwa
```

## Testowanie

Moduł AST można przetestować uruchamiając:

```bash
make test_ast
./test_ast
```

Lub uruchomić wszystkie testy:

```bash
make test
```

## Następne kroki

Po zdefiniowaniu AST następnymi krokami w rozwoju języka Ferdek są:

1. **Parser** - implementacja parsera, który tworzy AST z tokenów
2. **Interpreter** - wykonywanie programu reprezentowanego przez AST
3. **Kompilator** - generowanie kodu maszynowego z AST
4. **Optymalizator** - optymalizacja drzewa AST przed wykonaniem

## Zobacz także

- [ferdek.ebnf](ferdek.ebnf) - Gramatyka języka Ferdek
- [README_LEXER.md](README_LEXER.md) - Dokumentacja lexera
- [INSTRUKCJA.md](INSTRUKCJA.md) - Kompletna instrukcja użycia języka
