# KLAMOTY - Standardowa Biblioteka Ferdeka

**KLAMOTY** to cały dobytek Ferdeka - zestaw modułów standardowej biblioteki języka Ferdek. Każdy moduł reprezentuje kawałek mebla/wyposażenia mieszkania Ferdeka, gdzie przechowuje różne funkcje i narzędzia.

## Filozofia

Ferdek trzyma swoje narzędzia w różnych miejscach mieszkania, każde ma swoje przeznaczenie:
- Zimne rzeczy w **LODÓWCE**
- Rozrywka przy **TELEWIZORZE** 
- Hydraulika w **KIBELU**
- Spokój na **WERSALCE**
- Browary w **SKRZYNCE**
- Ludzie w **KLATCE**
- Wygoda na **KANAPIE**
- Porządek w **SZAFCE**

## Składnia Importu

```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/LODÓWKA
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/TELEWIZOR
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/KIBEL
```

---

## 📦 LODÓWKA

**Przeznaczenie:** Zmienne, stałe, podstawowe typy danych

**Uzasadnienie:** Lodówka przechowuje rzeczy, jest zimna (immutable?), rzeczy w niej się nie psują

### Funkcje:

#### `ZAMROŹ(wartość)`
Tworzy stałą (immutable)
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/LODÓWKA

CYCU PRZYNIEŚ NO temperatura
TO NIE SĄ TANIE RZECZY ZAMROŹ(-18)
```

#### `ROZMROŹ(wartość)`
Konwertuje stałą na zmienną
```ferdek
CYCU PRZYNIEŚ NO temp2
TO NIE SĄ TANIE RZECZY ROZMROŹ(temperatura)
```

#### `CO W LODÓWCE()`
Zwraca listę wszystkich zmiennych w bieżącym scope
```ferdek
PANIE SENSACJA REWELACJA CO W LODÓWCE()
```

#### `WYRZUĆ Z LODÓWKI(nazwa)`
Usuwa zmienną (jeśli język będzie to wspierał)

---

## 📺 TELEWIZOR

**Przeznaczenie:** Operacje I/O, wejście/wyjście, print, input

**Uzasadnienie:** Ferdek patrzy w telewizor (output), słucha telewizora (input)

### Funkcje:

#### `PRZEŁĄCZ KANAŁ()`
Alias dla `PANIE SENSACJA REWELACJA` - standardowy print
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/TELEWIZOR

PRZEŁĄCZ KANAŁ("Teraz oglądamy TVN!")
```

#### `CO W TELEWIZORZE()`
Alias dla input/read - czyta wejście od użytkownika
```ferdek
CYCU PRZYNIEŚ NO odpowiedź
TO NIE SĄ TANIE RZECZY CO W TELEWIZORZE()
```

#### `WYŁĄCZ TELEWIZOR()`
Flush output buffer, kończy output

#### `ZWIĘKSZ GŁOŚNOŚĆ()` / `ZMNIEJSZ GŁOŚNOŚĆ()`
Kontrola poziomu verbosity logowania

---

## 🚽 KIBEL

**Przeznaczenie:** Pliki, strumienie, operacje na plikach

**Uzasadnienie:** Coś wchodzi, coś wychodzi... przepływ danych jak woda

### Funkcje:

#### `OTWÓRZ KIBEL(ścieżka)`
Otwiera plik do odczytu
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/KIBEL

CYCU PRZYNIEŚ NO plik
TO NIE SĄ TANIE RZECZY OTWÓRZ KIBEL("dane.txt")
```

#### `ZAMKNIJ KIBEL(uchwyt)`
Zamyka plik
```ferdek
ZAMKNIJ KIBEL(plik)
```

#### `SPUŚĆ WODĘ(uchwyt, dane)`
Zapisuje dane do pliku (write)
```ferdek
SPUŚĆ WODĘ(plik, "Treść do zapisania")
```

#### `WYPOMPUJ(uchwyt)`
Czyta cały plik (read)
```ferdek
CYCU PRZYNIEŚ NO zawartość
TO NIE SĄ TANIE RZECZY WYPOMPUJ(plik)
```

#### `CZY KIBEL ZAJĘTY(ścieżka)`
Sprawdza czy plik istnieje
```ferdek
JEŻELI CZY KIBEL ZAJĘTY("config.txt")
  PANIE SENSACJA REWELACJA "Plik istnieje"
