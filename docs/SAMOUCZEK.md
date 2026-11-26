# Ferdek w 15 minut

Ferdek to język programowania ułożony z cytatów ze *Świata według Kiepskich*. Działa naprawdę:
ma interpreter, kompilator do C, edytor z podpowiedziami i plac zabaw w przeglądarce.
Ten samouczek prowadzi od pierwszego programu do funkcji, tablic, dat i wyjątków.

Każdy przykład to cały program - wklej go do pliku `program.ferdek` i uruchom `ferdek program.ferdek`
(albo skompiluj: `ferdek -c program.ferdek -o program`). Pod każdym jest to, co wypisze.
Pełny słownik słów kluczowych: [JEZYK.md](JEZYK.md).

## 1. Pierwszy program

Program zaczyna się od `CO JEST KURDE`, a kończy na `MOJA NOGA JUŻ TUTAJ NIE POSTANIE`.
`PANIE SENSACJA REWELACJA` wypisuje wartość i przechodzi do nowej linii.

```ferdek
CO JEST KURDE
PANIE SENSACJA REWELACJA "Walduś, to jest język!"
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
Walduś, to jest język!
```

## 2. Zmienne i działania

Zmienną tworzy `CYCU PRZYNIEŚ NO nazwa`, a wartość daje `TO NIE SĄ TANIE RZECZY`.
Zmienia się ją zdaniem `O KURDE MAM POMYSŁA x A PROSZĘ BARDZO nowa wartość NO I GITARA`.
Działania: `BABKA DAWAJ RENTĘ` (+), `PASZOŁ WON` (-), `ROZDUPCĘ BANK` (*), `MUSZĘ DO SRACZA` (/),
`PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ` (reszta z dzielenia). `+` z tekstem skleja teksty.
`RYM CYM CYM` zaczyna komentarz.

```ferdek
CO JEST KURDE
CYCU PRZYNIEŚ NO piwa
TO NIE SĄ TANIE RZECZY 6
RYM CYM CYM Ferdek wypił dwa
O KURDE MAM POMYSŁA piwa A PROSZĘ BARDZO piwa PASZOŁ WON 2 NO I GITARA
PANIE SENSACJA REWELACJA "Zostało piw: " BABKA DAWAJ RENTĘ piwa
PANIE SENSACJA REWELACJA piwa ROZDUPCĘ BANK 2.5
PANIE SENSACJA REWELACJA 7 MUSZĘ DO SRACZA 2
PANIE SENSACJA REWELACJA 7.0 MUSZĘ DO SRACZA 2
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
Zostało piw: 4
10.0
3
3.5
```

`7 / 2` to `3` - dzielenie liczb całkowitych; z przecinkiem po którejkolwiek stronie wynik ma przecinek.

## 3. Warunki

`NO JAK NIE JAK TAK warunek` ... `DO CHAŁUPY ALE JUŻ`. Po drodze może być `AAA TO ZMIENIA POSTAĆ RZECZY`
(else if) i `A DUPA TAM` (else). Porównania: `TO PANU SIĘ CHCE WTEDY KIEDY MNIE` (=),
`PAN TU NIE MIESZKASZ` (≠), `GRUBA ŚWINIA` (>), `ŁYSA PAŁA` (<), `JA JESTEM PONAD TO` (≥);
łączenie: `PIWO I TELEWIZOR` (i), `ALBO JUTRO U ADWOKATA` (lub), `TAK BYĆ NIE BĘDZIE` (nie).
Gdy od warunku zależy tylko wartość, wystarczy jedna linia:
`NO JAK NIE JAK TAK piwa GRUBA ŚWINIA 0 A PROSZĘ BARDZO "jest" A DUPA TAM "nie ma"`.

