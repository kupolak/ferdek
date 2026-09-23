# Ferdek - słownik języka

> Wygenerowane przez `scripts/gen_keywords.py` z leksera - nie edytuj ręcznie.

Każde słowo z polskimi znakami można też napisać bez nich (np. `ZROB DLUGI` = `ZRÓB DŁUGI`).
Funkcje z sekcji SKRZYNKA, KLATKA i BABKA wymagają importu modułu, reszta jest wbudowana.
Przykładowe programy: katalog [`examples/`](../examples).

## Program

| Słowo | Znaczenie |
|---|---|
| `CO JEST KURDE` | Początek programu |
| `MOJA NOGA JUŻ TUTAJ NIE POSTANIE` | Koniec programu |
| `O KOGO MOJE PIĘKNE OCZY WIDZĄ` | Import: plik obok (moj_plik) albo moduł stdlib (KLAMOTY/SKRZYNKA) |
| `CYCU PRZYNIEŚ` | Import, krótsza forma: CYCU PRZYNIEŚ BABKA |

## Zmienne i wypisywanie

| Słowo | Znaczenie |
|---|---|
| `CYCU PRZYNIEŚ NO` | Deklaracja zmiennej: CYCU PRZYNIEŚ NO x / TO NIE SĄ TANIE RZECZY 5 |
| `TO NIE SĄ TANIE RZECZY` | Wartość początkowa w deklaracji |
| `PANIE TO JEST PRYWATNA PUBLICZNA TABLICA` | Deklaracja tablicy |
| `O KURDE MAM POMYSŁA` | Przypisanie: O KURDE MAM POMYSŁA x A PROSZĘ BARDZO 5 NO I GITARA |
| `A PROSZĘ BARDZO` | Nowa wartość w przypisaniu |
| `NO I GITARA` | Koniec przypisania |
| `PANIE SENSACJA REWELACJA` | Wypisz wartość i zakończ linię |
| `JEDZIEM Z TYM ŚLEDZIEM` | Wypisz wartość bez końca linii |
| `NO TO ENTER` | Zakończ linię |
| `CO TAM U PANA SŁYCHAĆ` | Wczytaj linię z wejścia do zmiennej |
| `WYPIERDZIELAJ PAN NA POZYCJĘ` | Element tablicy: WYPIERDZIELAJ PAN NA POZYCJĘ t[0] |

## Sterowanie

| Słowo | Znaczenie |
|---|---|
| `NO JAK NIE JAK TAK` | if |
| `AAA TO ZMIENIA POSTAĆ RZECZY` | else if |
| `A DUPA TAM` | else |
| `DO CHAŁUPY ALE JUŻ` | Koniec if / bloku catch |
| `CHLUŚNIEM BO UŚNIEM` | Pętla while |
| `KRĘCI CEMENT BETONIARA` | Pętla for: KRĘCI CEMENT BETONIARA i OD 1 DO 10 CO 2 |
| `OD` | Początek zakresu pętli for |
| `DO` | Koniec zakresu pętli for (włącznie) |
| `CO` | Krok pętli for (domyślnie 1, ujemny liczy w dół) |
| `A ROBIĆ NI MA KOMU` | Koniec pętli |
| `A POCAŁUJCIE MNIE WSZYSCY W DUPĘ` | break |
| `AKUKARACZA` | continue |
| `HELENA MUSZĘ CI COŚ POWIEDZIEĆ` | try |
| `HELENA MAM ZAWAŁ` | catch (zmienna z wyjątkiem); blok kończy DO CHAŁUPY ALE JUŻ |
| `O KARWASZ TWARZ` | Rzuć wyjątek |

## Funkcje

| Słowo | Znaczenie |
|---|---|
| `ALE WIE PAN JA ZASADNICZO` | Definicja funkcji |
| `NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ` | Funkcja zwraca wartość |
| `NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO` | Parametry funkcji (a, b albo a, ... dla zmiennej liczby) |
| `DO WIDZENIA PANU` | Koniec funkcji / klasy |
| `I JA INFORMUJĘ ŻE WYCHODZĘ` | return |
| `W MORDĘ JEŻA` | Wywołanie funkcji: W MORDĘ JEŻA f(1, 2) |
| `AFERA JEST` | Wynik funkcji do zmiennej: AFERA JEST x W MORDĘ JEŻA f() |

