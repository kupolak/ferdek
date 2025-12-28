{
open Parser

exception LexError of string

let unescape_string s =
  (* Simple function to handle escape sequences in strings *)
  s
}

(* Helper definitions *)
let whitespace = [' ' '\t']
let newline = '\n' | '\r' | "\r\n"
let digit = ['0'-'9']
let letter = ['a'-'z' 'A'-'Z']
let identifier_char = letter | digit | '_'

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

  (* Keywords - BABKA (testing framework) *)
  | "TAK JEST I KROPKA" { IDENTIFIER "TAK JEST I KROPKA" }
  | "MA BYĆ RÓWNE" { IDENTIFIER "MA BYĆ RÓWNE" }
  | "MA BYC ROWNE" { IDENTIFIER "MA BYC ROWNE" }
  | "TEN SAM BAJZEL" { IDENTIFIER "TEN SAM BAJZEL" }
  | "GUZIK PRAWDA" { IDENTIFIER "GUZIK PRAWDA" }
  | "MOJE LEPSZE" { IDENTIFIER "MOJE LEPSZE" }
  | "DZIŚ GORSZY BAJZEL" { IDENTIFIER "DZIŚ GORSZY BAJZEL" }
  | "DZIS GORSZY BAJZEL" { IDENTIFIER "DZIS GORSZY BAJZEL" }
  | "WSZYSCY OBLANI" { IDENTIFIER "WSZYSCY OBLANI" }
  | "OLEWAM TO" { IDENTIFIER "OLEWAM TO" }
  | "WYGRAŁAM" { IDENTIFIER "WYGRAŁAM" }
  | "WYGRALAM" { IDENTIFIER "WYGRALAM" }
  | "JA TU RZĄDZĘ" { IDENTIFIER "JA TU RZĄDZĘ" }
  | "JA TU RZADZE" { IDENTIFIER "JA TU RZADZE" }
  | "NIKT LEPIEJ ODE MNIE" { IDENTIFIER "NIKT LEPIEJ ODE MNIE" }
  | "BABKA PODSUMUJ" { IDENTIFIER "BABKA PODSUMUJ" }
  | "ZERO" { IDENTIFIER "ZERO" }
  | "PIENIĄDZE SĄ" { IDENTIFIER "PIENIĄDZE SĄ" }
  | "PIENIADZE SA" { IDENTIFIER "PIENIADZE SA" }

  (* Keywords - DECLARATIONS *)
  | "CYCU PRZYNIEŚ NO" { VAR_DECL }
  | "CYCU PRZYNES NO" { VAR_DECL }
  | "TO NIE SĄ TANIE RZECZY" { VAR_INIT }
  | "TO NIE SA TANIE RZECZY" { VAR_INIT }

  (* Keywords - STATEMENTS *)
  | "PANIE SENSACJA REWELACJA" { PRINT }
  | "CO TAM U PANA SŁYCHAĆ" { READ }
  | "O KURDE MAM POMYSŁA" { ASSIGN_START }
  | "A PROSZĘ BARDZO" { ASSIGN_OP }
  | "NO I GITARA" { ASSIGN_END }

  (* Keywords - CONDITIONALS AND LOOPS *)
  | "NO JAK NIE JAK TAK" { IF }
  | "A DUPA TAM" { ELSE }
  | "DO CHAŁUPY ALE JUŻ" { END_IF }
  | "DO CHALUPY ALE JUZ" { END_IF }
  | "CHLUŚNIEM BO UŚNIEM" { WHILE }
  | "A ROBIĆ NI MA KOMU" { END_WHILE }

  (* Keywords - FUNCTIONS *)
  | "ALE WIE PAN JA ZASADNICZO" { FUNC_DECL }
  | "NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ" { FUNC_RETURNS }
  | "NO DOBRZE ALE CO JA Z TEGO BEDE MIAL" { FUNC_RETURNS }
  | "NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO" { FUNC_PARAMS }
  | "DO WIDZENIA PANU" { FUNC_END }
  | "W MORDĘ JEŻA" { FUNC_CALL }
  | "W MORDE JEZA" { FUNC_CALL }
  | "AFERA JEST" { FUNC_CALL_ASSIGN }
  | "I JA INFORMUJĘ ŻE WYCHODZĘ" { RETURN }
  | "I JA INFORMUJE ZE WYCHODZE" { RETURN }

  (* Keywords - MODULES AND IMPORTS *)
  | "O KOGO MOJE PIĘKNE OCZY WIDZĄ" { IMPORT }
  | "O KOGO MOJE PIEKNE OCZY WIDZA" { IMPORT }
  | "CYCU PRZYNIEŚ" { IMPORT }
  | "CYCU PRZYNES" { IMPORT }

  (* Keywords - KANAPA (string functions from stdlib) *)
  | "USIĄDŹ NA KANAPIE" { IDENTIFIER "USIĄDŹ NA KANAPIE" }
  | "USIADZ NA KANAPIE" { IDENTIFIER "USIADZ NA KANAPIE" }
  | "ROZCIĄGNIJ KANAPĘ" { IDENTIFIER "ROZCIĄGNIJ KANAPĘ" }
  | "ROZCIAGNIJ KANAPE" { IDENTIFIER "ROZCIAGNIJ KANAPE" }
  | "POTNIJ KANAPĘ" { IDENTIFIER "POTNIJ KANAPĘ" }
  | "POTNIJ KANAPE" { IDENTIFIER "POTNIJ KANAPE" }
  | "PRZESUŃ NA KANAPIE" { IDENTIFIER "PRZESUŃ NA KANAPIE" }
  | "PRZESUN NA KANAPIE" { IDENTIFIER "PRZESUN NA KANAPIE" }
  | "POSKŁADAJ KANAPĘ" { IDENTIFIER "POSKŁADAJ KANAPĘ" }
  | "POSKLADAJ KANAPE" { IDENTIFIER "POSKLADAJ KANAPE" }
  | "WYTRZEP KANAPĘ" { IDENTIFIER "WYTRZEP KANAPĘ" }
  | "WYTRZEP KANAPE" { IDENTIFIER "WYTRZEP KANAPE" }
  | "ZAMIEŃ NA KANAPIE" { IDENTIFIER "ZAMIEŃ NA KANAPIE" }
  | "ZAMIEN NA KANAPIE" { IDENTIFIER "ZAMIEN NA KANAPIE" }
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

  (* Keywords - KLATKA (networking functions from stdlib) *)
  | "WYJDŹ NA KLATKĘ" { IDENTIFIER "WYJDŹ NA KLATKĘ" }
  | "WYJDZ NA KLATKE" { IDENTIFIER "WYJDZ NA KLATKE" }
  | "ZAPUKAJ DO SĄSIADA" { IDENTIFIER "ZAPUKAJ DO SĄSIADA" }
  | "ZAPUKAJ DO SASIADA" { IDENTIFIER "ZAPUKAJ DO SASIADA" }
  | "KTO NA KLATCE" { IDENTIFIER "KTO NA KLATCE" }
  | "CZY SĄSIAD W DOMU" { IDENTIFIER "CZY SĄSIAD W DOMU" }
  | "CZY SASIAD W DOMU" { IDENTIFIER "CZY SASIAD W DOMU" }

  (* Keywords - SZAFKA (hashmap/dictionary functions from stdlib) *)
  | "OTWÓRZ SZAFKĘ" { IDENTIFIER "OTWÓRZ SZAFKĘ" }
  | "OTWORZ SZAFKE" { IDENTIFIER "OTWORZ SZAFKE" }
  | "WŁÓŻ DO SZAFKI" { IDENTIFIER "WŁÓŻ DO SZAFKI" }
  | "WLOZ DO SZAFKI" { IDENTIFIER "WLOZ DO SZAFKI" }
  | "WYJMIJ Z SZAFKI" { IDENTIFIER "WYJMIJ Z SZAFKI" }
  | "WYRZUĆ ZE SZAFKI" { IDENTIFIER "WYRZUĆ ZE SZAFKI" }
  | "WYRZUC ZE SZAFKI" { IDENTIFIER "WYRZUC ZE SZAFKI" }
  | "CZY W SZAFCE" { IDENTIFIER "CZY W SZAFCE" }
  | "WSZYSTKIE SZUFLADKI" { IDENTIFIER "WSZYSTKIE SZUFLADKI" }
  | "ILE W SZAFCE" { IDENTIFIER "ILE W SZAFCE" }

  (* Keywords - WERSALKA (list/array functions from stdlib) *)
  | "ILE NA WERSALCE" { IDENTIFIER "ILE NA WERSALCE" }
  | "POŁÓŻ NA WERSALCE" { IDENTIFIER "POŁÓŻ NA WERSALCE" }
  | "POLOZ NA WERSALCE" { IDENTIFIER "POLOZ NA WERSALCE" }
  | "ZDEJMIJ Z WERSALKI" { IDENTIFIER "ZDEJMIJ Z WERSALKI" }
  | "CZY LEŻY NA WERSALCE" { IDENTIFIER "CZY LEŻY NA WERSALCE" }
  | "CZY LEZY NA WERSALCE" { IDENTIFIER "CZY LEZY NA WERSALCE" }

  (* Keywords - KIBEL extended (additional file operations) *)
  | "ZRÓB KIBEL" { IDENTIFIER "ZRÓB KIBEL" }
  | "ZROB KIBEL" { IDENTIFIER "ZROB KIBEL" }
  | "WYWAL KIBEL" { IDENTIFIER "WYWAL KIBEL" }
  | "CO W KIBLU" { IDENTIFIER "CO W KIBLU" }
  | "CZY TO KIBEL" { IDENTIFIER "CZY TO KIBEL" }
  | "PRZEKOPIUJ KIBEL" { IDENTIFIER "PRZEKOPIUJ KIBEL" }
  | "PRZENIEŚ KIBEL" { IDENTIFIER "PRZENIEŚ KIBEL" }
  | "PRZENIES KIBEL" { IDENTIFIER "PRZENIES KIBEL" }
  | "WYKOP WSZYSTKIE KIBLE" { IDENTIFIER "WYKOP WSZYSTKIE KIBLE" }

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
  | "GRUBA SWINIA" { GREATER }
  | "ŁYSA PAŁA" { LESS }
  | "LYSA PALA" { LESS }
  | "ŚWINIA" { LESS }
  | "SWINIA" { LESS }

  (* Logical operators *)
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

  (* Literals *)
  | '"' { read_string (Buffer.create 16) lexbuf }
  | digit+ as num { INTEGER (int_of_string num) }

  (* Identifiers *)
  | letter identifier_char* as id { IDENTIFIER id }

  (* End of file *)
  | eof { EOF }

  (* Unknown character *)
  | _ {
      let pos = Lexing.lexeme_start_p lexbuf in
      let char_code = Char.code (Lexing.lexeme_char lexbuf 0) in
      raise (LexError (Printf.sprintf "Unexpected character at line %d, col %d (code: 0x%02X)"
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
  | eof       { raise (LexError "Unterminated string") }
  | _ as c    { Buffer.add_char buf c; read_string buf lexbuf }