```ferdek
CO JEST KURDE
CYCU PRZYNIEŚ NO godzina
TO NIE SĄ TANIE RZECZY 14
NO JAK NIE JAK TAK godzina ŁYSA PAŁA 12
    PANIE SENSACJA REWELACJA "Za wcześnie na piwo"
AAA TO ZMIENIA POSTAĆ RZECZY godzina ŁYSA PAŁA 18 PIWO I TELEWIZOR TAK BYĆ NIE BĘDZIE godzina TO PANU SIĘ CHCE WTEDY KIEDY MNIE 13
    PANIE SENSACJA REWELACJA "Pora na piwo"
A DUPA TAM
    PANIE SENSACJA REWELACJA "Telewizor"
DO CHAŁUPY ALE JUŻ
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
Pora na piwo
```

Kiedy wariantów jest dużo, wygodniej jest `CO TO JE`: każdy `JAK JE` wymienia pasujące wartości,
a `A JAK NIC Z TEGO` łapie resztę.

```ferdek
CO JEST KURDE
KRĘCI CEMENT BETONIARA dzien Z ["piątek", "sobota", "wtorek"]
    CO TO JE dzien
        JAK JE "sobota", "niedziela"
            PANIE SENSACJA REWELACJA dzien BABKA DAWAJ RENTĘ ": schabowy"
        JAK JE "piątek"
            PANIE SENSACJA REWELACJA dzien BABKA DAWAJ RENTĘ ": ryba"
        A JAK NIC Z TEGO
            PANIE SENSACJA REWELACJA dzien BABKA DAWAJ RENTĘ ": zupa z torebki"
    KONIEC GADANIA
A ROBIĆ NI MA KOMU
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
piątek: ryba
sobota: schabowy
wtorek: zupa z torebki
```

`CO TO JE` może też dać wartość - wtedy po `JAK JE` stoi `A PROSZĘ BARDZO` i wynik:
`CO TO JE dzien JAK JE "piątek" A PROSZĘ BARDZO "ryba" A JAK NIC Z TEGO "zupa" KONIEC GADANIA`.

## 4. Pętle

`KRĘCI CEMENT BETONIARA i OD 1 DO 5` liczy (z `CO krok` - co tyle), `KRĘCI CEMENT BETONIARA x Z kolekcja`
idzie po elementach tablicy, kluczach szafki albo znakach tekstu (`k, w Z kolekcja` - parami: klucz
i wartość szafki, numer i element tablicy), a `CHLUŚNIEM BO UŚNIEM warunek`
kręci, dopóki warunek jest prawdziwy. Każdą kończy `A ROBIĆ NI MA KOMU`.
`A POCAŁUJCIE MNIE WSZYSCY W DUPĘ` przerywa pętlę, `AKUKARACZA` przechodzi do następnego obrotu.
`JEDZIEM Z TYM ŚLEDZIEM` wypisuje bez przechodzenia do nowej linii, `NO TO ENTER` kończy linię.

```ferdek
CO JEST KURDE
KRĘCI CEMENT BETONIARA i OD 10 DO 0 CO -2
    JEDZIEM Z TYM ŚLEDZIEM i BABKA DAWAJ RENTĘ " "
A ROBIĆ NI MA KOMU
NO TO ENTER
KRĘCI CEMENT BETONIARA kto Z ["Ferdek", "Halina", "Boczek", "Paździoch"]
    NO JAK NIE JAK TAK kto TO PANU SIĘ CHCE WTEDY KIEDY MNIE "Paździoch"
        AKUKARACZA
    DO CHAŁUPY ALE JUŻ
    PANIE SENSACJA REWELACJA "Na kanapie: " BABKA DAWAJ RENTĘ kto
A ROBIĆ NI MA KOMU
CYCU PRZYNIEŚ NO kasa
TO NIE SĄ TANIE RZECZY 100
CHLUŚNIEM BO UŚNIEM kasa GRUBA ŚWINIA 0
    O KURDE MAM POMYSŁA kasa A PROSZĘ BARDZO kasa PASZOŁ WON 30 NO I GITARA
A ROBIĆ NI MA KOMU
PANIE SENSACJA REWELACJA "Po zakupach: " BABKA DAWAJ RENTĘ kasa
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
10 8 6 4 2 0 
Na kanapie: Ferdek
Na kanapie: Halina
Na kanapie: Boczek
Po zakupach: -20
```