## Typy złożone

| Słowo | Znaczenie |
|---|---|
| `ALE JAJA` | Definicja klasy |
| `RENTA BABKI` | Dziedziczenie (extends) |
| `DZIAD ZDZIADZIAŁY JEDEN` | Nowy obiekt klasy |
| `MEBEL` | Definicja struktury |
| `KONIEC MEBLA` | Koniec struktury |
| `ZMONTUJ MEBEL` | Nowa struktura |
| `WCHODZIMY DO UNII` | Definicja unii |
| `KONIEC UNII EUROPEJSKIEJ` | Koniec unii |
| `WEJDŹ DO UNII` | Nowa unia |
| `PANIE LISTA` | Definicja enuma |
| `KONIEC LISTY` | Koniec enuma |

## Wskaźniki i fixed-point

| Słowo | Znaczenie |
|---|---|
| `PALCEM POKAZUJĘ` | Wskaźnik do wartości albo funkcja jako wartość |
| `CO TAM JEST` | Wartość spod wskaźnika |
| `GDZIE STOI` | Adres zmiennej |
| `KROK DALEJ` | Przesunięcie wskaźnika do przodu |
| `KROK WSTECZ` | Przesunięcie wskaźnika do tyłu |
| `ZAMIEŃ NA FIXED` | Liczba na fixed-point 16.16 |
| `WYJMIJ Z FIXED` | Fixed-point 16.16 na liczbę |

## Operatory

| Słowo | Znaczenie |
|---|---|
| `BABKA DAWAJ RENTĘ` | + (z tekstem skleja) |
| `PASZOŁ WON` | - |
| `ROZDUPCĘ BANK` | * |
| `MUSZĘ DO SRACZA` | / (na liczbach całkowitych dzielenie całkowite) |
| `PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ` | % (reszta z dzielenia) |
| `TO PANU SIĘ CHCE WTEDY KIEDY MNIE` | == |
| `PAN TU NIE MIESZKASZ` | != |
| `GRUBA ŚWINIA` | > |
| `ŁYSA PAŁA` | < |
| `ŚWINIA` | < |
| `JA JESTEM PONAD TO` | >= |
| `PIWO I TELEWIZOR` | and |
| `ALBO JUTRO U ADWOKATA` | or |
| `TAK BYĆ NIE BĘDZIE` | not |
| `WSZYSTKO MUSI BYĆ` | & (bitowe) |
| `COKOLWIEK MOŻE BYĆ` | \| (bitowe) |
| `TYLKO JEDNO Z TEGO` | ^ (bitowe) |
| `RUSZ SIĘ W LEWO` | << (przesunięcie bitowe) |
| `RUSZ SIĘ W PRAWO` | >> (przesunięcie bitowe) |
| `NA OPAK` | ~ (negacja bitowa) |

## Stałe

| Słowo | Znaczenie |
|---|---|
| `A ŻEBYŚ PAN WIEDZIAŁ` | true |
| `GÓWNO PRAWDA` | false |
| `W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM` | null |

## KANAPA - tekst

| Słowo | Znaczenie |
|---|---|
| `USIĄDŹ NA KANAPIE(a, b, ...)` | Sklej teksty |
| `ILE MIEJSCA NA KANAPIE(tekst)` | Długość tekstu (w bajtach) |
| `POTNIJ KANAPĘ(tekst, od, do)` | Fragment tekstu |
| `ROZCIĄGNIJ KANAPĘ(tekst, długość)` | Dopełnij spacjami do długości |
| `PRZESUŃ NA KANAPIE(tekst, separator)` | Podziel tekst na tablicę |
| `POSKŁADAJ KANAPĘ(tablica, separator)` | Sklej tablicę w tekst |
| `WYTRZEP KANAPĘ(tekst)` | Usuń białe znaki z brzegów |
| `ZAMIEŃ NA KANAPIE(tekst, stary, nowy)` | Zamień wszystkie wystąpienia |
| `ZNAK Z KANAPY(tekst, i)` | Znak na pozycji i |
| `KANAPA DO GÓRY(tekst)` | Wielkie litery (także polskie) |
| `KANAPA W DÓŁ(tekst)` | Małe litery (także polskie) |

## WERSALKA - tablice

