(* Rejestr wbudowanych funkcji interpretera: nazwy (z wariantami) i liczba argumentów
   (None = zmienna). Używa go ferdek --check. Wygenerowany z eval_function_call;
   make test-check pilnuje, żeby się nie rozjechał (sprawdza wszystkie programy testowe). *)

let builtins : (string list * int option) list = [
  ["USIĄDŹ NA KANAPIE"; "USIADZ NA KANAPIE"], None;
  ["ROZCIĄGNIJ KANAPĘ"], Some 2;
  ["POTNIJ KANAPĘ"], Some 3;
  ["PRZESUŃ NA KANAPIE"], Some 2;
  ["POSKŁADAJ KANAPĘ"], Some 2;
  ["WYTRZEP KANAPĘ"], Some 1;
  ["ZAMIEŃ NA KANAPIE"], Some 3;
  ["ILE MIEJSCA NA KANAPIE"], Some 1;
  ["OTWÓRZ KIBEL"], Some 1;
  ["ZAMKNIJ KIBEL"], Some 1;
  ["SPUŚĆ WODĘ"], Some 2;
  ["WYPOMPUJ"], Some 1;
  ["CZY KIBEL ZAJĘTY"], Some 1;
  ["OTWÓRZ KIBEL DO ZAPISU"], Some 1;
  ["SYSTEM"], Some 1;
  ["OTWÓRZ SZAFKĘ"], Some 0;
  ["WŁÓŻ DO SZAFKI"], Some 3;
  ["WYJMIJ Z SZAFKI"], Some 2;
  ["WYRZUĆ ZE SZAFKI"], Some 2;
  ["CZY W SZAFCE"], Some 2;
  ["WSZYSTKIE SZUFLADKI"], Some 1;
  ["ILE W SZAFCE"], Some 1;
  ["ZRÓB KIBEL"], Some 1;
  ["WYWAL KIBEL"], Some 1;
  ["CO W KIBLU"], Some 1;
  ["CZY TO KIBEL"], Some 1;
  ["PRZEKOPIUJ KIBEL"], Some 2;
  ["PRZENIEŚ KIBEL"], Some 2;
  ["WYKOP WSZYSTKIE KIBLE"], Some 1;
  ["ILE NA WERSALCE"], Some 1;
  ["POŁÓŻ NA WERSALCE"], Some 2;
  ["ZDEJMIJ Z WERSALKI"], Some 1;
  ["CZY LEŻY NA WERSALCE"], Some 2;
  ["DAJ MI HAJS"], Some 2;
  ["ODDAJ WSZYSTKO"], Some 1;
  ["KOMORNICZY WINDYKACJA"], Some 2;
  ["ZAPISZ DO BLOKU"], Some 3;
  ["CZYTAJ Z BLOKU"], Some 2;
  ["ROZMIAR BLOKU"], Some 1;
  ["ILE KASY LECI"], Some 0;
  ["TAG_TRWALE"], Some 0;
  ["TAG_POZIOM"], Some 0;
  ["TAG_SMIECIOWE"], Some 0;
  ["WŁĄCZ TELEWIZOR"; "WLACZ TELEWIZOR"], Some 2;
  ["WYŁĄCZ TELEWIZOR"; "WYLACZ TELEWIZOR"], Some 1;
  ["ZMIEŃ KANAŁ"; "ZMIEN KANAL"], Some 4;
  ["CO LECI W TELEWIZORZE"], Some 3;
  ["STWÓRZ TABELĘ"; "STWORZ TABELE"], Some 1;
  ["WPISZ DO TABELI"], Some 3;
  ["SPRAWDŹ W TABELI"; "SPRAWDZ W TABELI"], Some 2;
  ["PISZ BAJT"], Some 3;
  ["CZYTAJ BAJT"], Some 2;
  ["KOPIUJ PAMIĘĆ"; "KOPIUJ PAMIEC"], Some 3;
  ["ZRÓB BAJCIK"; "ZROB BAJCIK"], Some 1;
  ["ZRÓB KRÓTKI"; "ZROB KROTKI"], Some 1;
  ["ZRÓB DŁUGI"; "ZROB DLUGI"], Some 1;
  ["ZRÓB UŁAMEK"; "ZROB ULAMEK"], Some 1;
  ["KARTA LUBI DYM"], None;
  ["CO TO ZA TYP"], Some 1;
  ["OTWORZ"], Some 2;
  ["ZAMKNIJ"], Some 1;
  ["CZYTAJ"], None;
  ["PISZ"], Some 2;
  ["SKOCZ"], None;
  ["POZYCJA"], Some 1;
  ["TABLICA 2D"], Some 2;
  ["TABLICA 3D"], Some 3;
  ["POLAŁA SIĘ KREW"; "POLALA SIE KREW"], None;
  ["OKNO_OTWORZ"; "OKNO OTWORZ"], Some 3;
  ["OKNO_ZAMKNIJ"; "OKNO ZAMKNIJ"], Some 0;
  ["PALETA_USTAW"; "PALETA USTAW"], Some 1;
  ["PIKSEL_MALUJ"; "PIKSEL MALUJ"], Some 3;
  ["EKRAN_ODŚWIEŹ"; "EKRAN_ODŚWIEŻ"; "EKRAN ODŚWIEŹ"; "EKRAN ODŚWIEŻ"; "EKRAN_ODSWIEZ"; "EKRAN ODSWIEZ"], Some 0;
  ["EKRAN_CZYŚĆ"; "EKRAN CZYŚĆ"; "EKRAN_CZYSĆ"; "EKRAN CZYSĆ"; "EKRAN_CZYSC"; "EKRAN CZYSC"], Some 1;
  ["BUFOR_RAMKI_POBIERZ"; "BUFOR RAMKI POBIERZ"], Some 2;
  ["ZDARZENIE_CZEKAJ"; "ZDARZENIE CZEKAJ"], Some 0;
  ["GNIAZDKO_OTWORZ"; "GNIAZDKO OTWORZ"], Some 1;
  ["GNIAZDKO_WYSLIJ"; "GNIAZDKO WYSLIJ"], Some 4;
  ["GNIAZDKO_ODBIERZ"; "GNIAZDKO ODBIERZ"], Some 2;
  ["GNIAZDKO_ZAMKNIJ"; "GNIAZDKO ZAMKNIJ"], Some 1;
]

(* Some arity dla znanej nazwy, None gdy to nie builtin *)
let find name =
  List.find_map (fun (names, arity) -> if List.mem name names then Some arity else None) builtins