## 5. Funkcje

Funkcję deklaruje `ALE WIE PAN JA ZASADNICZO nazwa`. `NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ` mówi,
że coś zwraca, `NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO` podaje parametry, a `DO WIDZENIA PANU` kończy.
Wynik oddaje `I JA INFORMUJĘ ŻE WYCHODZĘ`. Wywołanie to `W MORDĘ JEŻA nazwa(argumenty)`,
a `AFERA JEST x W MORDĘ JEŻA f()` wkłada wynik do zmiennej.

```ferdek
CO JEST KURDE
ALE WIE PAN JA ZASADNICZO silnia
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO n
    NO JAK NIE JAK TAK n ŁYSA PAŁA 2
        I JA INFORMUJĘ ŻE WYCHODZĘ 1
    DO CHAŁUPY ALE JUŻ
    I JA INFORMUJĘ ŻE WYCHODZĘ n ROZDUPCĘ BANK W MORDĘ JEŻA silnia(n PASZOŁ WON 1)
DO WIDZENIA PANU

AFERA JEST wynik W MORDĘ JEŻA silnia(10)
PANIE SENSACJA REWELACJA "10! = " BABKA DAWAJ RENTĘ wynik
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
10! = 3628800
```

Parametr może mieć wartość domyślną - wtedy przy wywołaniu można go pominąć. Wartość, której nie wolno
zmienić, to stała: `TO JE NA AMEN` zamiast `CYCU PRZYNIEŚ NO`.

```ferdek
CO JEST KURDE
TO JE NA AMEN cena_piwa
TO NIE SĄ TANIE RZECZY 3
ALE WIE PAN JA ZASADNICZO rachunek
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO kto, piwa TO NIE SĄ TANIE RZECZY 1
    I JA INFORMUJĘ ŻE WYCHODZĘ kto BABKA DAWAJ RENTĘ " płaci " BABKA DAWAJ RENTĘ piwa ROZDUPCĘ BANK cena_piwa
DO WIDZENIA PANU
PANIE SENSACJA REWELACJA W MORDĘ JEŻA rachunek("Ferdek")
PANIE SENSACJA REWELACJA W MORDĘ JEŻA rachunek("Boczek", 4)
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
Ferdek płaci 3
Boczek płaci 12
```

Przypisanie do stałej (`O KURDE MAM POMYSŁA cena_piwa ...`) to błąd, zgłaszany jeszcze przed uruchomieniem.

Zmienna, parametr i wynik funkcji mogą mieć typ: `TO JE LICZBA SYNEK`, `TO JE LICZBA Z PRZECINKIEM`,
`TO SĄ STRINGI`, `TO JE TAK ALBO NIE`, `TO JE WERSALKA`, `TO JE SZAFKA`, `TO JE FUNKCJA`.
Każde przypisanie jest wtedy pilnowane, `ferdek --check` wyłapie oczywiste pomyłki przed uruchomieniem,
a kompilator trzyma takie liczby jako zwykłe liczby C - szybciej.

```ferdek
CO JEST KURDE
ALE WIE PAN JA ZASADNICZO srednia
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ TO JE LICZBA Z PRZECINKIEM
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO suma TO JE LICZBA SYNEK, ile TO JE LICZBA SYNEK
    I JA INFORMUJĘ ŻE WYCHODZĘ suma MUSZĘ DO SRACZA (ile ROZDUPCĘ BANK 1.0)
DO WIDZENIA PANU
CYCU PRZYNIEŚ NO piwa TO JE LICZBA SYNEK
TO NIE SĄ TANIE RZECZY 6
PANIE SENSACJA REWELACJA W MORDĘ JEŻA srednia(piwa, 4)
HELENA MUSZĘ CI COŚ POWIEDZIEĆ
    O KURDE MAM POMYSŁA piwa A PROSZĘ BARDZO W MORDĘ JEŻA KANAPA DO GÓRY("dużo") NO I GITARA
HELENA MAM ZAWAŁ blad
    PANIE SENSACJA REWELACJA blad
DO CHAŁUPY ALE JUŻ
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
1.5
Zmienna piwa: TO JE LICZBA SYNEK, a jest tekst
```

