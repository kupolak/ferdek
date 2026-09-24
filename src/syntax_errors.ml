(* Podpowiedzi do błędów składni: które tokeny parser przyjąłby w miejscu błędu.
   Parser w trybie --table; po błędzie przechodzimy tekst jeszcze raz krokowo
   i pytamy ostatni stan "czekam na token", co by zaakceptował. *)

module I = Parser.MenhirInterpreter

(* Token -> jak go napisać (pierwsza pisownia z leksera). Wygenerowane z parser.mly/lexer.mll. *)
let keywords = [
  Parser.PROGRAM_START, "CO JEST KURDE";
  Parser.PROGRAM_END, "MOJA NOGA JUŻ TUTAJ NIE POSTANIE";
  Parser.VAR_DECL, "CYCU PRZYNIEŚ NO";
  Parser.VAR_INIT, "TO NIE SĄ TANIE RZECZY";
  Parser.PRINT, "PANIE SENSACJA REWELACJA";
  Parser.PRINT_INLINE, "JEDZIEM Z TYM ŚLEDZIEM";
  Parser.PRINT_NEWLINE, "NO TO ENTER";
  Parser.READ, "CO TAM U PANA SŁYCHAĆ";
  Parser.ASSIGN_START, "O KURDE MAM POMYSŁA";
  Parser.ASSIGN_OP, "A PROSZĘ BARDZO";
  Parser.ASSIGN_END, "NO I GITARA";
  Parser.IF, "NO JAK NIE JAK TAK";
  Parser.ELSE, "A DUPA TAM";
  Parser.ELSE_IF, "AAA TO ZMIENIA POSTAĆ RZECZY";
  Parser.END_IF, "DO CHAŁUPY ALE JUŻ";
  Parser.WHILE, "CHLUŚNIEM BO UŚNIEM";
  Parser.END_WHILE, "A ROBIĆ NI MA KOMU";
  Parser.FOR, "KRĘCI CEMENT BETONIARA";
  Parser.FOR_FROM, "OD";
  Parser.FOR_TO, "DO";
  Parser.FOR_STEP, "CO";
  Parser.FOR_IN, "Z";
  Parser.SWITCH, "CO TO JE";
  Parser.CASE, "JAK JE";
  Parser.DEFAULT, "A JAK NIC Z TEGO";
  Parser.END_SWITCH, "KONIEC GADANIA";
  Parser.FUNC_DECL, "ALE WIE PAN JA ZASADNICZO";
  Parser.FUNC_RETURNS, "NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ";
  Parser.FUNC_PARAMS, "NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO";
  Parser.FUNC_END, "DO WIDZENIA PANU";
  Parser.ELLIPSIS, "...";
  Parser.FUNC_CALL, "W MORDĘ JEŻA";
  Parser.LAMBDA, "JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ";
  Parser.FUNC_CALL_ASSIGN, "AFERA JEST";
  Parser.RETURN, "I JA INFORMUJĘ ŻE WYCHODZĘ";
  Parser.PLUS, "BABKA DAWAJ RENTĘ";
  Parser.MINUS, "PASZOŁ WON";
  Parser.MULTIPLY, "ROZDUPCĘ BANK";
  Parser.DIVIDE, "MUSZĘ DO SRACZA";
  Parser.MODULO, "PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ";
  Parser.EQUAL, "TO PANU SIĘ CHCE WTEDY KIEDY MNIE";
  Parser.NOT_EQUAL, "PAN TU NIE MIESZKASZ";
  Parser.GREATER, "GRUBA ŚWINIA";
  Parser.LESS, "ŁYSA PAŁA";
  Parser.GREATER_EQUAL, "JA JESTEM PONAD TO";
  Parser.AND, "PIWO I TELEWIZOR";
  Parser.OR, "ALBO JUTRO U ADWOKATA";
  Parser.NOT, "TAK BYĆ NIE BĘDZIE";
  Parser.BIT_AND, "WSZYSTKO MUSI BYĆ";
  Parser.BIT_OR, "COKOLWIEK MOŻE BYĆ";
  Parser.BIT_XOR, "TYLKO JEDNO Z TEGO";
  Parser.BIT_SHIFT_LEFT, "RUSZ SIĘ W LEWO";
  Parser.BIT_SHIFT_RIGHT, "RUSZ SIĘ W PRAWO";
  Parser.BIT_NOT, "NA OPAK";
  Parser.TO_FIXED, "ZAMIEŃ NA FIXED";
  Parser.FROM_FIXED, "WYJMIJ Z FIXED";
  Parser.TRUE, "A ŻEBYŚ PAN WIEDZIAŁ";
  Parser.FALSE, "GÓWNO PRAWDA";
  Parser.LPAREN, "(";
  Parser.RPAREN, ")";
  Parser.COMMA, ",";
  Parser.IMPORT, "O KOGO MOJE PIĘKNE OCZY WIDZĄ";
  Parser.IMPORT_AS, "JAKO";
  Parser.SLASH, "/";
  Parser.ARRAY_DECL, "PANIE TO JEST PRYWATNA PUBLICZNA TABLICA";
  Parser.ARRAY_INDEX, "WYPIERDZIELAJ PAN NA POZYCJĘ";
  Parser.TRY, "HELENA MUSZĘ CI COŚ POWIEDZIEĆ";
  Parser.CATCH, "HELENA MAM ZAWAŁ";
  Parser.THROW, "O KARWASZ TWARZ";
  Parser.NULL, "W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM";
  Parser.BREAK, "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ";
  Parser.CONTINUE, "AKUKARACZA";
  Parser.CLASS, "ALE JAJA";
  Parser.EXTENDS, "RENTA BABKI";
  Parser.NEW, "DZIAD ZDZIADZIAŁY JEDEN";
  Parser.STRUCT, "MEBEL";
  Parser.END_STRUCT, "KONIEC MEBLA";
  Parser.NEW_STRUCT, "ZMONTUJ MEBEL";
  Parser.UNION, "WCHODZIMY DO UNII";
  Parser.END_UNION, "KONIEC UNII EUROPEJSKIEJ";
  Parser.NEW_UNION, "WEJDŹ DO UNII";
  Parser.ENUM, "PANIE LISTA";
  Parser.END_ENUM, "KONIEC LISTY";
  Parser.POINTER_REF, "PALCEM POKAZUJĘ";
  Parser.POINTER_DEREF, "CO TAM JEST";
  Parser.POINTER_ADDR, "GDZIE STOI";
  Parser.POINTER_STEP_FORWARD, "KROK DALEJ";
  Parser.POINTER_STEP_BACK, "KROK WSTECZ";
  Parser.LBRACKET, "[";
  Parser.RBRACKET, "]";
  Parser.EOF, "koniec pliku";
  Parser.IDENTIFIER "x", "nazwa";
  Parser.INTEGER 0, "liczba";
  Parser.FLOAT 0.0, "liczba z przecinkiem";
  Parser.STRING "", "tekst";
]

