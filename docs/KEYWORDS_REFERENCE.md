# Ferdek Language Keywords Reference

Quick reference guide for all Ferdek language keywords.

## Program Structure

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| CO JEST KURDE | Halinka is sleeping | Program start |
| MOJA NOGA JUŻ TUTAJ NIE POSTANIE | Need to sleep to wake up for work | Program end |
| RYM CYM CYM | Rhyme chyme chyme | Single-line comment |

## Variables & Types

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| CYCU PRZYNIEŚ NO | Tit, bring it here | Variable declaration |
| TO NIE SĄ TANIE RZECZY | These are not cheap things | Variable initialization |
| A ŻEBYŚ PAN WIEDZIAŁ | You should know | Boolean true |
| GÓWNO PRAWDA | My tumor jumped | Boolean false |
| W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM | There's no work in this country | Null value |

## Arrays

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| PANIE TO JEST PRYWATNA PUBLICZNA TABLICA | Sir, this is a private public array | Array declaration |
| WYPIERDZIELAJ PAN NA POZYCJĘ | Get your ass to position | Array index access |

## Input/Output

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| PANIE SENSACJA REWELACJA | Sir, sensation, revelation | Print statement |
| CO TAM U PANA SŁYCHAĆ | What's up with you, sir | Read input |

## Assignment

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| O KURDE MAM POMYSŁA | Oh crap, I have an idea | Assignment start |
| A PROSZĘ BARDZO | Here you go | Assignment operator |
| NO I GITARA | And that's great | Assignment end |

## Conditionals

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| NO JAK NIE JAK TAK | Well, if not then yes | If statement |
| A DUPA TAM | And screw that | Else statement |
| DO CHAŁUPY ALE JUŻ | Rudeness in the state | End if |

## Loops

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| CHLUŚNIEM BO UŚNIEM | I'll drink or I'll sleep | While loop |
| A ROBIĆ NI MA KOMU | And there's nobody to work | End while |
| A POCAŁUJCIE MNIE WSZYSCY W DUPĘ | Everyone kiss my ass | Break |
| AKUKARACZA | Cockroach sound | Continue |

## Functions

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| ALE WIE PAN JA ZASADNICZO | But you know, basically | Function declaration |
| NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ | OK but what's in it for me | Function returns |
| NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO | I don't talk about such topics sober | Function parameters |
| DO WIDZENIA PANU | Goodbye sir | Function/class end |
| W MORDĘ JEŻA | In the hedgehog's face | Function call |
| AFERA JEST | There's a scandal | Function call with assignment |
| I JA INFORMUJĘ ŻE WYCHODZĘ | And I inform that I'm leaving | Return statement |

## Exception Handling

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| HELENA MUSZĘ CI COŚ POWIEDZIEĆ | Helena, I must tell you something | Try block |
| HELENA MAM ZAWAŁ | Helena, I'm having a heart attack | Catch block |
| O KARWASZ TWARZ | Oh, crucian carp face | Throw exception |

## Object-Oriented Programming

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| ALE JAJA | Autumn from the ass of Middle Ages | Class declaration |
| DZIAD ZDZIADZIAŁY JEDEN | One senile old man | New object instantiation |

## Modules

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| O KOGO MOJE PIĘKNE OCZY WIDZĄ | Who my beautiful eyes see | Import module |

## Arithmetic Operators

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| BABKA DAWAJ RENTĘ | How's your health | Addition (+) |
| PASZOŁ WON | I don't give a shit | Subtraction (-) |
| ROZDUPCĘ BANK | Get out | Multiplication (*) |
| MUSZĘ DO SRACZA | I need to go to the shitter | Division (/) |
| PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ | Please leave me immediately | Modulo (%) |

## Comparison Operators

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| TO PANU SIĘ CHCE WTEDY KIEDY MNIE | You want when I want | Equal (==) |
| PAN TU NIE MIESZKASZ | You don't live here | Not equal (!=) |
| MOJA NOGA JUŻ TUTAJ NIE POSTANIE | My foot won't stand here anymore | Greater than (>) |
| CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU | Why you squirming like shit in an ice hole | Less than (<) |

## Logical Operators

| Keyword | English Translation | Purpose |
|---------|-------------------|---------|
| PIWO I TELEWIZOR | Beer and TV | Logical AND |
| ALBO JUTRO U ADWOKATA | Or tomorrow at the lawyer | Logical OR |

## Separators

| Symbol | Purpose |
|--------|---------|
| ( | Left parenthesis |
| ) | Right parenthesis |
| [ | Left bracket (array) |
| ] | Right bracket (array) |
| , | Comma (separator) |

---

## Quick Examples

### Hello World
```ferdek
CO JEST KURDE
PANIE SENSACJA REWELACJA "Cześć!"
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

### Variable
```ferdek
CYCU PRZYNIEŚ NO x
TO NIE SĄ TANIE RZECZY 42
```

### Array
```ferdek
PANIE TO JEST PRYWATNA PUBLICZNA TABLICA liczby
TO NIE SĄ TANIE RZECZY [1, 2, 3]
```

### If-Else
```ferdek
NO JAK NIE JAK TAK x MOJA NOGA JUŻ TUTAJ NIE POSTANIE 0
    PANIE SENSACJA REWELACJA "Positive"
A DUPA TAM
    PANIE SENSACJA REWELACJA "Zero or negative"
DO CHAŁUPY ALE JUŻ
```

### While Loop
```ferdek
CHLUŚNIEM BO UŚNIEM i CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU 10
    PANIE SENSACJA REWELACJA i
A ROBIĆ NI MA KOMU
```

### Try-Catch
```ferdek
HELENA MUSZĘ CI COŚ POWIEDZIEĆ
    O KARWASZ TWARZ "Error!"
HELENA MAM ZAWAŁ err
    PANIE SENSACJA REWELACJA err
```

### Class
```ferdek
ALE JAJA Osoba
    CYCU PRZYNIEŚ NO imie
    TO NIE SĄ TANIE RZECZY "Jan"
DO WIDZENIA PANU
```