## 6. Tablice i szafki

Tablica to `[1, 2, 3]`, element to `WYPIERDZIELAJ PAN NA POZYCJĘ t[0]` (numerowane od zera; `t[-1]` to ostatni).
Szafka to mapa: `OTWÓRZ SZAFKĘ("klucz", wartość, ...)`, `WYJMIJ Z SZAFKI`, `WŁÓŻ DO SZAFKI`,
albo krócej w nawiasach: `WYPIERDZIELAJ PAN NA POZYCJĘ s["klucz"]` i `O KURDE MAM POMYSŁA s["klucz"] A PROSZĘ BARDZO 5 NO I GITARA`.
Do tablic jest cała WERSALKA funkcji: suma, najmniejszy, sortowanie, wycinanie...

```ferdek
CO JEST KURDE
CYCU PRZYNIEŚ NO rachunki
TO NIE SĄ TANIE RZECZY [120, 45, 300, 45, 80]
PANIE SENSACJA REWELACJA "Pierwszy: " BABKA DAWAJ RENTĘ WYPIERDZIELAJ PAN NA POZYCJĘ rachunki[0]
PANIE SENSACJA REWELACJA "Razem: " BABKA DAWAJ RENTĘ W MORDĘ JEŻA ZSUMUJ WERSALKĘ(rachunki)
PANIE SENSACJA REWELACJA "Najdroższy: " BABKA DAWAJ RENTĘ W MORDĘ JEŻA NAJWIĘKSZY NA WERSALCE(rachunki)
PANIE SENSACJA REWELACJA W MORDĘ JEŻA POSKŁADAJ WERSALKĘ(W MORDĘ JEŻA BEZ POWTÓREK(rachunki))
PANIE SENSACJA REWELACJA W MORDĘ JEŻA WYTNIJ Z WERSALKI(rachunki, 1, 3)

AFERA JEST lodowka W MORDĘ JEŻA OTWÓRZ SZAFKĘ("piwo", 6, "kiełbasa", 2)
W MORDĘ JEŻA WŁÓŻ DO SZAFKI(lodowka, "ogórki", 1)
KRĘCI CEMENT BETONIARA co, ile Z lodowka
    PANIE SENSACJA REWELACJA co BABKA DAWAJ RENTĘ ": " BABKA DAWAJ RENTĘ ile
A ROBIĆ NI MA KOMU
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
Pierwszy: 120
Razem: 590
Najdroższy: 300
[45, 80, 120, 300]
[45, 300]
kiełbasa: 2
ogórki: 1
piwo: 6
```

## 7. Funkcje bez nazwy (lambdy)

`JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) wyrażenie` to funkcja bez nazwy - najlepsza do przerabiania tablic.
Dłuższa wersja ma ciało jak zwykła funkcja: `(x) NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ` ... `DO WIDZENIA PANU`.

```ferdek
CO JEST KURDE
CYCU PRZYNIEŚ NO ceny
TO NIE SĄ TANIE RZECZY [4, 12, 7, 30]
PANIE SENSACJA REWELACJA W MORDĘ JEŻA PRZERABIAJ WERSALKĘ(ceny, JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(c) c ROZDUPCĘ BANK 2)
PANIE SENSACJA REWELACJA W MORDĘ JEŻA PRZEFILTRUJ WERSALKĘ(ceny, JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(c) c GRUBA ŚWINIA 5)
PANIE SENSACJA REWELACJA W MORDĘ JEŻA ZWIŃ WERSALKĘ(ceny, 0, JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(suma, c) suma BABKA DAWAJ RENTĘ c)
CYCU PRZYNIEŚ NO opis
TO NIE SĄ TANIE RZECZY JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(c) NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
    NO JAK NIE JAK TAK c GRUBA ŚWINIA 10
        I JA INFORMUJĘ ŻE WYCHODZĘ "drogo"
    DO CHAŁUPY ALE JUŻ
    I JA INFORMUJĘ ŻE WYCHODZĘ "tanio"
DO WIDZENIA PANU
PANIE SENSACJA REWELACJA W MORDĘ JEŻA PRZERABIAJ WERSALKĘ(ceny, opis)
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
[8, 24, 14, 60]
[12, 7, 30]
53
[tanio, drogo, tanio, drogo]
```