NO TO ROZUMIEMY SIĘ
```

---

## 🛋️ WERSALKA

**Przeznaczenie:** Kolekcje, listy, tablice, struktury danych

**Uzasadnienie:** Na wersalce można się rozłożyć, dużo miejsca, można pomieścić wiele osób/rzeczy

### Funkcje:

#### `ROZŁÓŻ WERSALKĘ()`
Tworzy pustą listę
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/WERSALKA

CYCU PRZYNIEŚ NO browary
TO NIE SĄ TANIE RZECZY ROZŁÓŻ WERSALKĘ()
```

#### `POŁÓŻ NA WERSALCE(lista, element)`
Dodaje element do listy (append)
```ferdek
POŁÓŻ NA WERSALCE(browary, "Tyskie")
POŁÓŻ NA WERSALCE(browary, "Żywiec")
```

#### `ZDEJMIJ Z WERSALKI(lista)`
Usuwa i zwraca ostatni element (pop)
```ferdek
CYCU PRZYNIEŚ NO ostatni_browar
TO NIE SĄ TANIE RZECZY ZDEJMIJ Z WERSALKI(browary)
```

#### `ILE NA WERSALCE(lista)`
Zwraca długość listy
```ferdek
PANIE SENSACJA REWELACJA ILE NA WERSALCE(browary)
```

#### `POSKŁADAJ WERSALKĘ(lista)`
Sortuje listę
```ferdek
POSKŁADAJ WERSALKĘ(browary)
```

#### `CZY LEŻY NA WERSALCE(lista, element)`
Sprawdza czy element jest w liście
```ferdek
JEŻELI CZY LEŻY NA WERSALCE(browary, "Lech")
  PANIE SENSACJA REWELACJA "Mamy Lecha!"
NO TO ROZUMIEMY SIĘ
```

---

## 🍺 SKRZYNKA

**Przeznaczenie:** Matematyka, operacje na liczbach, funkcje matematyczne

**Uzasadnienie:** Skrzynka piwa = Ferdek liczy browary, matematyka

### Funkcje:

#### `ILE W SKRZYNCE()`
Zwraca PI (3.14159...)
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/SKRZYNKA

CYCU PRZYNIEŚ NO pi
TO NIE SĄ TANIE RZECZY ILE W SKRZYNCE()
```

#### `POLICZ SKRZYNKI(liczba)`
Wartość bezwzględna (abs)
```ferdek
CYCU PRZYNIEŚ NO dodatnia
TO NIE SĄ TANIE RZECZY POLICZ SKRZYNKI(-5)  RYM CYM CYM Zwróci 5
```

#### `ZAOKRĄGLIJ DO SKRZYNKI(liczba)`
Zaokrągla do najbliższej liczby całkowitej
```ferdek
PANIE SENSACJA REWELACJA ZAOKRĄGLIJ DO SKRZYNKI(3.7)  RYM CYM CYM 4
```

#### `OTWÓRZ SKRZYNKĘ(liczba, potęga)`
Potęgowanie (power)
```ferdek
CYCU PRZYNIEŚ NO kwadrat
TO NIE SĄ TANIE RZECZY OTWÓRZ SKRZYNKĘ(5, 2)  RYM CYM CYM 25
```

#### `PODZIEL SKRZYNKI(liczba1, liczba2)`
Dzielenie całkowite
```ferdek
PANIE SENSACJA REWELACJA PODZIEL SKRZYNKI(17, 5)  RYM CYM CYM 3
```

#### `RESZTA ZE SKRZYNKI(liczba1, liczba2)`
Reszta z dzielenia (modulo)
```ferdek
PANIE SENSACJA REWELACJA RESZTA ZE SKRZYNKI(17, 5)  RYM CYM CYM 2
```

#### `LOSUJ ZE SKRZYNKI(min, max)`
Losuje liczbę z zakresu
```ferdek
CYCU PRZYNIEŚ NO losowa
TO NIE SĄ TANIE RZECZY LOSUJ ZE SKRZYNKI(1, 20)
```

---

## 🏢 KLATKA

**Przeznaczenie:** Networking, komunikacja, HTTP, sockety

**Uzasadnienie:** W klatce schodowej wszyscy się spotykają, komunikacja między mieszkaniami

### Funkcje:

#### `WYJDŹ NA KLATKĘ(adres)`
Nawiązuje połączenie HTTP GET
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/KLATKA

CYCU PRZYNIEŚ NO odpowiedź
TO NIE SĄ TANIE RZECZY WYJDŹ NA KLATKĘ("https://api.example.com/data")
```