(* Operatory i początki instrukcji/wyrażeń pasują prawie wszędzie - to szum w podpowiedzi *)
let is_noise = function
  | Parser.PLUS | MINUS | MULTIPLY | DIVIDE | MODULO | EQUAL | NOT_EQUAL | GREATER | LESS
  | GREATER_EQUAL | AND | OR | BIT_AND | BIT_OR | BIT_XOR | BIT_SHIFT_LEFT | BIT_SHIFT_RIGHT
  | POINTER_STEP_FORWARD | POINTER_STEP_BACK
  | VAR_DECL | ARRAY_DECL | PRINT | PRINT_INLINE | PRINT_NEWLINE | READ | ASSIGN_START | IF
  | WHILE | FOR | SWITCH | FUNC_CALL | FUNC_CALL_ASSIGN | RETURN | TRY | THROW | BREAK | CONTINUE
  | FUNC_DECL | CLASS | STRUCT | UNION | ENUM | IMPORT
  (* "koniec programu" pasuje po każdej instrukcji na górnym poziomie - nic nie mówi *)
  | PROGRAM_END | EOF -> true
  | _ -> false

let starts_expression = function
  | Parser.IDENTIFIER _ | INTEGER _ | FLOAT _ | STRING _ | TRUE | FALSE | NULL | LPAREN | LBRACKET | NOT
  | BIT_NOT | TO_FIXED | FROM_FIXED | ARRAY_INDEX | NEW | NEW_STRUCT | NEW_UNION
  | POINTER_REF | POINTER_DEREF | POINTER_ADDR -> true
  | _ -> false

(* Tokeny akceptowane w miejscu błędu; [] gdy nie da się ustalić *)
let acceptable text fname =
  let lexbuf = Lexing.from_string text in
  lexbuf.Lexing.lex_curr_p <- { lexbuf.Lexing.lex_curr_p with Lexing.pos_fname = fname };
  let rec go last cp =
    match cp with
    | I.InputNeeded _ ->
        (match Lexer.token lexbuf with
         | tok -> go (Some cp) (I.offer cp (tok, lexbuf.Lexing.lex_start_p, lexbuf.Lexing.lex_curr_p))
         | exception _ -> None)
    | I.Shifting _ | I.AboutToReduce _ -> go last (I.resume cp)
    | I.HandlingError _ -> last
    | I.Accepted _ | I.Rejected -> None
  in
  match go None (Parser.Incremental.program lexbuf.Lexing.lex_curr_p) with
  | None -> []
  | Some cp ->
      let pos = lexbuf.Lexing.lex_start_p in
      List.filter (fun (tok, _) -> I.acceptable cp tok pos) keywords

(* Dopisek do komunikatu (osobne zdanie ze spacją na początku albo ""): najpierw słowa, które coś zamykają/kontynuują; inaczej "wyrażenie" *)
let hint text fname =
  let ok = acceptable text fname in
  let specific = List.filter (fun (tok, _) -> not (is_noise tok) && not (starts_expression tok)) ok
                 |> List.map snd |> List.sort_uniq compare in
  match specific with
  | [] when List.exists (fun (tok, _) -> starts_expression tok) ok ->
      " Spodziewałem się wyrażenia (liczby, tekstu, nazwy...)."
  | [] -> ""
  | l when List.length l > 6 -> ""
  | l -> " Spodziewałem się: " ^ String.concat " albo " (List.map (Printf.sprintf "'%s'") l) ^ "."
