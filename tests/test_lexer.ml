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
  | PRINT_INLINE -> "PRINT_INLINE"
  | PRINT_NEWLINE -> "PRINT_NEWLINE"
  | NOT -> "NOT"
  | ELSE_IF -> "ELSE_IF"
  | FOR -> "FOR"
  | FOR_FROM -> "FOR_FROM"
  | FOR_TO -> "FOR_TO"
  | FOR_STEP -> "FOR_STEP"
  | FOR_IN -> "FOR_IN"
  | SWITCH -> "SWITCH"
  | CONST -> "CONST"
  | FINALLY -> "FINALLY"
  | TYPE _ -> "TYPE"
  | CASE -> "CASE"
  | DEFAULT -> "DEFAULT"
  | END_SWITCH -> "END_SWITCH"
  | GREATER_EQUAL -> "GREATER_EQUAL"
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
  | LAMBDA -> "LAMBDA"
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
  | COMMA -> "COMMA"
  | IMPORT -> "IMPORT"
  | IMPORT_AS -> "IMPORT_AS"
  | SLASH -> "SLASH"
  | ARRAY_DECL -> "ARRAY_DECL"
  | ARRAY_INDEX -> "ARRAY_INDEX"
  | TRY -> "TRY"
  | CATCH -> "CATCH"
  | THROW -> "THROW"
  | NULL -> "NULL"
  | BREAK -> "BREAK"
  | CONTINUE -> "CONTINUE"
  | CLASS -> "CLASS"
  | EXTENDS -> "EXTENDS"
  | NEW -> "NEW"
  | STRUCT -> "STRUCT"
  | END_STRUCT -> "END_STRUCT"
  | NEW_STRUCT -> "NEW_STRUCT"
  | POINTER_REF -> "POINTER_REF"
  | POINTER_DEREF -> "POINTER_DEREF"
  | POINTER_ADDR -> "POINTER_ADDR"
  | POINTER_STEP_FORWARD -> "POINTER_STEP_FORWARD"
  | POINTER_STEP_BACK -> "POINTER_STEP_BACK"
  | UNION -> "UNION"
  | NEW_UNION -> "NEW_UNION"
  | END_UNION -> "END_UNION"
  | ENUM -> "ENUM"
  | END_ENUM -> "END_ENUM"
  | BIT_AND -> "BIT_AND"
  | BIT_OR -> "BIT_OR"
  | BIT_XOR -> "BIT_XOR"
  | BIT_NOT -> "BIT_NOT"
  | BIT_SHIFT_LEFT -> "BIT_SHIFT_LEFT"
  | BIT_SHIFT_RIGHT -> "BIT_SHIFT_RIGHT"
  | TO_FIXED -> "TO_FIXED"
  | FROM_FIXED -> "FROM_FIXED"
  | LBRACKET -> "LBRACKET"
  | RBRACKET -> "RBRACKET"
  | IDENTIFIER s -> sprintf "IDENTIFIER(%s)" s
  | INTEGER n -> sprintf "INTEGER(%d)" n
  | FLOAT f -> sprintf "FLOAT(%g)" f
  | STRING s -> sprintf "STRING(\"%s\")" s
  | INTERP_HEAD s -> sprintf "INTERP_HEAD(\"%s\")" s
  | INTERP_PART s -> sprintf "INTERP_PART(\"%s\")" s
  | INTERP_END s -> sprintf "INTERP_END(\"%s\")" s
  | ELLIPSIS -> "ELLIPSIS"
  | EOF -> "EOF"

(* Test lexing from string *)
let test_string name input =
  printf "Test: %s\n" name;
  printf "-------------------\n";
  let lexbuf = Lexing.from_string input in
  let rec tokenize acc =
    match Lexer.token lexbuf with
    | EOF -> List.rev (EOF :: acc)
    | tok -> tokenize (tok :: acc)
  in
  let tokens = tokenize [] in
  List.iter (fun tok -> printf "%s\n" (string_of_token tok)) tokens;
  printf "\n"

(* Test lexing from file *)
let test_file filename =
  printf "Test from file: %s\n" filename;
  printf "========================\n";
  try
    let ic = open_in filename in
    let lexbuf = Lexing.from_channel ic in
    let rec tokenize () =
      match Lexer.token lexbuf with
      | EOF ->
          close_in ic;
          printf "EOF\n"
      | tok ->
          printf "%s\n" (string_of_token tok);
          tokenize ()
    in
    tokenize ();
    printf "\n"
  with
  | Lexer.LexError msg ->
      Printf.eprintf "Lexical error: %s\n" msg
  | Sys_error msg ->
      Printf.eprintf "System error: %s\n" msg

(* Main tests *)
let () =
  printf "=== Ferdek Language Lexer Test ===\n\n";
  
  test_string "Hello World" 
    "CO JEST KURDE\nPANIE SENSACJA REWELACJA \"Cześć, tu Ferdek!\"\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE";
  
  test_string "Variable declaration"
    "CYCU PRZYNIEŚ NO piwa\nTO NIE SĄ TANIE RZECZY 6";
  
  test_string "Arithmetic operators"
    "O KURDE MAM POMYSŁA x\nA PROSZĘ BARDZO y BABKA DAWAJ RENTĘ 5\nNO I GITARA";
  
  test_string "If-else statement"
    "NO JAK NIE JAK TAK x GRUBA ŚWINIA 0\nA DUPA TAM\nDO CHAŁUPY ALE JUŻ";
  
  test_string "Comments"
    "CYCU PRZYNIEŚ NO x RYM CYM CYM This is a comment\nTO NIE SĄ TANIE RZECZY 42";
  
  test_string "Boolean values"
    "A ŻEBYŚ PAN WIEDZIAŁ\nGÓWNO PRAWDA";
  
  test_string "Function declaration"
    "ALE WIE PAN JA ZASADNICZO dodaj\nNA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO a, b\nDO WIDZENIA PANU";
  
  test_string "Import with path"
    "O KOGO MOJE PIĘKNE OCZY WIDZĄ KLAMOTY/SKRZYNKA";
  
  (* Test file if provided as argument *)
  if Array.length Sys.argv > 1 then
    test_file Sys.argv.(1)
