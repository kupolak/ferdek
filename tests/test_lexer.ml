(* Lexer test for Ferdek language *)

open Printf
open Lexer
open Parser

let string_of_token = function
  | PROGRAM_START -> "PROGRAM_START"
  | PROGRAM_END -> "PROGRAM_END"
  | VAR_DECL -> "VAR_DECL"
  | VAR_INIT -> "VAR_INIT"
  | PRINT -> "PRINT"
  | READ -> "READ"
  | ASSIGN_START -> "ASSIGN_START"
  | ASSIGN_OP -> "ASSIGN_OP"
  | ASSIGN_END -> "ASSIGN_END"
  | IF -> "IF"
  | ELSE -> "ELSE"
  | END_IF -> "END_IF"
  | WHILE -> "WHILE"
  | END_WHILE -> "END_WHILE"
  | FUNC_DECL -> "FUNC_DECL"
  | FUNC_RETURNS -> "FUNC_RETURNS"
  | FUNC_PARAMS -> "FUNC_PARAMS"
  | FUNC_END -> "FUNC_END"
  | FUNC_CALL -> "FUNC_CALL"
  | FUNC_CALL_ASSIGN -> "FUNC_CALL_ASSIGN"
  | RETURN -> "RETURN"
  | PLUS -> "PLUS"
  | MINUS -> "MINUS"
  | MULTIPLY -> "MULTIPLY"
  | DIVIDE -> "DIVIDE"
  | MODULO -> "MODULO"
  | EQUAL -> "EQUAL"
  | NOT_EQUAL -> "NOT_EQUAL"
  | GREATER -> "GREATER"
  | LESS -> "LESS"
  | AND -> "AND"
  | OR -> "OR"
  | TRUE -> "TRUE"
  | FALSE -> "FALSE"
  | LPAREN -> "LPAREN"
  | RPAREN -> "RPAREN"
  | LBRACKET -> "LBRACKET"
  | RBRACKET -> "RBRACKET"
  | COMMA -> "COMMA"
  | IMPORT -> "IMPORT"
  | ARRAY_DECL -> "ARRAY_DECL"
  | ARRAY_INDEX -> "ARRAY_INDEX"
  | TRY -> "TRY"
  | CATCH -> "CATCH"
  | THROW -> "THROW"
  | NULL -> "NULL"
  | BREAK -> "BREAK"
  | CONTINUE -> "CONTINUE"
  | CLASS -> "CLASS"
  | NEW -> "NEW"
  | IDENTIFIER s -> sprintf "IDENTIFIER(%s)" s
  | INTEGER n -> sprintf "INTEGER(%d)" n
  | STRING s -> sprintf "STRING(\"%s\")" s
  | EOF -> "EOF"

let tokenize_string input =
  let lexbuf = Lexing.from_string input in
  let rec loop acc =
    match Lexer.token lexbuf with
    | EOF -> List.rev (EOF :: acc)
    | tok -> loop (tok :: acc)
  in
  loop []

let tokenize_file filename =
  let ic = open_in filename in
  let lexbuf = Lexing.from_channel ic in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
  let rec loop acc =
    try
      match Lexer.token lexbuf with
      | EOF ->
          close_in ic;
          List.rev (EOF :: acc)
      | tok -> loop (tok :: acc)
    with
    | Lexer.LexError msg ->
        close_in ic;
        let pos = lexbuf.lex_curr_p in
        eprintf "Lexical error in %s:%d:%d: %s\n"
          pos.pos_fname pos.pos_lnum (pos.pos_cnum - pos.pos_bol) msg;
        exit 1
  in
  loop []

let print_tokens tokens =
  List.iter (fun tok ->
    printf "%s\n" (string_of_token tok)
  ) tokens

let () =
  printf "=== Ferdek Language Lexer Test ===\n\n";

  (* Test 1: Hello World *)
  printf "Test 1: Hello World\n";
  printf "-------------------\n";
  let input1 = "CO JEST KURDE\nPANIE SENSACJA REWELACJA \"Cześć, tu Ferdek!\"\nTRZEBA SPAĆ ŻEBY RANO DO ROBOTY WSTAĆ" in
  let tokens1 = tokenize_string input1 in
  print_tokens tokens1;
  printf "\n";

  (* Test 2: Variables *)
  printf "Test 2: Variable declaration\n";
  printf "----------------------------\n";
  let input2 = "CYCU PRZYNIEŚ NO piwa\nTO NIE SĄ TANIE RZECZY 6" in
  let tokens2 = tokenize_string input2 in
  print_tokens tokens2;
  printf "\n";

  (* Test 3: Arithmetic operators *)
  printf "Test 3: Arithmetic operators\n";
  printf "----------------------------\n";
  let input3 = "O KURDE MAM POMYSŁA x\nA PROSZĘ BARDZO y\nBABKA DAWAJ RENTĘ 5\nNO I GITARA" in
  let tokens3 = tokenize_string input3 in
  print_tokens tokens3;
  printf "\n";

  (* Test 4: Conditional *)
  printf "Test 4: If-else statement\n";
  printf "-------------------------\n";
  let input4 = "NO JAK NIE JAK TAK x MOJA NOGA JUŻ TUTAJ NIE POSTANIE 0\nA DUPA TAM\nCHAMSTWO W PAŃSTWIE" in
  let tokens4 = tokenize_string input4 in
  print_tokens tokens4;
  printf "\n";

  (* Test 5: Comments *)
  printf "Test 5: Comments\n";
  printf "----------------\n";
  let input5 = "RYM CYM CYM to jest komentarz\nCYCU PRZYNIEŚ NO x\nTO NIE SĄ TANIE RZECZY 42" in
  let tokens5 = tokenize_string input5 in
  print_tokens tokens5;
  printf "\n";

  (* Test 6: Boolean values *)
  printf "Test 6: Boolean values\n";
  printf "----------------------\n";
  let input6 = "A ŻEBYŚ PAN WIEDZIAŁ\nGUL MI SKOCZYŁ" in
  let tokens6 = tokenize_string input6 in
  print_tokens tokens6;
  printf "\n";

  (* Test 7: Function *)
  printf "Test 7: Function declaration\n";
  printf "----------------------------\n";
  let input7 = "ALE WIE PAN JA ZASADNICZO dodaj\nNA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO a, b\nDO WIDZENIA PANU" in
  let tokens7 = tokenize_string input7 in
  print_tokens tokens7;
  printf "\n";

  (* Test from file if argument provided *)
  if Array.length Sys.argv > 1 then begin
    let filename = Sys.argv.(1) in
    printf "Test from file: %s\n" filename;
    printf "========================\n";
    let tokens = tokenize_file filename in
    print_tokens tokens
  end
