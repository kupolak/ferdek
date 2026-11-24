{
open Parser

exception LexError of string

let unescape_string s =
  (* Simple function to handle escape sequences in strings *)
  s

(* Ile otwartych {wyrażeń} w tekstach POWIEM PANU TAK: tylko wtedy "}" wraca do czytania tekstu.
   Zerowane na końcu pliku i przy niezamkniętym tekście, żeby błąd nie przeszedł do następnego pliku. *)
let interp_depth = ref 0

let unterminated () =
  interp_depth := 0;
  raise (LexError "Niezamknięty tekst - brakuje cudzysłowu")
}

(* Helper definitions *)
let whitespace = [' ' '\t']
let newline = '\n' | '\r' | "\r\n"
let digit = ['0'-'9']
let letter = ['a'-'z' 'A'-'Z']
let identifier_char = letter | digit | '_' | ['\128'-'\255'] (* bajty UTF-8: ą, ł, ż... *)
(* Polska litera na początku nazwy (żółw): bajt wiodący UTF-8 dla ą-ż i bajt kontynuacji *)
let utf8_letter = ['\195'-'\197'] ['\128'-'\191']

rule token = parse
  (* Whitespace *)
  | whitespace+       { token lexbuf }
  | newline           { Lexing.new_line lexbuf; token lexbuf }

  (* Comments *)
  | "RYM CYM CYM"     { line_comment lexbuf }

  (* Keywords - PROGRAM *)
  | "CO JEST KURDE"  { PROGRAM_START }
  | "MOJA NOGA JUŻ TUTAJ NIE POSTANIE" { PROGRAM_END }
  | "MOJA NOGA JUZ TUTAJ NIE POSTANIE" { PROGRAM_END }

  (* Nazwa metody startowej klasy: dostaje argumenty z DZIAD ZDZIADZIAŁY JEDEN Klasa(...) *)
  | "NA DZIEŃ DOBRY" { IDENTIFIER "NA DZIEŃ DOBRY" }
  | "NA DZIEN DOBRY" { IDENTIFIER "NA DZIEŃ DOBRY" }

  (* Keywords - BABKA (testing framework) *)
  | "TAK JEST I KROPKA" { IDENTIFIER "TAK JEST I KROPKA" }
  | "MA BYĆ RÓWNE" { IDENTIFIER "MA BYĆ RÓWNE" }
  | "MA BYC ROWNE" { IDENTIFIER "MA BYĆ RÓWNE" }
  | "TEN SAM BAJZEL" { IDENTIFIER "TEN SAM BAJZEL" }
  | "GUZIK PRAWDA" { IDENTIFIER "GUZIK PRAWDA" }
  | "MOJE LEPSZE" { IDENTIFIER "MOJE LEPSZE" }
  | "DZIŚ GORSZY BAJZEL" { IDENTIFIER "DZIŚ GORSZY BAJZEL" }
  | "DZIS GORSZY BAJZEL" { IDENTIFIER "DZIŚ GORSZY BAJZEL" }
  | "WSZYSCY OBLANI" { IDENTIFIER "WSZYSCY OBLANI" }
  | "OLEWAM TO" { IDENTIFIER "OLEWAM TO" }
  | "WYGRAŁAM" { IDENTIFIER "WYGRAŁAM" }
  | "WYGRALAM" { IDENTIFIER "WYGRAŁAM" }
  | "JA TU RZĄDZĘ" { IDENTIFIER "JA TU RZĄDZĘ" }
  | "JA TU RZADZE" { IDENTIFIER "JA TU RZĄDZĘ" }
  | "NIKT LEPIEJ ODE MNIE" { IDENTIFIER "NIKT LEPIEJ ODE MNIE" }
  | "BABKA PODSUMUJ" { IDENTIFIER "BABKA PODSUMUJ" }
  | "ZERO" { IDENTIFIER "ZERO" }
  | "PIENIĄDZE SĄ" { IDENTIFIER "PIENIĄDZE SĄ" }
  | "PIENIADZE SA" { IDENTIFIER "PIENIĄDZE SĄ" }

  (* Keywords - DECLARATIONS *)
  | "CYCU PRZYNIEŚ NO" { VAR_DECL }
  | "CYCU PRZYNES NO" { VAR_DECL }
  | "TO NIE SĄ TANIE RZECZY" { VAR_INIT }
  | "TO NIE SA TANIE RZECZY" { VAR_INIT }

  (* Keywords - STATEMENTS *)
  | "PANIE SENSACJA REWELACJA" { PRINT }
  | "JEDZIEM Z TYM ŚLEDZIEM" { PRINT_INLINE }
  | "JEDZIEM Z TYM SLEDZIEM" { PRINT_INLINE }
  | "NO TO ENTER" { PRINT_NEWLINE }
  | "CO TAM U PANA SŁYCHAĆ" { READ }
  | "O KURDE MAM POMYSŁA" { ASSIGN_START }
  (* DOLEJ 2 DO x: x = x + 2 (tekst dokleja); ULEJ 1 Z x: x = x - 1 *)
  | "DOLEJ" { INCREMENT }
  | "ULEJ" { DECREMENT }
  | "A PROSZĘ BARDZO" { ASSIGN_OP }
  | "NO I GITARA" { ASSIGN_END }

  (* Keywords - CONDITIONALS AND LOOPS *)
  | "NO JAK NIE JAK TAK" { IF }
  | "CO TO JE" { SWITCH }
  (* Typy - po nazwie zmiennej, stałej, parametru i po NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ *)
  | "TO JE LICZBA SYNEK" { TYPE Ast.TInt }
  | "TO JE LICZBA Z PRZECINKIEM" { TYPE Ast.TFloat }
  | "TO SĄ STRINGI" { TYPE Ast.TString }
  | "TO SA STRINGI" { TYPE Ast.TString }
  | "TO JE TAK ALBO NIE" { TYPE Ast.TBool }
  | "TO JE WERSALKA" { TYPE Ast.TArray }
  | "TO JE SZAFKA" { TYPE Ast.TMap }
  | "TO JE FUNKCJA" { TYPE Ast.TFunction }
  | "I TAK TRZEBA POSPRZĄTAĆ" { FINALLY }
  | "I TAK TRZEBA POSPRZATAC" { FINALLY }
  | "TO JE NA AMEN" { CONST }
  | "JAK JE" { CASE }
  | "A JAK NIC Z TEGO" { DEFAULT }
  | "KONIEC GADANIA" { END_SWITCH }
  | "A DUPA TAM" { ELSE }
  | "AAA TO ZMIENIA POSTAĆ RZECZY" { ELSE_IF }
  | "AAA TO ZMIENIA POSTAC RZECZY" { ELSE_IF }
  | "DO CHAŁUPY ALE JUŻ" { END_IF }
  | "DO CHALUPY ALE JUZ" { END_IF }
  | "CHLUŚNIEM BO UŚNIEM" { WHILE }
  | "A ROBIĆ NI MA KOMU" { END_WHILE }
  | "KRĘCI CEMENT BETONIARA" { FOR }
  | "KRECI CEMENT BETONIARA" { FOR }
  (* Zwykłe słowa pętli; dłuższe DO WIDZENIA PANU / DO CHAŁUPY / CO JEST KURDE wygrywają *)
  | "OD" { FOR_FROM }
  | "DO" { FOR_TO }
  | "CO" { FOR_STEP }
  | "Z" { FOR_IN }

  (* Keywords - FUNCTIONS *)
  | "ALE WIE PAN JA ZASADNICZO" { FUNC_DECL }
  | "NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ" { FUNC_RETURNS }
  | "NO DOBRZE ALE CO JA Z TEGO BEDE MIAL" { FUNC_RETURNS }
  | "NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO" { FUNC_PARAMS }
  | "DO WIDZENIA PANU" { FUNC_END }
  | "JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ" { LAMBDA }
  | "JAK ROBIC ZEBY SIE NIE NAROBIC" { LAMBDA }
  | "W MORDĘ JEŻA" { FUNC_CALL }
  | "W MORDE JEZA" { FUNC_CALL }
  | "AFERA JEST" { FUNC_CALL_ASSIGN }
  | "I JA INFORMUJĘ ŻE WYCHODZĘ" { RETURN }
  | "I JA INFORMUJE ZE WYCHODZE" { RETURN }

  (* Keywords - MODULES AND IMPORTS *)
  | "O KOGO MOJE PIĘKNE OCZY WIDZĄ" { IMPORT }
  | "O KOGO MOJE PIEKNE OCZY WIDZA" { IMPORT }
  | "JAKO" { IMPORT_AS }
  | "CYCU PRZYNIEŚ" { IMPORT }
  | "CYCU PRZYNES" { IMPORT }

  (* Keywords - KANAPA (string functions from stdlib) *)
  | "USIĄDŹ NA KANAPIE" { IDENTIFIER "USIĄDŹ NA KANAPIE" }
  | "USIADZ NA KANAPIE" { IDENTIFIER "USIĄDŹ NA KANAPIE" }
  | "ROZCIĄGNIJ KANAPĘ" { IDENTIFIER "ROZCIĄGNIJ KANAPĘ" }
  | "ROZCIAGNIJ KANAPE" { IDENTIFIER "ROZCIĄGNIJ KANAPĘ" }
  | "POTNIJ KANAPĘ" { IDENTIFIER "POTNIJ KANAPĘ" }
  | "POTNIJ KANAPE" { IDENTIFIER "POTNIJ KANAPĘ" }
  | "PRZESUŃ NA KANAPIE" { IDENTIFIER "PRZESUŃ NA KANAPIE" }
  | "PRZESUN NA KANAPIE" { IDENTIFIER "PRZESUŃ NA KANAPIE" }
  | "POSKŁADAJ KANAPĘ" { IDENTIFIER "POSKŁADAJ KANAPĘ" }
  | "POSKLADAJ KANAPE" { IDENTIFIER "POSKŁADAJ KANAPĘ" }
  | "WYTRZEP KANAPĘ" { IDENTIFIER "WYTRZEP KANAPĘ" }
  | "WYTRZEP KANAPE" { IDENTIFIER "WYTRZEP KANAPĘ" }
  | "ZAMIEŃ NA KANAPIE" { IDENTIFIER "ZAMIEŃ NA KANAPIE" }
  | "ZAMIEN NA KANAPIE" { IDENTIFIER "ZAMIEŃ NA KANAPIE" }
  | "ILE MIEJSCA NA KANAPIE" { IDENTIFIER "ILE MIEJSCA NA KANAPIE" }

  (* Keywords - KIBEL (file operations from stdlib) *)
  | "OTWÓRZ KIBEL" { IDENTIFIER "OTWÓRZ KIBEL" }
  | "ZAMKNIJ KIBEL" { IDENTIFIER "ZAMKNIJ KIBEL" }
  | "SPUŚĆ WODĘ" { IDENTIFIER "SPUŚĆ WODĘ" }
  | "WYPOMPUJ" { IDENTIFIER "WYPOMPUJ" }
  | "CZY KIBEL ZAJĘTY" { IDENTIFIER "CZY KIBEL ZAJĘTY" }
  | "OTWÓRZ KIBEL DO ZAPISU" { IDENTIFIER "OTWÓRZ KIBEL DO ZAPISU" }

  (* Keywords - SKRZYNKA (math functions from stdlib) *)
  | "ILE W SKRZYNCE" { IDENTIFIER "ILE W SKRZYNCE" }
  | "POLICZ SKRZYNKI" { IDENTIFIER "POLICZ SKRZYNKI" }
  | "ZAOKRĄGLIJ DO SKRZYNKI" { IDENTIFIER "ZAOKRĄGLIJ DO SKRZYNKI" }
  | "OTWÓRZ SKRZYNKĘ" { IDENTIFIER "OTWÓRZ SKRZYNKĘ" }
  | "PODZIEL SKRZYNKI" { IDENTIFIER "PODZIEL SKRZYNKI" }
  | "RESZTA ZE SKRZYNKI" { IDENTIFIER "RESZTA ZE SKRZYNKI" }
  | "LOSUJ ZE SKRZYNKI" { IDENTIFIER "LOSUJ ZE SKRZYNKI" }
  | "MNIEJSZA ZE SKRZYNEK" { IDENTIFIER "MNIEJSZA ZE SKRZYNEK" }
  | "WIĘKSZA ZE SKRZYNEK" { IDENTIFIER "WIĘKSZA ZE SKRZYNEK" }
  | "WIEKSZA ZE SKRZYNEK" { IDENTIFIER "WIĘKSZA ZE SKRZYNEK" }
  | "PIERWIASTEK ZE SKRZYNKI" { IDENTIFIER "PIERWIASTEK ZE SKRZYNKI" }
  | "SINUS ZE SKRZYNKI" { IDENTIFIER "SINUS ZE SKRZYNKI" }
  | "COSINUS ZE SKRZYNKI" { IDENTIFIER "COSINUS ZE SKRZYNKI" }
  | "TANGENS ZE SKRZYNKI" { IDENTIFIER "TANGENS ZE SKRZYNKI" }
  | "POTĘGA ZE SKRZYNKI" { IDENTIFIER "POTĘGA ZE SKRZYNKI" }
  | "POTEGA ZE SKRZYNKI" { IDENTIFIER "POTĘGA ZE SKRZYNKI" }
  | "LOGARYTM ZE SKRZYNKI" { IDENTIFIER "LOGARYTM ZE SKRZYNKI" }
  | "PODŁOGA ZE SKRZYNKI" { IDENTIFIER "PODŁOGA ZE SKRZYNKI" }
  | "PODLOGA ZE SKRZYNKI" { IDENTIFIER "PODŁOGA ZE SKRZYNKI" }
  | "SUFIT ZE SKRZYNKI" { IDENTIFIER "SUFIT ZE SKRZYNKI" }
  | "MODUŁ ZE SKRZYNKI" { IDENTIFIER "MODUŁ ZE SKRZYNKI" }
  | "MODUL ZE SKRZYNKI" { IDENTIFIER "MODUŁ ZE SKRZYNKI" }

  (* Keywords - KLATKA (networking functions from stdlib) *)
  | "WYJDŹ NA KLATKĘ" { IDENTIFIER "WYJDŹ NA KLATKĘ" }
  | "WYJDZ NA KLATKE" { IDENTIFIER "WYJDŹ NA KLATKĘ" }
  | "ZAPUKAJ DO SĄSIADA" { IDENTIFIER "ZAPUKAJ DO SĄSIADA" }
  | "ZAPUKAJ DO SASIADA" { IDENTIFIER "ZAPUKAJ DO SĄSIADA" }
  | "KTO NA KLATCE" { IDENTIFIER "KTO NA KLATCE" }
  | "CZY SĄSIAD W DOMU" { IDENTIFIER "CZY SĄSIAD W DOMU" }
  | "CZY SASIAD W DOMU" { IDENTIFIER "CZY SĄSIAD W DOMU" }

  (* Keywords - SZAFKA (hashmap/dictionary functions from stdlib) *)
  | "OTWÓRZ SZAFKĘ" { IDENTIFIER "OTWÓRZ SZAFKĘ" }
  | "OTWORZ SZAFKE" { IDENTIFIER "OTWÓRZ SZAFKĘ" }
  | "WŁÓŻ DO SZAFKI" { IDENTIFIER "WŁÓŻ DO SZAFKI" }
  | "WLOZ DO SZAFKI" { IDENTIFIER "WŁÓŻ DO SZAFKI" }
  | "WYJMIJ Z SZAFKI" { IDENTIFIER "WYJMIJ Z SZAFKI" }
  | "WYRZUĆ ZE SZAFKI" { IDENTIFIER "WYRZUĆ ZE SZAFKI" }
  | "WYRZUC ZE SZAFKI" { IDENTIFIER "WYRZUĆ ZE SZAFKI" }
  | "CZY W SZAFCE" { IDENTIFIER "CZY W SZAFCE" }
  | "WSZYSTKIE SZUFLADKI" { IDENTIFIER "WSZYSTKIE SZUFLADKI" }
  | "ILE W SZAFCE" { IDENTIFIER "ILE W SZAFCE" }

  (* Keywords - WERSALKA (list/array functions from stdlib) *)
  | "ILE NA WERSALCE" { IDENTIFIER "ILE NA WERSALCE" }
  | "POSKŁADAJ WERSALKĘ" { IDENTIFIER "POSKŁADAJ WERSALKĘ" }
  | "POSKLADAJ WERSALKE" { IDENTIFIER "POSKŁADAJ WERSALKĘ" }
  | "ODWRÓĆ WERSALKĘ" { IDENTIFIER "ODWRÓĆ WERSALKĘ" }
  | "ODWROC WERSALKE" { IDENTIFIER "ODWRÓĆ WERSALKĘ" }
  | "PRZERABIAJ WERSALKĘ" { IDENTIFIER "PRZERABIAJ WERSALKĘ" }
  | "PRZERABIAJ WERSALKE" { IDENTIFIER "PRZERABIAJ WERSALKĘ" }
  | "PRZEFILTRUJ WERSALKĘ" { IDENTIFIER "PRZEFILTRUJ WERSALKĘ" }
  | "PRZEFILTRUJ WERSALKE" { IDENTIFIER "PRZEFILTRUJ WERSALKĘ" }
  | "POŁÓŻ NA WERSALCE" { IDENTIFIER "POŁÓŻ NA WERSALCE" }
  | "POLOZ NA WERSALCE" { IDENTIFIER "POŁÓŻ NA WERSALCE" }
  | "ZDEJMIJ Z WERSALKI" { IDENTIFIER "ZDEJMIJ Z WERSALKI" }
  | "CZY LEŻY NA WERSALCE" { IDENTIFIER "CZY LEŻY NA WERSALCE" }
  | "CZY LEZY NA WERSALCE" { IDENTIFIER "CZY LEŻY NA WERSALCE" }

  (* Keywords - KIBEL extended (additional file operations) *)
  | "ZRÓB KIBEL" { IDENTIFIER "ZRÓB KIBEL" }
  | "ZROB KIBEL" { IDENTIFIER "ZRÓB KIBEL" }
  | "WYWAL KIBEL" { IDENTIFIER "WYWAL KIBEL" }
  | "CO W KIBLU" { IDENTIFIER "CO W KIBLU" }
  | "CZY TO KIBEL" { IDENTIFIER "CZY TO KIBEL" }
  | "PRZEKOPIUJ KIBEL" { IDENTIFIER "PRZEKOPIUJ KIBEL" }
  | "PRZENIEŚ KIBEL" { IDENTIFIER "PRZENIEŚ KIBEL" }
  | "PRZENIES KIBEL" { IDENTIFIER "PRZENIEŚ KIBEL" }
  | "WYKOP WSZYSTKIE KIBLE" { IDENTIFIER "WYKOP WSZYSTKIE KIBLE" }

  (* Keywords - HAJS (DOOM-style zone memory management) *)
  | "DAJ MI HAJS" { IDENTIFIER "DAJ MI HAJS" }
  | "ODDAJ WSZYSTKO" { IDENTIFIER "ODDAJ WSZYSTKO" }
  | "KOMORNICZY WINDYKACJA" { IDENTIFIER "KOMORNICZY WINDYKACJA" }
  | "ZAPISZ DO BLOKU" { IDENTIFIER "ZAPISZ DO BLOKU" }
  | "CZYTAJ Z BLOKU" { IDENTIFIER "CZYTAJ Z BLOKU" }
  | "ROZMIAR BLOKU" { IDENTIFIER "ROZMIAR BLOKU" }
  | "ILE KASY LECI" { IDENTIFIER "ILE KASY LECI" }

  (* Keywords - TELEWIZOR (framebuffer and direct memory access) *)
  | "WŁĄCZ TELEWIZOR" { IDENTIFIER "WŁĄCZ TELEWIZOR" }
  | "WLACZ TELEWIZOR" { IDENTIFIER "WŁĄCZ TELEWIZOR" }
  | "WYŁĄCZ TELEWIZOR" { IDENTIFIER "WYŁĄCZ TELEWIZOR" }
  | "WYLACZ TELEWIZOR" { IDENTIFIER "WYŁĄCZ TELEWIZOR" }
  | "ZMIEŃ KANAŁ" { IDENTIFIER "ZMIEŃ KANAŁ" }
  | "ZMIEN KANAL" { IDENTIFIER "ZMIEŃ KANAŁ" }
  | "CO LECI W TELEWIZORZE" { IDENTIFIER "CO LECI W TELEWIZORZE" }
  | "STWÓRZ TABELĘ" { IDENTIFIER "STWÓRZ TABELĘ" }
  | "STWORZ TABELE" { IDENTIFIER "STWÓRZ TABELĘ" }
  | "WPISZ DO TABELI" { IDENTIFIER "WPISZ DO TABELI" }
  | "SPRAWDŹ W TABELI" { IDENTIFIER "SPRAWDŹ W TABELI" }
  | "SPRAWDZ W TABELI" { IDENTIFIER "SPRAWDŹ W TABELI" }
  | "PISZ BAJT" { IDENTIFIER "PISZ BAJT" }
  | "CZYTAJ BAJT" { IDENTIFIER "CZYTAJ BAJT" }
  | "KOPIUJ PAMIĘĆ" { IDENTIFIER "KOPIUJ PAMIĘĆ" }
  | "KOPIUJ PAMIEC" { IDENTIFIER "KOPIUJ PAMIĘĆ" }

  (* Keywords - TYPE CASTING *)
  | "ZRÓB BAJCIK" { IDENTIFIER "ZRÓB BAJCIK" }
  | "ZROB BAJCIK" { IDENTIFIER "ZRÓB BAJCIK" }
  | "ZRÓB KRÓTKI" { IDENTIFIER "ZRÓB KRÓTKI" }
  | "ZROB KROTKI" { IDENTIFIER "ZRÓB KRÓTKI" }
  | "ZRÓB DŁUGI" { IDENTIFIER "ZRÓB DŁUGI" }
  | "ZROB DLUGI" { IDENTIFIER "ZRÓB DŁUGI" }
  | "ZRÓB UŁAMEK" { IDENTIFIER "ZRÓB UŁAMEK" }
  | "ZROB ULAMEK" { IDENTIFIER "ZRÓB UŁAMEK" }
  | "CO TO ZA TYP" { IDENTIFIER "CO TO ZA TYP" }
  | "KARTA LUBI DYM" { IDENTIFIER "KARTA LUBI DYM" }
  | "PO PIERWSZE PRIMO" { IDENTIFIER "PO PIERWSZE PRIMO" }
  (* Program i system: argumenty, zmienne środowiska, kod wyjścia *)
  | "CO PAN PRZYNIÓSŁ" { IDENTIFIER "CO PAN PRZYNIÓSŁ" }
  | "CO PAN PRZYNIOSL" { IDENTIFIER "CO PAN PRZYNIÓSŁ" }
  | "CO MÓWI SĄSIAD" { IDENTIFIER "CO MÓWI SĄSIAD" }
  | "CO MOWI SASIAD" { IDENTIFIER "CO MÓWI SĄSIAD" }
  | "ZAMYKAM INTERES" { IDENTIFIER "ZAMYKAM INTERES" }
  | "NASTĘPNA LINIJKA" { IDENTIFIER "NASTĘPNA LINIJKA" }
  | "NASTEPNA LINIJKA" { IDENTIFIER "NASTĘPNA LINIJKA" }
  | "CAŁE WEJŚCIE" { IDENTIFIER "CAŁE WEJŚCIE" }
  | "CALE WEJSCIE" { IDENTIFIER "CAŁE WEJŚCIE" }
  | "ZAPAKUJ DO SŁOIKA" { IDENTIFIER "ZAPAKUJ DO SŁOIKA" }
  | "ZAPAKUJ DO SLOIKA" { IDENTIFIER "ZAPAKUJ DO SŁOIKA" }
  | "WYJMIJ ZE SŁOIKA" { IDENTIFIER "WYJMIJ ZE SŁOIKA" }
  | "WYJMIJ ZE SLOIKA" { IDENTIFIER "WYJMIJ ZE SŁOIKA" }
  (* Biblioteka 2.0: tablice, teksty, szafki, kalendarz *)
  | "WYTNIJ Z WERSALKI" { IDENTIFIER "WYTNIJ Z WERSALKI" }
  | "GDZIE LEŻY NA WERSALCE" { IDENTIFIER "GDZIE LEŻY NA WERSALCE" }
  | "GDZIE LEZY NA WERSALCE" { IDENTIFIER "GDZIE LEŻY NA WERSALCE" }
  | "ZESTAW WERSALKI" { IDENTIFIER "ZESTAW WERSALKI" }
  | "ZSUMUJ WERSALKĘ" { IDENTIFIER "ZSUMUJ WERSALKĘ" }
  | "ZSUMUJ WERSALKE" { IDENTIFIER "ZSUMUJ WERSALKĘ" }
  | "NAJMNIEJSZY NA WERSALCE" { IDENTIFIER "NAJMNIEJSZY NA WERSALCE" }
  | "NAJWIĘKSZY NA WERSALCE" { IDENTIFIER "NAJWIĘKSZY NA WERSALCE" }
  | "NAJWIEKSZY NA WERSALCE" { IDENTIFIER "NAJWIĘKSZY NA WERSALCE" }
  | "ZWIŃ WERSALKĘ" { IDENTIFIER "ZWIŃ WERSALKĘ" }
  | "ZWIN WERSALKE" { IDENTIFIER "ZWIŃ WERSALKĘ" }
  | "BEZ POWTÓREK" { IDENTIFIER "BEZ POWTÓREK" }
  | "BEZ POWTOREK" { IDENTIFIER "BEZ POWTÓREK" }
  | "ZRÓB KOLEJKĘ" { IDENTIFIER "ZRÓB KOLEJKĘ" }
  | "ZROB KOLEJKE" { IDENTIFIER "ZRÓB KOLEJKĘ" }
  | "WYLOSUJ Z WERSALKI" { IDENTIFIER "WYLOSUJ Z WERSALKI" }
  | "POWTÓRZ NA KANAPIE" { IDENTIFIER "POWTÓRZ NA KANAPIE" }
  | "POWTORZ NA KANAPIE" { IDENTIFIER "POWTÓRZ NA KANAPIE" }
  | "CZY SIEDZI NA KANAPIE" { IDENTIFIER "CZY SIEDZI NA KANAPIE" }
  | "GDZIE SIEDZI NA KANAPIE" { IDENTIFIER "GDZIE SIEDZI NA KANAPIE" }
  | "ZACZYNA SIĘ OD" { IDENTIFIER "ZACZYNA SIĘ OD" }
  | "ZACZYNA SIE OD" { IDENTIFIER "ZACZYNA SIĘ OD" }
  | "KOŃCZY SIĘ NA" { IDENTIFIER "KOŃCZY SIĘ NA" }
  | "KONCZY SIE NA" { IDENTIFIER "KOŃCZY SIĘ NA" }
  | "ODWRÓĆ KANAPĘ" { IDENTIFIER "ODWRÓĆ KANAPĘ" }
  | "ODWROC KANAPE" { IDENTIFIER "ODWRÓĆ KANAPĘ" }
  | "ROZCIĄGNIJ Z LEWEJ" { IDENTIFIER "ROZCIĄGNIJ Z LEWEJ" }
  | "ROZCIAGNIJ Z LEWEJ" { IDENTIFIER "ROZCIĄGNIJ Z LEWEJ" }
  | "WSZYSTKIE RZECZY" { IDENTIFIER "WSZYSTKIE RZECZY" }
  | "DOŁÓŻ SZAFKĘ" { IDENTIFIER "DOŁÓŻ SZAFKĘ" }
  | "DOLOZ SZAFKE" { IDENTIFIER "DOŁÓŻ SZAFKĘ" }
  | "JAKI DZIŚ DZIEŃ" { IDENTIFIER "JAKI DZIŚ DZIEŃ" }
  | "JAKI DZIS DZIEN" { IDENTIFIER "JAKI DZIŚ DZIEŃ" }
  | "KTÓRA GODZINA" { IDENTIFIER "KTÓRA GODZINA" }
  | "KTORA GODZINA" { IDENTIFIER "KTÓRA GODZINA" }
  | "DZIEŃ TYGODNIA" { IDENTIFIER "DZIEŃ TYGODNIA" }
  | "DZIEN TYGODNIA" { IDENTIFIER "DZIEŃ TYGODNIA" }
  | "DODAJ DNI" { IDENTIFIER "DODAJ DNI" }
  | "ILE DNI MIĘDZY" { IDENTIFIER "ILE DNI MIĘDZY" }
  | "ILE DNI MIEDZY" { IDENTIFIER "ILE DNI MIĘDZY" }
  | "POLAŁA SIĘ KREW" { IDENTIFIER "POLAŁA SIĘ KREW" }
  | "POLALA SIE KREW" { IDENTIFIER "POLAŁA SIĘ KREW" }
  | "TRZEBA SPAĆ" { IDENTIFIER "TRZEBA SPAĆ" }
  | "TRZEBA SPAC" { IDENTIFIER "TRZEBA SPAĆ" }
  | "JEST TRZECIA W NOCY" { IDENTIFIER "JEST TRZECIA W NOCY" }
  | "OPAKUJ W GAZETĘ" { IDENTIFIER "OPAKUJ W GAZETĘ" }
  | "OPAKUJ W GAZETE" { IDENTIFIER "OPAKUJ W GAZETĘ" }
  | "ZNAK Z KANAPY" { IDENTIFIER "ZNAK Z KANAPY" }
  | "CZY KANAPA PASUJE" { IDENTIFIER "CZY KANAPA PASUJE" }
  | "ZNAJDŹ NA KANAPIE" { IDENTIFIER "ZNAJDŹ NA KANAPIE" }
  | "ZNAJDZ NA KANAPIE" { IDENTIFIER "ZNAJDŹ NA KANAPIE" }
  | "ZNAJDŹ WSZYSTKO NA KANAPIE" { IDENTIFIER "ZNAJDŹ WSZYSTKO NA KANAPIE" }
  | "ZNAJDZ WSZYSTKO NA KANAPIE" { IDENTIFIER "ZNAJDŹ WSZYSTKO NA KANAPIE" }
  | "PODMIEŃ NA KANAPIE" { IDENTIFIER "PODMIEŃ NA KANAPIE" }
  | "PODMIEN NA KANAPIE" { IDENTIFIER "PODMIEŃ NA KANAPIE" }
  | "KANAPA DO GÓRY" { IDENTIFIER "KANAPA DO GÓRY" }
  | "KANAPA DO GORY" { IDENTIFIER "KANAPA DO GÓRY" }
  | "KANAPA W DÓŁ" { IDENTIFIER "KANAPA W DÓŁ" }
  | "KANAPA W DOL" { IDENTIFIER "KANAPA W DÓŁ" }

  (* Separators for modules *)
  | '/' { SLASH }

  (* Keywords - ARRAYS *)
  | "PANIE TO JEST PRYWATNA PUBLICZNA TABLICA" { ARRAY_DECL }
  | "WYPIERDZIELAJ PAN NA POZYCJĘ" { ARRAY_INDEX }

  (* Keywords - EXCEPTION HANDLING *)
  | "HELENA MUSZĘ CI COŚ POWIEDZIEĆ" { TRY }
  | "HELENA MAM ZAWAŁ" { CATCH }
  | "O KARWASZ TWARZ" { THROW }

  (* Keywords - CONTROL FLOW *)
  | "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ" { BREAK }
  | "AKUKARACZA" { CONTINUE }

  (* Keywords - OOP *)
  | "ALE JAJA" { CLASS }
  | "RENTA BABKI" { EXTENDS }
  | "DZIAD ZDZIADZIAŁY JEDEN" { NEW }

  (* Keywords - STRUCTS *)
  | "MEBEL" { STRUCT }
  | "KONIEC MEBLA" { END_STRUCT }
  | "ZMONTUJ MEBEL" { NEW_STRUCT }

  (* Keywords - UNIONS *)
  | "WCHODZIMY DO UNII" { UNION }
  | "KONIEC UNII EUROPEJSKIEJ" { END_UNION }
  | "WEJDŹ DO UNII" { NEW_UNION }
  | "WEJDZ DO UNII" { NEW_UNION }

  (* Keywords - ENUMS *)
  | "PANIE LISTA" { ENUM }
  | "KONIEC LISTY" { END_ENUM }

  (* Keywords - MULTIDIMENSIONAL ARRAYS *)
  | "TABLICA 2D" { IDENTIFIER "TABLICA 2D" }
  | "TABLICA 3D" { IDENTIFIER "TABLICA 3D" }

  (* Keywords - POINTERS *)
  | "PALCEM POKAZUJĘ" { POINTER_REF }
  | "PALCEM POKAZUJE" { POINTER_REF }
  | "CO TAM JEST" { POINTER_DEREF }
  | "GDZIE STOI" { POINTER_ADDR }
  | "KROK DALEJ" { POINTER_STEP_FORWARD }
  | "KROK WSTECZ" { POINTER_STEP_BACK }

  (* Keywords - NULL *)
  | "W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM" { NULL }

  (* Arithmetic operators *)
  | "BABKA DAWAJ RENTĘ" { PLUS }
  | "PASZOŁ WON" { MINUS }
  | "ROZDUPCĘ BANK" { MULTIPLY }
  | "MUSZĘ DO SRACZA" { DIVIDE }
  | "PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ" { MODULO }

  (* Comparison operators *)
  | "TO PANU SIĘ CHCE WTEDY KIEDY MNIE" { EQUAL }
  | "TO PANU SIE CHCE WTEDY KIEDY MNIE" { EQUAL }
  | "PAN TU NIE MIESZKASZ" { NOT_EQUAL }
  | "GRUBA ŚWINIA" { GREATER }
  | "JA JESTEM PONAD TO" { GREATER_EQUAL }
  | "GRUBA SWINIA" { GREATER }
  | "ŁYSA PAŁA" { LESS }
  | "LYSA PALA" { LESS }
  | "ŚWINIA" { LESS }
  | "SWINIA" { LESS }

  (* Logical operators *)
  | "TAK BYĆ NIE BĘDZIE" { NOT }
  | "TAK BYC NIE BEDZIE" { NOT }
  | "PIWO I TELEWIZOR" { AND }
  | "ALBO JUTRO U ADWOKATA" { OR }

  (* Bitwise operators *)
  | "RUSZ SIĘ W LEWO" { BIT_SHIFT_LEFT }
  | "RUSZ SIE W LEWO" { BIT_SHIFT_LEFT }
  | "RUSZ SIĘ W PRAWO" { BIT_SHIFT_RIGHT }
  | "RUSZ SIE W PRAWO" { BIT_SHIFT_RIGHT }
  | "WSZYSTKO MUSI BYĆ" { BIT_AND }
  | "WSZYSTKO MUSI BYC" { BIT_AND }
  | "COKOLWIEK MOŻE BYĆ" { BIT_OR }
  | "COKOLWIEK MOZE BYC" { BIT_OR }
  | "TYLKO JEDNO Z TEGO" { BIT_XOR }
  | "NA OPAK" { BIT_NOT }

  (* Fixed-point arithmetic *)
  | "ZAMIEŃ NA FIXED" { TO_FIXED }
  | "ZAMIEN NA FIXED" { TO_FIXED }
  | "WYJMIJ Z FIXED" { FROM_FIXED }

  (* Boolean values *)
  | "A ŻEBYŚ PAN WIEDZIAŁ" { TRUE }
  | "GÓWNO PRAWDA" { FALSE }

  (* Separators *)
  | '(' { LPAREN }
  | ')' { RPAREN }
  | '[' { LBRACKET }
  | ']' { RBRACKET }
  | ',' { COMMA }
  | "..." { ELLIPSIS }

  (* Tekst z wstawkami: POWIEM PANU TAK "Piwa: {piwa}, razem {a} i {b}". Tokeny: INTERP_HEAD (tekst
     przed pierwszym "{"), wyrażenie, INTERP_PART (tekst między "}" a "{"), wyrażenie, ..., INTERP_END
     (tekst od "}" do zamykającego cudzysłowu). Bez wstawek to zwykły STRING. *)
  | "POWIEM PANU TAK" {
      let start = lexbuf.lex_start_p in
      let tok = interp_start lexbuf in
      lexbuf.lex_start_p <- start;
      tok }
  | '}' {
      if !interp_depth = 0 then
        raise (LexError (Printf.sprintf "Nieoczekiwany znak '}' w linii %d - nie ma otwartej wstawki {...}"
          lexbuf.lex_start_p.pos_lnum));
      decr interp_depth;
      let start = lexbuf.lex_start_p in
      let tok = read_interp false (Buffer.create 16) lexbuf in
      lexbuf.lex_start_p <- start;
      tok }

  (* Literals *)
  | '"' {
      (* Początek tokena = otwierający cudzysłów (read_string przesuwa lex_start_p na zamykający) *)
      let start = lexbuf.lex_start_p in
      let tok = read_string (Buffer.create 16) lexbuf in
      lexbuf.lex_start_p <- start;
      tok }
  | (digit+ '.' digit+) as f { FLOAT (float_of_string f) }
  | '-' ((digit+ '.' digit+) as f) { FLOAT (-. (float_of_string f)) }
  | digit+ as num { INTEGER (int_of_string num) }
  (* ponytail: minus tylko jako literał ujemny; odejmowanie to PASZOŁ WON *)
  | '-' (digit+ as num) { INTEGER (- (int_of_string num)) }

  (* Identifiers *)
  (* m.nazwa - nazwa z modułu zaimportowanego JAKO m. Po kropce czytamy cały następny token, więc
     działa też nazwa wielowyrazowa: s.OTWÓRZ SKRZYNKĘ *)
  | (letter | utf8_letter) identifier_char* as alias '.' {
      let start = lexbuf.lex_start_p in
      match token lexbuf with
      | IDENTIFIER name -> lexbuf.lex_start_p <- start; IDENTIFIER (alias ^ "." ^ name)
      | _ -> raise (LexError (Printf.sprintf "Po '%s.' musi być nazwa (linia %d)" alias start.pos_lnum))
    }
  | (letter | utf8_letter) identifier_char* as id { IDENTIFIER id }

  (* End of file *)
  | eof { interp_depth := 0; EOF }

  (* Unknown character *)
  | _ {
      let pos = Lexing.lexeme_start_p lexbuf in
      let char_code = Char.code (Lexing.lexeme_char lexbuf 0) in
      raise (LexError (Printf.sprintf "Nieznany znak w linii %d, kolumna %d (kod: 0x%02X)"
        pos.pos_lnum (pos.pos_cnum - pos.pos_bol + 1) char_code))
    }

