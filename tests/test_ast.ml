(* Test modułu AST *)

open Ast

(* Test 1: Proste wyrażenie arytmetyczne *)
let test_simple_expr () =
  let expr = BinaryOp (IntLiteral 5, Plus, IntLiteral 3) in
  print_endline "Test 1: Proste wyrażenie arytmetyczne";
  print_endline ("  " ^ string_of_expr expr);
  print_newline ()

(* Test 2: Deklaracja zmiennej *)
let test_var_decl () =
  let stmt = VarDecl ("piwa", IntLiteral 6) in
  print_endline "Test 2: Deklaracja zmiennej";
  print_endline ("  " ^ string_of_stmt "" stmt);
  print_newline ()

(* Test 3: Instrukcja print *)
let test_print_stmt () =
  let stmt = Print (StringLiteral "Cześć, tu Ferdek!") in
  print_endline "Test 3: Instrukcja print";
  print_endline ("  " ^ string_of_stmt "" stmt);
  print_newline ()

(* Test 4: Instrukcja if *)
let test_if_stmt () =
  let cond = ComparisonOp (Identifier "kasa", Greater, IntLiteral 0) in
  let then_branch = [Print (StringLiteral "Mam kasę na browarka!")] in
  let else_branch = Some [Print (StringLiteral "Halinka, pożycz stówkę...")] in
  let stmt = If (cond, then_branch, else_branch) in
  print_endline "Test 4: Instrukcja if/else";
  print_endline (string_of_stmt "" stmt);
  print_newline ()

(* Test 5: Pętla while *)
let test_while_stmt () =
  let cond = ComparisonOp (Identifier "piwa", Greater, IntLiteral 0) in
  let body = [
    Print (Identifier "piwa");
    Assign ("piwa", BinaryOp (Identifier "piwa", Minus, IntLiteral 1))
  ] in
  let stmt = While (cond, body) in
  print_endline "Test 5: Pętla while";
  print_endline (string_of_stmt "" stmt);
  print_newline ()

(* Test 6: Deklaracja funkcji *)
let test_function_decl () =
  let fdecl = {
    name = "dolej_browarka";
    params = ["ile"];
    has_return = true;
    body = [
      VarDecl ("wynik", IntLiteral 0);
      Assign ("wynik", BinaryOp (Identifier "ile", Plus, IntLiteral 2));
      Return (Some (Identifier "wynik"))
    ]
  } in
  print_endline "Test 6: Deklaracja funkcji";
  print_endline (string_of_function_decl "" fdecl);
  print_newline ()

(* Test 7: Deklaracja tablicy *)
let test_array_decl () =
  let stmt = ArrayDecl ("liczby", [IntLiteral 1; IntLiteral 2; IntLiteral 3]) in
  print_endline "Test 7: Deklaracja tablicy";
  print_endline ("  " ^ string_of_stmt "" stmt);
  print_newline ()

(* Test 8: Dostęp do tablicy *)
let test_array_access () =
  let expr = ArrayAccess ("liczby", IntLiteral 0) in
  print_endline "Test 8: Dostęp do tablicy";
  print_endline ("  " ^ string_of_expr expr);
  print_newline ()

(* Test 9: Wyrażenie logiczne *)
let test_logical_expr () =
  let expr = LogicalOp (
    ComparisonOp (Identifier "reszta3", Equal, IntLiteral 0),
    And,
    ComparisonOp (Identifier "reszta5", Equal, IntLiteral 0)
  ) in
  print_endline "Test 9: Wyrażenie logiczne";
  print_endline ("  " ^ string_of_expr expr);
  print_newline ()

(* Test 10: Kompletny program *)
let test_complete_program () =
  let prog = {
    declarations = [
      Statement (VarDecl ("piwa", IntLiteral 6));
      Statement (Print (Identifier "piwa"));
      FunctionDecl {
        name = "test";
        params = [];
        has_return = false;
        body = [Print (StringLiteral "Hello")]
      };
      Import "modul"
    ]
  } in
  print_endline "Test 10: Kompletny program";
  print_endline (string_of_program prog);
  print_newline ()

(* Test 11: Obsługa wyjątków *)
let test_exception_handling () =
  let stmt = Try (
    [Print (StringLiteral "Próbuję...")],
    "err",
    [Print (StringLiteral "Złapałem błąd!")]
  ) in
  print_endline "Test 11: Obsługa wyjątków";
  print_endline (string_of_stmt "" stmt);
  print_newline ()

(* Test 12: Deklaracja klasy *)
let test_class_decl () =
  let cdecl = {
    name = "Ferdek";
    parent_class = None;
    fields = [("wiek", IntLiteral 50)];
    methods = [{
      name = "powitanie";
      params = [];
      has_return = false;
      body = [Print (StringLiteral "Cześć!")]
    }]
  } in
  print_endline "Test 12: Deklaracja klasy";
  print_endline (string_of_class_decl "" cdecl);
  print_newline ()

(* Główna funkcja testująca *)
let () =
  print_endline "========================================";
  print_endline "  TESTY MODUŁU AST - JĘZYK FERDEK";
  print_endline "========================================";
  print_newline ();

  test_simple_expr ();
  test_var_decl ();
  test_print_stmt ();
  test_if_stmt ();
  test_while_stmt ();
  test_function_decl ();
  test_array_decl ();
  test_array_access ();
  test_logical_expr ();
  test_exception_handling ();
  test_class_decl ();
  test_complete_program ();

  print_endline "========================================";
  print_endline "  WSZYSTKIE TESTY ZAKOŃCZONE";
  print_endline "========================================"
