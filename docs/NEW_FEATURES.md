# New Features in Ferdek Language

This document describes the extended features added to the Ferdek programming language.

## Import Modules

**Keyword**: `O KOGO MOJE PIĘKNE OCZY WIDZĄ`

Import external modules into your program.

**Syntax**:
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ ModuleName
```

**Example**:
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ MathUtils
O KOGO MOJE PIĘKNE OCZY WIDZĄ FileSystem
```

---

## Arrays

### Array Declaration

**Keyword**: `PANIE TO JEST PRYWATNA PUBLICZNA TABLICA`

Declare and initialize an array.

**Syntax**:
```ferdek
PANIE TO JEST PRYWATNA PUBLICZNA TABLICA arrayName
TO NIE SĄ TANIE RZECZY [element1, element2, element3]
```

**Example**:
```ferdek
PANIE TO JEST PRYWATNA PUBLICZNA TABLICA piwa
TO NIE SĄ TANIE RZECZY [1, 2, 3, 4, 5]

PANIE TO JEST PRYWATNA PUBLICZNA TABLICA pusta
TO NIE SĄ TANIE RZECZY []
```

### Array Access

**Keyword**: `WYPIERDZIELAJ PAN NA POZYCJĘ`

Access elements in an array by index.

**Syntax**:
```ferdek
WYPIERDZIELAJ PAN NA POZYCJĘ arrayName[index]
```

**Example**:
```ferdek
WYPIERDZIELAJ PAN NA POZYCJĘ piwa[0]
WYPIERDZIELAJ PAN NA POZYCJĘ piwa[2]
```

---

## Exception Handling

### Try-Catch

**Keywords**:
- `HELENA MUSZĘ CI COŚ POWIEDZIEĆ` (try)
- `HELENA MAM ZAWAŁ` (catch)

Handle errors and exceptions gracefully.

**Syntax**:
```ferdek
HELENA MUSZĘ CI COŚ POWIEDZIEĆ
    RYM CYM CYM code that might throw
HELENA MAM ZAWAŁ errorVariable
    RYM CYM CYM error handling code
```

**Example**:
```ferdek
HELENA MUSZĘ CI COŚ POWIEDZIEĆ
    PANIE SENSACJA REWELACJA "Trying something risky..."
    WYPIERDZIELAJ PAN NA POZYCJĘ tablica[100]
HELENA MAM ZAWAŁ blad
    PANIE SENSACJA REWELACJA "Error occurred!"
    PANIE SENSACJA REWELACJA blad
```

### Throw

**Keyword**: `O KARWASZ TWARZ`

Throw an exception or error.

**Syntax**:
```ferdek
O KARWASZ TWARZ errorMessage
```

**Example**:
```ferdek
NO JAK NIE JAK TAK wiek CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU 0
    O KARWASZ TWARZ "Age cannot be negative!"
DO CHAŁUPY ALE JUŻ
```

---

## Control Flow

### Break

**Keyword**: `A POCAŁUJCIE MNIE WSZYSCY W DUPĘ`

Exit from a loop early.

**Syntax**:
```ferdek
A POCAŁUJCIE MNIE WSZYSCY W DUPĘ
```

**Example**:
```ferdek
CHLUŚNIEM BO UŚNIEM i CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU 10
    NO JAK NIE JAK TAK i TO PANU SIĘ CHCE WTEDY KIEDY MNIE 5
        A POCAŁUJCIE MNIE WSZYSCY W DUPĘ
    DO CHAŁUPY ALE JUŻ
    PANIE SENSACJA REWELACJA i
A ROBIĆ NI MA KOMU
```

### Continue

**Keyword**: `AKUKARACZA`

Skip to the next iteration of a loop.

**Syntax**:
```ferdek
AKUKARACZA
```

**Example**:
```ferdek
CHLUŚNIEM BO UŚNIEM i CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU 10
    NO JAK NIE JAK TAK i TO PANU SIĘ CHCE WTEDY KIEDY MNIE 5
        AKUKARACZA
    DO CHAŁUPY ALE JUŻ
    PANIE SENSACJA REWELACJA i
A ROBIĆ NI MA KOMU
```

---

## Object-Oriented Programming

### Class Declaration

**Keyword**: `ALE JAJA`

Define a class with properties and methods.

**Syntax**:
```ferdek
ALE JAJA ClassName
    RYM CYM CYM class members (variables and functions)
DO WIDZENIA PANU
```

**Example**:
```ferdek
ALE JAJA Osoba
    CYCU PRZYNIEŚ NO imie
    TO NIE SĄ TANIE RZECZY "Jan"

    CYCU PRZYNIEŚ NO wiek
    TO NIE SĄ TANIE RZECZY 25

    ALE WIE PAN JA ZASADNICZO przedstawSie
        PANIE SENSACJA REWELACJA "Cześć, jestem "
        PANIE SENSACJA REWELACJA imie
    DO WIDZENIA PANU
DO WIDZENIA PANU
```

### New Object

**Keyword**: `DZIAD ZDZIADZIAŁY JEDEN`

Create a new instance of a class.

**Syntax**:
```ferdek
DZIAD ZDZIADZIAŁY JEDEN ClassName()
DZIAD ZDZIADZIAŁY JEDEN ClassName(arg1, arg2)
```

**Example**:
```ferdek
CYCU PRZYNIEŚ NO osoba
TO NIE SĄ TANIE RZECZY DZIAD ZDZIADZIAŁY JEDEN Osoba()

CYCU PRZYNIEŚ NO osoba2
TO NIE SĄ TANIE RZECZY DZIAD ZDZIADZIAŁY JEDEN Osoba("Anna", 30)
```

---

## Null Value

**Keyword**: `W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM`

Represents a null or undefined value.

**Syntax**:
```ferdek
CYCU PRZYNIEŚ NO pusty
TO NIE SĄ TANIE RZECZY W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM
```

**Example**:
```ferdek
CYCU PRZYNIEŚ NO wynik
TO NIE SĄ TANIE RZECZY W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM

NO JAK NIE JAK TAK wynik TO PANU SIĘ CHCE WTEDY KIEDY MNIE W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM
    PANIE SENSACJA REWELACJA "Brak wyniku!"
DO CHAŁUPY ALE JUŻ
```

---

## Additional Separators

- `[` - `LBRACKET` - Left bracket for arrays
- `]` - `RBRACKET` - Right bracket for arrays

---

## Complete Example

See [examples/advanced_features.ferdek](examples/advanced_features.ferdek) for a comprehensive example using all new features.

---

## Token Summary

| Feature | Keyword | Token |
|---------|---------|-------|
| Import | O KOGO MOJE PIĘKNE OCZY WIDZĄ | IMPORT |
| Array Declaration | PANIE TO JEST PRYWATNA PUBLICZNA TABLICA | ARRAY_DECL |
| Array Access | WYPIERDZIELAJ PAN NA POZYCJĘ | ARRAY_INDEX |
| Try | HELENA MUSZĘ CI COŚ POWIEDZIEĆ | TRY |
| Catch | HELENA MAM ZAWAŁ | CATCH |
| Throw | O KARWASZ TWARZ | THROW |
| Break | A POCAŁUJCIE MNIE WSZYSCY W DUPĘ | BREAK |
| Continue | AKUKARACZA | CONTINUE |
| Class | ALE JAJA | CLASS |
| New | DZIAD ZDZIADZIAŁY JEDEN | NEW |
| Null | W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM | NULL |
| Left Bracket | [ | LBRACKET |
| Right Bracket | ] | RBRACKET |