#### `ZAPUKAJ DO SĄSIADA(adres, dane)`
Wysyła żądanie HTTP POST
```ferdek
ZAPUKAJ DO SĄSIADA("https://api.example.com/send", "Hej sąsiad!")
```

#### `POSŁUCHAJ NA KLATCE(port)`
Uruchamia serwer TCP (nasłuchuje na porcie)
```ferdek
POSŁUCHAJ NA KLATCE(8080)
```

#### `KTO NA KLATCE()`
Zwraca własny adres IP
```ferdek
PANIE SENSACJA REWELACJA KTO NA KLATCE()
```

#### `CZY SĄSIAD W DOMU(adres)`
Sprawdza czy host jest dostępny (ping)
```ferdek
JEŻELI CZY SĄSIAD W DOMU("google.com")
  PANIE SENSACJA REWELACJA "Jest internet!"
NO TO ROZUMIEMY SIĘ
```

---

## 🛋️ KANAPA

**Przeznaczenie:** Stringi, operacje na tekście

**Uzasadnienie:** Kanapa jest miękka, elastyczna - jak stringi

### Funkcje:

#### `USIĄDŹ NA KANAPIE(tekst1, tekst2)`
Konkatenacja stringów
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/KANAPA

CYCU PRZYNIEŚ NO całość
TO NIE SĄ TANIE RZECZY USIĄDŹ NA KANAPIE("Cześć ", "Ferdek!")
```

#### `ROZCIĄGNIJ KANAPĘ(tekst, długość)`
Padduje string do określonej długości
```ferdek
PANIE SENSACJA REWELACJA ROZCIĄGNIJ KANAPĘ("test", 10)
```

#### `POTNIJ KANAPĘ(tekst, początek, koniec)`
Substring
```ferdek
CYCU PRZYNIEŚ NO kawałek
TO NIE SĄ TANIE RZECZY POTNIJ KANAPĘ("Ferdek", 0, 4)  RYM CYM CYM "Ferd"
```

#### `PRZESUŃ NA KANAPIE(tekst, separator)`
Split string
```ferdek
CYCU PRZYNIEŚ NO słowa
TO NIE SĄ TANIE RZECZY PRZESUŃ NA KANAPIE("Ferdek ma piwo", " ")
```

#### `POSKŁADAJ KANAPĘ(lista, separator)`
Join - łączy listę stringów
```ferdek
CYCU PRZYNIEŚ NO zdanie
TO NIE SĄ TANIE RZECZY POSKŁADAJ KANAPĘ(["Ferdek", "jest", "spoko"], " ")
```

#### `WYTRZEP KANAPĘ(tekst)`
Usuwa białe znaki z początku i końca (trim)
```ferdek
PANIE SENSACJA REWELACJA WYTRZEP KANAPĘ("  spacja  ")
```

#### `ZAMIEŃ NA KANAPIE(tekst, stary, nowy)`
Replace
```ferdek
CYCU PRZYNIEŚ NO nowy_tekst
TO NIE SĄ TANIE RZECZY ZAMIEŃ NA KANAPIE("Ferdek pije wodę", "wodę", "piwo")
```

#### `ILE MIEJSCA NA KANAPIE(tekst)`
Zwraca długość stringu
```ferdek
PANIE SENSACJA REWELACJA ILE MIEJSCA NA KANAPIE("Ferdek")  RYM CYM CYM 6
```

---

## 🗄️ SZAFKA

**Przeznaczenie:** Słowniki, mapy, hashmaps, key-value stores

**Uzasadnienie:** Szafka ma szufladki, każda z etykietką - jak klucze w dictionary

### Funkcje:

#### `OTWÓRZ SZAFKĘ()`
Tworzy pusty słownik
```ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/SZAFKA