Lambda łapie zmienne lokalne jako kopie, więc przypisanie do takiej zmiennej nie przetrwa do następnego
wywołania. Gdy lambda ma coś pamiętać, złap szafkę (albo tablicę) i zmieniaj to, co w niej leży
(`DOLEJ 1 DO x` to krótszy zapis `x = x + 1`, `ULEJ 1 Z x` odejmuje):

```ferdek
CO JEST KURDE
ALE WIE PAN JA ZASADNICZO licznik
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
    AFERA JEST stan W MORDĘ JEŻA OTWÓRZ SZAFKĘ("n", 0)
    I JA INFORMUJĘ ŻE WYCHODZĘ JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ() NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
        DOLEJ 1 DO stan["n"]
        I JA INFORMUJĘ ŻE WYCHODZĘ WYPIERDZIELAJ PAN NA POZYCJĘ stan["n"]
    DO WIDZENIA PANU
DO WIDZENIA PANU

AFERA JEST piwa W MORDĘ JEŻA licznik()
AFERA JEST flaszki W MORDĘ JEŻA licznik()
W MORDĘ JEŻA piwa()
W MORDĘ JEŻA piwa()
PANIE SENSACJA REWELACJA POWIEM PANU TAK "Piwo numer {W MORDĘ JEŻA piwa()}, flaszka numer {W MORDĘ JEŻA flaszki()}"
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
Piwo numer 3, flaszka numer 1
```

## 8. Teksty i daty

Teksty to KANAPA: długość, wycinanie, szukanie, wielkie litery - wszystko liczy polskie znaki jak należy.
Daty to teksty `RRRR-MM-DD`, a KALENDARZ umie dodawać dni i liczyć odstępy.
Zamiast sklejać kawałki przez `BABKA DAWAJ RENTĘ`, można wstawić wartości prosto w tekst:
`POWIEM PANU TAK "Mam {piwa} piw"` - w `{}` może stać dowolne wyrażenie.

```ferdek
CO JEST KURDE
CYCU PRZYNIEŚ NO tytul
TO NIE SĄ TANIE RZECZY "Świat według Kiepskich"
PANIE SENSACJA REWELACJA W MORDĘ JEŻA ILE MIEJSCA NA KANAPIE(tytul)
PANIE SENSACJA REWELACJA W MORDĘ JEŻA KANAPA DO GÓRY(tytul)
PANIE SENSACJA REWELACJA W MORDĘ JEŻA CZY SIEDZI NA KANAPIE(tytul, "Kiepskich")
PANIE SENSACJA REWELACJA W MORDĘ JEŻA POTNIJ KANAPĘ(tytul, 0, 5)
PANIE SENSACJA REWELACJA "[" BABKA DAWAJ RENTĘ W MORDĘ JEŻA ROZCIĄGNIJ Z LEWEJ(42, 6) BABKA DAWAJ RENTĘ "]"

CYCU PRZYNIEŚ NO premiera
TO NIE SĄ TANIE RZECZY "1999-03-16"
PANIE SENSACJA REWELACJA POWIEM PANU TAK "Premiera była we {W MORDĘ JEŻA DZIEŃ TYGODNIA(premiera)}"
PANIE SENSACJA REWELACJA POWIEM PANU TAK "Setny dzień serialu: {W MORDĘ JEŻA DODAJ DNI(premiera, 99)}"
PANIE SENSACJA REWELACJA W MORDĘ JEŻA ILE DNI MIĘDZY(premiera, "2000-01-01")
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
22
ŚWIAT WEDŁUG KIEPSKICH
true
Świat
[    42]
Premiera była we wtorek
Setny dzień serialu: 1999-06-23
291
```