| Słowo | Znaczenie |
|---|---|
| `ILE NA WERSALCE(tablica)` | Długość tablicy |
| `POŁÓŻ NA WERSALCE(tablica, element)` | Nowa tablica z elementem na końcu |
| `ZDEJMIJ Z WERSALKI(tablica)` | Ostatni element |
| `CZY LEŻY NA WERSALCE(tablica, element)` | Czy tablica zawiera element |
| `POSKŁADAJ WERSALKĘ(tablica)` | Posortowana kopia; z funkcją f(a, b) zwracającą <0, 0, >0 - własna kolejność |
| `ODWRÓĆ WERSALKĘ(tablica)` | Odwrócona kopia |
| `PRZERABIAJ WERSALKĘ(tablica, funkcja)` | Nowa tablica z f(x) dla każdego elementu (map) |
| `PRZEFILTRUJ WERSALKĘ(tablica, funkcja)` | Elementy, dla których f(x) jest prawdą (filter) |
| `TABLICA 2D(wiersze, kolumny)` | Tablica 2D wypełniona zerami |
| `TABLICA 3D(x, y, z)` | Tablica 3D wypełniona zerami |

## SZAFKA - mapy

| Słowo | Znaczenie |
|---|---|
| `OTWÓRZ SZAFKĘ()` | Nowa, pusta mapa |
| `WŁÓŻ DO SZAFKI(mapa, klucz, wartość)` | Zapisz wartość pod kluczem |
| `WYJMIJ Z SZAFKI(mapa, klucz)` | Wartość spod klucza (null, gdy brak) |
| `WYRZUĆ ZE SZAFKI(mapa, klucz)` | Usuń klucz |
| `CZY W SZAFCE(mapa, klucz)` | Czy klucz istnieje |
| `WSZYSTKIE SZUFLADKI(mapa)` | Posortowana tablica kluczy |
| `ILE W SZAFCE(mapa)` | Liczba kluczy |

## Typy liczbowe i losowanie

| Słowo | Znaczenie |
|---|---|
| `ZRÓB BAJCIK(x)` | Bajt 0-255 |
| `ZRÓB KRÓTKI(x)` | Liczba 16-bitowa ze znakiem |
| `ZRÓB DŁUGI(x)` | Liczba całkowita (obcina liczbę z przecinkiem, tekst zamienia na liczbę) |
| `ZRÓB UŁAMEK(x)` | Fixed-point 16.16 |
| `CO TO ZA TYP(x)` | Nazwa typu wartości |
| `KARTA LUBI DYM(min, max)` | Losowa liczba z zakresu; KARTA LUBI DYM(ziarno) ustawia ziarno |

## KIBEL - pliki

| Słowo | Znaczenie |
|---|---|
| `OTWÓRZ KIBEL(ścieżka)` | Otwórz plik do odczytu |
| `OTWÓRZ KIBEL DO ZAPISU(ścieżka)` | Otwórz plik do zapisu |
| `ZAMKNIJ KIBEL(uchwyt)` | Zamknij plik |
| `SPUŚĆ WODĘ(uchwyt, dane)` | Zapisz do pliku |
| `WYPOMPUJ(uchwyt)` | Przeczytaj cały plik |
| `CZY KIBEL ZAJĘTY(ścieżka)` | Czy plik istnieje |
| `ZRÓB KIBEL(ścieżka)` | Utwórz katalog |
| `WYWAL KIBEL(ścieżka)` | Usuń katalog |
| `CO W KIBLU(ścieżka)` | Pliki w katalogu |
| `CZY TO KIBEL(ścieżka)` | Czy to katalog |
| `PRZEKOPIUJ KIBEL(skąd, dokąd)` | Skopiuj plik |
| `PRZENIEŚ KIBEL(skąd, dokąd)` | Przenieś plik |
| `WYKOP WSZYSTKIE KIBLE(ścieżka)` | Usuń katalog z zawartością |
| `OPAKUJ W GAZETĘ(tekst)` | Zacytuj tekst jako jeden argument powłoki - używaj przy sklejaniu poleceń dla SYSTEM |

## Pamięć (alokator strefowy w stylu DOOM)