(* Single-line comment handling *)
and line_comment = parse
  | newline { Lexing.new_line lexbuf; token lexbuf }
  | eof     { EOF }
  | _       { line_comment lexbuf }

(* String handling *)
and read_string buf = parse
  | '"'       { STRING (Buffer.contents buf) }
  | '\\' 'n'  { Buffer.add_char buf '\n'; read_string buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; read_string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_string buf lexbuf }
  | '\\' '"'  { Buffer.add_char buf '"'; read_string buf lexbuf }
  | newline   { Lexing.new_line lexbuf;
                Buffer.add_char buf '\n';
                read_string buf lexbuf }
  | eof       { unterminated () }
  | _ as c    { Buffer.add_char buf c; read_string buf lexbuf }

and interp_start = parse
  | whitespace* '"' { read_interp true (Buffer.create 16) lexbuf }
  | ""              { raise (LexError (Printf.sprintf "Po POWIEM PANU TAK musi być tekst w cudzysłowie (linia %d)"
                        lexbuf.lex_start_p.pos_lnum)) }

(* Jak read_string, ale "{" zaczyna wstawkę; zwykły nawias klamrowy to \{.
   first: kawałek zaraz po POWIEM PANU TAK (a nie po "}") *)
and read_interp first buf = parse
  | '"'       { let s = Buffer.contents buf in if first then STRING s else INTERP_END s }
  | '{'       { incr interp_depth;
                let s = Buffer.contents buf in if first then INTERP_HEAD s else INTERP_PART s }
  | '\\' '{'  { Buffer.add_char buf '{'; read_interp first buf lexbuf }
  | '\\' 'n'  { Buffer.add_char buf '\n'; read_interp first buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; read_interp first buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_interp first buf lexbuf }
  | '\\' '"'  { Buffer.add_char buf '"'; read_interp first buf lexbuf }
  | newline   { Lexing.new_line lexbuf;
                Buffer.add_char buf '\n';
                read_interp first buf lexbuf }
  | eof       { unterminated () }
  | _ as c    { Buffer.add_char buf c; read_interp first buf lexbuf }