`JAKI DZIŚ DZIEŃ()` i `KTÓRA GODZINA()` dają dzisiejszą datę i godzinę.

## 9. Wyjątki

`HELENA MUSZĘ CI COŚ POWIEDZIEĆ` ... `HELENA MAM ZAWAŁ blad` ... `DO CHAŁUPY ALE JUŻ` łapie wyjątki:
te rzucone przez `O KARWASZ TWARZ` i błędy wykonania, jak dzielenie przez zero.

```ferdek
CO JEST KURDE
ALE WIE PAN JA ZASADNICZO wyplac
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO kwota
    NO JAK NIE JAK TAK kwota GRUBA ŚWINIA 500
        O KARWASZ TWARZ "Renta nie z gumy!"
    DO CHAŁUPY ALE JUŻ
    PANIE SENSACJA REWELACJA "Wypłacono " BABKA DAWAJ RENTĘ kwota
DO WIDZENIA PANU

HELENA MUSZĘ CI COŚ POWIEDZIEĆ
    W MORDĘ JEŻA wyplac(100)
    W MORDĘ JEŻA wyplac(1000)
HELENA MAM ZAWAŁ blad
    PANIE SENSACJA REWELACJA "Babka mówi: " BABKA DAWAJ RENTĘ blad
DO CHAŁUPY ALE JUŻ

HELENA MUSZĘ CI COŚ POWIEDZIEĆ
    PANIE SENSACJA REWELACJA 1 MUSZĘ DO SRACZA 0
HELENA MAM ZAWAŁ blad
    PANIE SENSACJA REWELACJA "Złapane: " BABKA DAWAJ RENTĘ blad
DO CHAŁUPY ALE JUŻ
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
Wypłacono 100
Babka mówi: Renta nie z gumy!
Złapane: Dzielenie przez zero
```

Ostatnia część bloku, `I TAK TRZEBA POSPRZĄTAĆ`, wykona się zawsze - także gdy z bloku wychodzi się przez
`I JA INFORMUJĘ ŻE WYCHODZĘ` albo gdy w `HELENA MAM ZAWAŁ` znowu coś pęknie:

```ferdek
CO JEST KURDE
ALE WIE PAN JA ZASADNICZO do_kibla
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO kto
    HELENA MUSZĘ CI COŚ POWIEDZIEĆ
        NO JAK NIE JAK TAK kto TO PANU SIĘ CHCE WTEDY KIEDY MNIE "Paździoch"
            O KARWASZ TWARZ "zajęte"
        DO CHAŁUPY ALE JUŻ
        I JA INFORMUJĘ ŻE WYCHODZĘ kto BABKA DAWAJ RENTĘ " wszedł"
    HELENA MAM ZAWAŁ blad
        I JA INFORMUJĘ ŻE WYCHODZĘ kto BABKA DAWAJ RENTĘ ": " BABKA DAWAJ RENTĘ blad
    I TAK TRZEBA POSPRZĄTAĆ
        PANIE SENSACJA REWELACJA "(spuszczam wodę)"
    DO CHAŁUPY ALE JUŻ
DO WIDZENIA PANU
PANIE SENSACJA REWELACJA W MORDĘ JEŻA do_kibla("Ferdek")
PANIE SENSACJA REWELACJA W MORDĘ JEŻA do_kibla("Paździoch")
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
(spuszczam wodę)
Ferdek wszedł
(spuszczam wodę)
Paździoch: zajęte
```

Błąd, którego nikt nie złapie, kończy program i pokazuje linię oraz ścieżkę wywołań:

