(* Test parser - parses Ferdek code and displays the AST *)

(* Helper function to parse a string *)
let parse_string str =
  let lexbuf = Lexing.from_string str in
  try
    let ast = Parser.program Lexer.token lexbuf in
    Some ast
  with
  | Lexer.LexError msg ->
      Printf.eprintf "Lexer error: %s\n" msg;
      None
  | Parser.Error ->
      Printf.eprintf "Parse error at position %d\n" lexbuf.Lexing.lex_curr_pos;
      None

(* Test 1: Simple hello world *)
let test_hello_world () =
  print_endline "Test 1: Hello World";
  print_endline "-------------------";
  let code = {|CO JEST KURDE
PANIE SENSACJA REWELACJA "Cześć, tu Ferdek!"
MOJA NOGA JUŻ TUTAJ NIE POSTANIE|} in
  match parse_string code with
  | Some ast ->
      print_endline (Ast.string_of_program ast);
      print_newline ()
  | None ->
      print_endline "Failed to parse";
      print_newline ()

(* Test 2: Variable declaration *)
let test_var_decl () =
  print_endline "Test 2: Variable Declaration";
  print_endline "----------------------------";
  let code = {|CO JEST KURDE
CYCU PRZYNIEŚ NO piwa
TO NIE SĄ TANIE RZECZY 6
MOJA NOGA JUŻ TUTAJ NIE POSTANIE|} in
  match parse_string code with
  | Some ast ->
      print_endline (Ast.string_of_program ast);
      print_newline ()
  | None ->
      print_endline "Failed to parse";
      print_newline ()

(* Test 3: Arithmetic expression *)
let test_arithmetic () =
  print_endline "Test 3: Arithmetic Expression";
  print_endline "-----------------------------";
  let code = {|CO JEST KURDE
CYCU PRZYNIEŚ NO wynik
TO NIE SĄ TANIE RZECZY 10
O KURDE MAM POMYSŁA wynik
A PROSZĘ BARDZO wynik
BABKA DAWAJ RENTĘ 5
NO I GITARA
MOJA NOGA JUŻ TUTAJ NIE POSTANIE|} in
  match parse_string code with
  | Some ast ->
      print_endline (Ast.string_of_program ast);
      print_newline ()
  | None ->
      print_endline "Failed to parse";
      print_newline ()

(* Test 4: If statement *)
let test_if_stmt () =
  print_endline "Test 4: If Statement";
  print_endline "--------------------";
  let code = {|CO JEST KURDE
CYCU PRZYNIEŚ NO kasa
TO NIE SĄ TANIE RZECZY 100
NO JAK NIE JAK TAK kasa GRUBA ŚWINIA 0
    PANIE SENSACJA REWELACJA "Mam kasę!"
A DUPA TAM
    PANIE SENSACJA REWELACJA "Brak kasy"
DO CHAŁUPY ALE JUŻ
MOJA NOGA JUŻ TUTAJ NIE POSTANIE|} in
  match parse_string code with
  | Some ast ->
      print_endline (Ast.string_of_program ast);
      print_newline ()
  | None ->
      print_endline "Failed to parse";
      print_newline ()

(* Test 5: While loop *)
let test_while_loop () =
  print_endline "Test 5: While Loop";
  print_endline "------------------";
  let code = {|CO JEST KURDE
CYCU PRZYNIEŚ NO licznik
TO NIE SĄ TANIE RZECZY 5
CHLUŚNIEM BO UŚNIEM licznik GRUBA ŚWINIA 0
    PANIE SENSACJA REWELACJA licznik
    O KURDE MAM POMYSŁA licznik
    A PROSZĘ BARDZO licznik
    PASZOŁ WON 1
    NO I GITARA
A ROBIĆ NI MA KOMU
MOJA NOGA JUŻ TUTAJ NIE POSTANIE|} in
  match parse_string code with
  | Some ast ->
      print_endline (Ast.string_of_program ast);
      print_newline ()
  | None ->
      print_endline "Failed to parse";
      print_newline ()

(* Test 6: Function declaration *)
let test_function () =
  print_endline "Test 6: Function Declaration";
  print_endline "----------------------------";
  let code = {|CO JEST KURDE
ALE WIE PAN JA ZASADNICZO dodaj
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO a, b
    CYCU PRZYNIEŚ NO wynik
    TO NIE SĄ TANIE RZECZY 0
    O KURDE MAM POMYSŁA wynik
    A PROSZĘ BARDZO a
    BABKA DAWAJ RENTĘ b
    NO I GITARA
    I JA INFORMUJĘ ŻE WYCHODZĘ wynik
DO WIDZENIA PANU
MOJA NOGA JUŻ TUTAJ NIE POSTANIE|} in
  match parse_string code with
  | Some ast ->
      print_endline (Ast.string_of_program ast);
      print_newline ()
  | None ->
      print_endline "Failed to parse";
      print_newline ()

(* Test 7: Array declaration *)
let test_array () =
  print_endline "Test 7: Array Declaration";
  print_endline "-------------------------";
  let code = {|CO JEST KURDE
PANIE TO JEST PRYWATNA PUBLICZNA TABLICA liczby
TO NIE SĄ TANIE RZECZY [1, 2, 3, 4, 5]
MOJA NOGA JUŻ TUTAJ NIE POSTANIE|} in
  match parse_string code with
  | Some ast ->
      print_endline (Ast.string_of_program ast);
      print_newline ()
  | None ->
      print_endline "Failed to parse";
      print_newline ()

(* Test 8: Boolean expressions *)
let test_boolean () =
  print_endline "Test 8: Boolean Expressions";
  print_endline "---------------------------";
  let code = {|CO JEST KURDE
CYCU PRZYNIEŚ NO prawda
TO NIE SĄ TANIE RZECZY A ŻEBYŚ PAN WIEDZIAŁ
CYCU PRZYNIEŚ NO falsz
TO NIE SĄ TANIE RZECZY GÓWNO PRAWDA
MOJA NOGA JUŻ TUTAJ NIE POSTANIE|} in
  match parse_string code with
  | Some ast ->
      print_endline (Ast.string_of_program ast);
      print_newline ()
  | None ->
      print_endline "Failed to parse";
      print_newline ()

(* Main test runner *)
let () =
  print_endline "========================================";
  print_endline "  FERDEK PARSER TESTS";
  print_endline "========================================";
  print_newline ();

  test_hello_world ();
  test_var_decl ();
  test_arithmetic ();
  test_if_stmt ();
  test_while_loop ();
  test_function ();
  test_array ();
  test_boolean ();

  print_endline "========================================";
  print_endline "  ALL TESTS COMPLETED";
  print_endline "========================================"