| Słowo | Znaczenie |
|---|---|
| `DAJ MI HAJS(rozmiar, tag)` | Zaalokuj blok pamięci |
| `ODDAJ WSZYSTKO(blok)` | Zwolnij blok |
| `KOMORNICZY WINDYKACJA(tag_od, tag_do)` | Zwolnij bloki o tagach z zakresu |
| `ZAPISZ DO BLOKU(blok, indeks, wartość)` | Zapisz w bloku |
| `CZYTAJ Z BLOKU(blok, indeks)` | Czytaj z bloku |
| `ROZMIAR BLOKU(blok)` | Rozmiar bloku |
| `ILE KASY LECI()` | Statystyki alokatora |
| `PISZ BAJT(blok, indeks, bajt)` | Zapisz bajt |
| `CZYTAJ BAJT(blok, indeks)` | Czytaj bajt |
| `KOPIUJ PAMIĘĆ(skąd, dokąd, rozmiar)` | Kopiuj pamięć (memcpy) |

## TELEWIZOR - framebuffer i tablice

| Słowo | Znaczenie |
|---|---|
| `WŁĄCZ TELEWIZOR(szerokość, wysokość)` | Utwórz framebuffer |
| `WYŁĄCZ TELEWIZOR(ekran)` | Usuń framebuffer |
| `ZMIEŃ KANAŁ(ekran, x, y, kolor)` | Ustaw piksel |
| `CO LECI W TELEWIZORZE(ekran, x, y)` | Odczytaj piksel |
| `STWÓRZ TABELĘ(rozmiar)` | Utwórz tablicę wyszukiwania |
| `WPISZ DO TABELI(tabela, indeks, wartość)` | Zapisz w tablicy wyszukiwania |
| `SPRAWDŹ W TABELI(tabela, indeks)` | Odczytaj z tablicy wyszukiwania |

## SKRZYNKA (import KLAMOTY/SKRZYNKA)

| Słowo | Znaczenie |
|---|---|
| `ILE W SKRZYNCE()` | SKRZYNKA: przybliżenie PI (liczba całkowita) |
| `POLICZ SKRZYNKI(liczba)` | SKRZYNKA: wartość bezwzględna |
| `ZAOKRĄGLIJ DO SKRZYNKI(liczba)` | SKRZYNKA: zaokrąglenie |
| `OTWÓRZ SKRZYNKĘ(podstawa, wykładnik)` | SKRZYNKA: potęga |
| `PODZIEL SKRZYNKI(a, b)` | SKRZYNKA: dzielenie całkowite |
| `RESZTA ZE SKRZYNKI(a, b)` | SKRZYNKA: reszta z dzielenia |
| `LOSUJ ZE SKRZYNKI(min, max)` | SKRZYNKA: losowa liczba |

## KLATKA (import KLAMOTY/KLATKA)

| Słowo | Znaczenie |
|---|---|
| `WYJDŹ NA KLATKĘ(url)` | KLATKA: HTTP GET |
| `ZAPUKAJ DO SĄSIADA(url, dane)` | KLATKA: HTTP POST |
| `KTO NA KLATCE()` | KLATKA: twój publiczny adres IP |
| `CZY SĄSIAD W DOMU(host)` | KLATKA: ping |

## BABKA - testy (import BABKA)

| Słowo | Znaczenie |
|---|---|
| `TAK JEST I KROPKA(warunek)` | BABKA: asercja prawdy |
| `GUZIK PRAWDA(warunek)` | BABKA: asercja fałszu |
| `MA BYĆ RÓWNE(oczekiwane, rzeczywiste)` | BABKA: asercja równości |
| `MOJE LEPSZE(nieoczekiwane, rzeczywiste)` | BABKA: asercja różności |
| `TEN SAM BAJZEL(a, b)` | BABKA: to samo |
| `DZIŚ GORSZY BAJZEL(a, b)` | BABKA: nie to samo |
| `ZERO(wartość)` | BABKA: asercja null |
| `PIENIĄDZE SĄ(wartość)` | BABKA: asercja nie-null |
| `JA TU RZĄDZĘ(wynik)` | BABKA: asercja wyniku operacji |
| `NIKT LEPIEJ ODE MNIE(wynik)` | BABKA: zaprzeczenie wyniku operacji |
| `WSZYSCY OBLANI(wiadomość)` | BABKA: oblej test |
| `OLEWAM TO(wiadomość)` | BABKA: pomiń test |
| `WYGRAŁAM()` | BABKA: zalicz test |
| `BABKA PODSUMUJ()` | BABKA: raport; błąd, jeśli coś oblano |