```
Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: Dzielenie przez zero (program.ferdek, linia 5)
    5 |     I JA INFORMUJĘ ŻE WYCHODZĘ a MUSZĘ DO SRACZA b
  w funkcji dziel, wywołanej w linii 8
```

## 10. Klasy

`ALE JAJA Nazwa` ... `DO WIDZENIA PANU` to klasa z polami i metodami; `DZIAD ZDZIADZIAŁY JEDEN Nazwa`
tworzy obiekt. Do pól i metod sięga się przez kropkę: `swinka.stan`, `W MORDĘ JEŻA swinka.wrzuc(20)`
(to samo co `swinka["stan"]` - kropka działa też na szafkach). Metoda o nazwie `NA DZIEŃ DOBRY` dostaje
argumenty podane przy tworzeniu obiektu; jej parametr nie może nazywać się jak pole, bo by je zasłonił.

```ferdek
CO JEST KURDE
ALE JAJA Skarbonka
    CYCU PRZYNIEŚ NO stan
    TO NIE SĄ TANIE RZECZY 0

    ALE WIE PAN JA ZASADNICZO NA DZIEŃ DOBRY
    NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO na_start
        O KURDE MAM POMYSŁA stan A PROSZĘ BARDZO na_start NO I GITARA
    DO WIDZENIA PANU

    ALE WIE PAN JA ZASADNICZO wrzuc
    NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO ile
        O KURDE MAM POMYSŁA stan A PROSZĘ BARDZO stan BABKA DAWAJ RENTĘ ile NO I GITARA
    DO WIDZENIA PANU
DO WIDZENIA PANU

CYCU PRZYNIEŚ NO swinka
TO NIE SĄ TANIE RZECZY DZIAD ZDZIADZIAŁY JEDEN Skarbonka(100)
W MORDĘ JEŻA swinka.wrzuc(20)
W MORDĘ JEŻA swinka.wrzuc(5)
PANIE SENSACJA REWELACJA POWIEM PANU TAK "W skarbonce: {swinka.stan}"
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
W skarbonce: 125
```

## 11. Moduły

`O KOGO MOJE PIĘKNE OCZY WIDZĄ moduł` dołącza plik `moduł.ferdek` leżący obok albo moduł ze stdlib
(`KLAMOTY/SKRZYNKA` i inne). Z `JAKO` nazwy modułu dostają przedrostek i nie mieszają się z Twoimi.

```ferdek
CO JEST KURDE
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/SKRZYNKA JAKO s
PANIE SENSACJA REWELACJA W MORDĘ JEŻA s.OTWÓRZ SKRZYNKĘ(2, 10)
PANIE SENSACJA REWELACJA W MORDĘ JEŻA s.WIĘKSZA ZE SKRZYNEK(3, 7)
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

Wynik:

```
1024
7
```

## Co dalej

- `ferdek nowy moj_projekt` - nowy projekt: program, moduł, test i README.
- `ferdek -c program.ferdek -o program` - kompilacja do C i gotowy plik wykonywalny (dużo szybszy).
- `ferdek --check program.ferdek` - sprawdzenie bez uruchamiania: literówki, nieznane nazwy, liczba argumentów.
- `ferdek --fmt program.ferdek` - uporządkowane wcięcia.
- `ferdek --repl` - rozmowa z Ferdkiem linia po linii.
- `ferdek --debug program.ferdek` - program krok po kroku: `k` krok, `n` następna linia, `b 12` punkt
  zatrzymania, `c` jedź dalej, `p x` wartość, `z` zmienne (`h` pokazuje wszystko).
- `ferdek test` - uruchamia pliki `*_test.ferdek` (asercje z modułu BABKA).
- Edytor: rozszerzenie do VS Code albo dowolny edytor z LSP (`ferdek --lsp`) - błędy na bieżąco,
  podpowiedzi, przejście do definicji.
- Wszystkie słowa i funkcje: [JEZYK.md](JEZYK.md).