CYCU PRZYNIEŚ NO ceny
TO NIE SĄ TANIE RZECZY OTWÓRZ SZAFKĘ()
```

#### `WŁÓŻ DO SZAFKI(słownik, klucz, wartość)`
Dodaje parę klucz-wartość
```ferdek
WŁÓŻ DO SZAFKI(ceny, "Tyskie", 3.50)
WŁÓŻ DO SZAFKI(ceny, "Żywiec", 3.80)
```

#### `WYJMIJ Z SZAFKI(słownik, klucz)`
Pobiera wartość dla klucza
```ferdek
CYCU PRZYNIEŚ NO cena_tyskiego
TO NIE SĄ TANIE RZECZY WYJMIJ Z SZAFKI(ceny, "Tyskie")
```

#### `WYRZUĆ ZE SZAFKI(słownik, klucz)`
Usuwa parę klucz-wartość
```ferdek
WYRZUĆ ZE SZAFKI(ceny, "Żywiec")
```

#### `CZY W SZAFCE(słownik, klucz)`
Sprawdza czy klucz istnieje
```ferdek
JEŻELI CZY W SZAFCE(ceny, "Lech")
  PANIE SENSACJA REWELACJA "Mamy Lecha w cenniku!"
NO TO ROZUMIEMY SIĘ
```

#### `WSZYSTKIE SZUFLADKI(słownik)`
Zwraca listę wszystkich kluczy
```ferdek
CYCU PRZYNIEŚ NO wszystkie_piwa
TO NIE SĄ TANIE RZECZY WSZYSTKIE SZUFLADKI(ceny)
```

#### `ILE W SZAFCE(słownik)`
Zwraca liczbę elementów w słowniku
```ferdek
PANIE SENSACJA REWELACJA ILE W SZAFCE(ceny)
```

---

## Przykład Użycia

```ferdek
CO JEST KURDE

RYM CYM CYM Importujemy potrzebne moduły
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/LODÓWKA
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/TELEWIZOR
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/SKRZYNKA
O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/KANAPA

RYM CYM CYM Tworzymy stałą
CYCU PRZYNIEŚ NO MAX PIW
TO NIE SĄ TANIE RZECZY ZAMROŹ(6)

RYM CYM CYM Losujemy liczbę piw
CYCU PRZYNIEŚ NO piwa
TO NIE SĄ TANIE RZECZY LOSUJ ZE SKRZYNKI(1, MAX PIW)

RYM CYM CYM Wyświetlamy komunikat
CYCU PRZYNIEŚ NO wiadomość
TO NIE SĄ TANIE RZECZY USIĄDŹ NA KANAPIE("Mam ", piwa)
TO NIE SĄ TANIE RZECZY USIĄDŹ NA KANAPIE(wiadomość, " piw!")

PRZEŁĄCZ KANAŁ(wiadomość)

MOJA NOGA JUŻ TUTAJ NIE POSTANIE
```

---

## Rozszerzanie KLAMOTY

W przyszłości można dodać więcej modułów:
- **BALKON** - Threading, równoległość (wyjście na zewnątrz)
- **PIWNICA** - Cache, storage, persistent data
- **GARAŻ** - Procesy, subprocess, system calls
- **ŚMIETNIK** - Garbage collection, memory management
- **KUCHNIA** - Data transformation, processing
- **ŁÓŻKO** - Sleep, delay, timing functions

---

*Wszystko co Ferdek ma, trzyma w swoich KLAMOTACH!*
