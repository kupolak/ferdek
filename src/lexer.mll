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

  (* Keywords - DECLARATIONS *)
  | "CYCU PRZYNIEŚ NO" { VAR_DECL }
  | "TO NIE SĄ TANIE RZECZY" { VAR_INIT }

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
  | "CHLUŚNIEM BO UŚNIEM" { WHILE }
  | "A ROBIĆ NI MA KOMU" { END_WHILE }

  (* Keywords - FUNCTIONS *)
  | "ALE WIE PAN JA ZASADNICZO" { FUNC_DECL }
  | "NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ" { FUNC_RETURNS }
  | "NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO" { FUNC_PARAMS }
  | "DO WIDZENIA PANU" { FUNC_END }
  | "W MORDĘ JEŻA" { FUNC_CALL }
  | "AFERA JEST" { FUNC_CALL_ASSIGN }
  | "I JA INFORMUJĘ ŻE WYCHODZĘ" { RETURN }

  (* Keywords - MODULES AND IMPORTS *)
  | "O KOGO MOJE PIĘKNE OCZY WIDZĄ" { IMPORT }

  (* Keywords - KANAPA (string functions from stdlib) *)
  | "USIĄDŹ NA KANAPIE" { IDENTIFIER "USIĄDŹ NA KANAPIE" }
  | "ROZCIĄGNIJ KANAPĘ" { IDENTIFIER "ROZCIĄGNIJ KANAPĘ" }
  | "POTNIJ KANAPĘ" { IDENTIFIER "POTNIJ KANAPĘ" }
  | "PRZESUŃ NA KANAPIE" { IDENTIFIER "PRZESUŃ NA KANAPIE" }
  | "POSKŁADAJ KANAPĘ" { IDENTIFIER "POSKŁADAJ KANAPĘ" }
  | "WYTRZEP KANAPĘ" { IDENTIFIER "WYTRZEP KANAPĘ" }
  | "ZAMIEŃ NA KANAPIE" { IDENTIFIER "ZAMIEŃ NA KANAPIE" }
  | "ILE MIEJSCA NA KANAPIE" { IDENTIFIER "ILE MIEJSCA NA KANAPIE" }

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
  | "DZIAD ZDZIADZIAŁY JEDEN" { NEW }

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
  | "PAN TU NIE MIESZKASZ" { NOT_EQUAL }
  | "GRUBA ŚWINIA" { GREATER }
  | "ŁYSA PAŁA" { LESS }

  (* Logical operators *)
  | "PIWO I TELEWIZOR" { AND }
  | "ALBO JUTRO U ADWOKATA" { OR }

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
  | _ as c { raise (LexError (Printf.sprintf "Unexpected character: '%c'" c)) }

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
