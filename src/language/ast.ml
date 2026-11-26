(* AST - Abstract Syntax Tree for Ferdek Programming Language *)

(* ============ BASE TYPES ============ *)

(* Arithmetic operators *)
type arith_op =
  | Plus      (* BABKA DAWAJ RENTĘ *)
  | Minus     (* PASZOŁ WON *)
  | Multiply  (* ROZDUPCĘ BANK *)
  | Divide    (* MUSZĘ DO SRACZA *)
  | Modulo    (* PROSZĘ MNIE NATYCHMIAST OPUŚCIĆ *)

(* Comparison operators *)
type comparison_op =
  | Equal        (* TO PANU SIĘ CHCE WTEDY KIEDY MNIE *)
  | NotEqual     (* PAN TU NIE MIESZKASZ *)
  | Greater      (* MOJA NOGA JUŻ TUTAJ NIE POSTANIE *)
  | Less         (* CO SIĘ TAK WIERCISZ JAK GÓWNO W PRZERĘBLU *)
  | GreaterEqual (* JA JESTEM PONAD TO *)

(* Logical operators *)
type logical_op =
  | And  (* PIWO I TELEWIZOR *)
  | Or   (* ALBO JUTRO U ADWOKATA *)

(* Bitwise operators *)
type bitwise_op =
  | BitAnd      (* WSZYSTKO MUSI BYĆ *)
  | BitOr       (* COKOLWIEK MOŻE BYĆ *)
  | BitXor      (* TYLKO JEDNO Z TEGO *)
  | BitShiftLeft   (* RUSZ SIĘ W LEWO *)
  | BitShiftRight  (* RUSZ SIĘ W PRAWO *)

(* ============ EXPRESSIONS ============ *)

(* Expression - basic computational unit *)
(* Typy (opcjonalne, sprawdzane w działającym programie): TO JE LICZBA SYNEK, TO SĄ STRINGI... *)
type typ = TInt | TFloat | TString | TBool | TArray | TMap | TFunction

type expr =
  | IntLiteral of int                                    (* Integer literal *)
  | FloatLiteral of float                                (* Liczba z przecinkiem: 3.14 *)
  | StringLiteral of string                              (* String literal *)
  | BoolLiteral of bool                                  (* Boolean literal: true (A ŻEBYŚ PAN WIEDZIAŁ), false (GÓWNO PRAWDA) *)
  | NullLiteral                                          (* Null value (W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM) *)
  | Identifier of string                                 (* Variable identifier *)
  | BinaryOp of expr * arith_op * expr                   (* Binary arithmetic operation *)
  | ComparisonOp of expr * comparison_op * expr          (* Comparison operation *)
  | LogicalOp of expr * logical_op * expr                (* Logical operation *)
  | BitwiseOp of expr * bitwise_op * expr                (* Bitwise operation *)
  | ArrayLiteral of expr list                             (* [a, b, c] jako wyrażenie *)
  | LogicalNot of expr                                   (* Negacja logiczna (TAK BYĆ NIE BĘDZIE) *)
  | BitwiseNot of expr                                   (* Bitwise NOT (NA OPAK) *)
  | ArrayAccess of expr * expr                           (* Array element access (WYPIERDZIELAJ PAN NA POZYCJĘ) - supports nesting *)
  | FunctionCall of string * expr list                   (* Function call (W MORDĘ JEŻA) *)
  | NewObject of string * expr list                      (* New object instantiation (DZIAD ZDZIADZIAŁY JEDEN) *)
  | NewStruct of string                                  (* New struct instantiation (ZMONTUJ MEBEL) *)
  | NewUnion of string                                   (* New union instantiation (WCHODZIMY DO UNII) *)
  | Reference of expr                                    (* Create reference/pointer (PALCEM POKAZUJĘ) *)
  | Dereference of expr                                  (* Dereference pointer (CO TAM JEST) *)
  | AddressOf of string                                  (* Get address of variable (GDZIE STOI) *)
  | PointerArithmetic of expr * arith_op * expr          (* Pointer arithmetic (KROK DALEJ/KROK WSTECZ) *)
  | FunctionRef of string                                (* Function pointer reference (PALCEM POKAZUJĘ funkcja) *)
  | ToFixed of expr                                      (* Convert to fixed-point 16.16 (ZAMIEŃ NA FIXED) *)
  | FromFixed of expr                                    (* Convert from fixed-point 16.16 (WYJMIJ Z FIXED) *)
  | Parenthesized of expr                                (* Parenthesized expression *)
  | Conditional of expr * expr * expr                    (* NO JAK NIE JAK TAK w A PROSZĘ BARDZO a A DUPA TAM b - jedno albo drugie jako wartość *)
  | Switch of expr * (expr list * expr) list * expr      (* CO TO JE x / JAK JE 1, 2 A PROSZĘ BARDZO a / A JAK NIC Z TEGO b / KONIEC GADANIA - wybór jako wartość *)
  | Lambda of string list * stmt list                    (* JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ(x) x + 1  albo  (x) NO DOBRZE ... DO WIDZENIA PANU *)
  | Checked of expr * typ * string                       (* wartość musi mieć typ; napis: czego dotyczy (do błędu) *)

(* ============ STATEMENTS ============ *)

(* Statement type *)
and stmt =
  | VarDecl of string * expr                             (* Variable declaration (CYCU PRZYNIEŚ NO ... TO NIE SĄ TANIE RZECZY) *)
  | ConstDecl of string * expr                           (* Stała (TO JE NA AMEN ... TO NIE SĄ TANIE RZECZY) *)
  | ArrayDecl of string * expr list                      (* Array declaration (PANIE TO JEST PRYWATNA PUBLICZNA TABLICA) *)
  | Print of expr                                        (* Print statement (PANIE SENSACJA REWELACJA) *)
  | PrintInline of expr                                  (* Print bez końca linii (JEDZIEM Z TYM ŚLEDZIEM) *)
  | Read of string                                       (* Read input (CO TAM U PANA SŁYCHAĆ) *)
  | Assign of string * expr                              (* Assignment (O KURDE MAM POMYSŁA ... A PROSZĘ BARDZO ... NO I GITARA) *)
  | ArrayAssign of expr * expr                           (* Array element assignment - supports nested: arr[i][j] = val *)
  | If of expr * stmt list * stmt list option            (* If statement (NO JAK NIE JAK TAK ... A DUPA TAM ... DO CHAŁUPY ALE JUŻ) *)
  | While of expr * stmt list                            (* While loop (CHLUŚNIEM BO UŚNIEM ... A ROBIĆ NI MA KOMU) *)
  | For of string * expr * expr * expr option * stmt list  (* KRĘCI CEMENT BETONIARA i OD a DO b [CO krok] ... A ROBIĆ NI MA KOMU *)
  | ForEach of string * expr * stmt list                 (* KRĘCI CEMENT BETONIARA x Z kolekcja ... A ROBIĆ NI MA KOMU *)
  | FunctionCallStmt of string * expr list               (* Function call statement (W MORDĘ JEŻA) *)
  | FunctionCallWithAssign of string * string * expr list (* Function call with assignment (AFERA JEST ... W MORDĘ JEŻA) *)
  | Return of expr option                                (* Return statement (I JA INFORMUJĘ ŻE WYCHODZĘ) *)
  | Try of stmt list * string * stmt list * stmt list    (* try, zmienna, catch, I TAK TRZEBA POSPRZĄTAĆ (finally, [] gdy brak) *)
  | Throw of expr                                        (* Throw exception (O KARWASZ TWARZ) *)
  | Break                                                (* Break statement (A POCAŁUJCIE MNIE WSZYSCY W DUPĘ) *)
  | Continue                                             (* Continue statement (AKUKARACZA) *)
  | Located of string * int * stmt                       (* Plik i linia instrukcji - do komunikatów błędów *)

(* ============ HIGH-LEVEL DECLARATIONS ============ *)

(* Function parameter *)
type param = string

(* Function declaration *)
type function_decl = {
  name: string;                                          (* Function name *)
  params: param list;                                    (* Parameter list *)
  is_variadic: bool;                                     (* Whether function accepts variable arguments (...) *)
  has_return: bool;                                      (* Whether function returns a value (NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ) *)
  body: stmt list;                                       (* Function body *)
  defaults: (string * expr) list;                        (* Wartości domyślne ostatnich parametrów *)
}

(* Class declaration *)
type class_decl = {
  name: string;                                          (* Class name *)
  parent_class: string option;                           (* Parent class for inheritance (RENTA BABKI) *)
  fields: (string * expr) list;                          (* Class fields (variables) *)
  methods: function_decl list;                           (* Class methods *)
}

(* Struct declaration *)
type struct_decl = {
  name: string;                                          (* Struct name *)
  fields: (string * expr) list;                          (* Struct fields (no methods, no inheritance) *)
}

(* Union declaration *)
type union_decl = {
  name: string;                                          (* Union name *)
  fields: (string * expr) list;                          (* Union fields (all share same memory) *)
}

(* Enum declaration *)
type enum_decl = {
  name: string;                                          (* Enum name *)
  values: (string * int option) list;                    (* Enum values with optional explicit numbers *)
}

(* Module import *)
type import_stmt = string                                (* Module import (O KOGO MOJE PIĘKNE OCZY WIDZĄ) *)

(* ============ PROGRAM ============ *)

(* Top-level declaration *)
type top_level_decl =
  | Import of import_stmt
  | ImportAs of import_stmt * string                     (* O KOGO MOJE PIĘKNE OCZY WIDZĄ moduł JAKO m - nazwy jako m.nazwa *)
  | Statement of stmt
  | FunctionDecl of function_decl
  | ClassDecl of class_decl
  | StructDecl of struct_decl
  | UnionDecl of union_decl
  | EnumDecl of enum_decl

(* Program - main AST structure *)
type program = {
  declarations: top_level_decl list;                     (* List of top-level declarations *)
}

(* ============ HELPER FUNCTIONS ============ *)

(* Create an empty program *)
let empty_program () = { declarations = [] }

(* Add a declaration to a program *)
let add_declaration prog decl =
  { declarations = prog.declarations @ [decl] }

(* Convert arithmetic operator to string *)
let string_of_arith_op = function
  | Plus -> "+"
  | Minus -> "-"
  | Multiply -> "*"
  | Divide -> "/"
  | Modulo -> "%"

(* Convert comparison operator to string *)
let string_of_comparison_op = function
  | Equal -> "=="
  | NotEqual -> "!="
  | Greater -> ">"
  | Less -> "<"
  | GreaterEqual -> ">="

(* Convert logical operator to string *)
let string_of_logical_op = function
  | And -> "&&"
  | Or -> "||"

(* Convert bitwise operator to string *)
let string_of_bitwise_op = function
  | BitAnd -> "&"
  | BitOr -> "|"
  | BitXor -> "^"
  | BitShiftLeft -> "<<"
  | BitShiftRight -> ">>"

(* ============ PRETTY PRINTING (for debugging) ============ *)

(* Convert expression to string (simplified) *)
(* Typ tak, jak się go pisze *)
let string_of_typ = function
  | TInt -> "TO JE LICZBA SYNEK" | TFloat -> "TO JE LICZBA Z PRZECINKIEM" | TString -> "TO SĄ STRINGI"
  | TBool -> "TO JE TAK ALBO NIE" | TArray -> "TO JE WERSALKA" | TMap -> "TO JE SZAFKA"
  | TFunction -> "TO JE FUNKCJA"

let rec string_of_expr = function
  | IntLiteral n -> string_of_int n
  | FloatLiteral f -> Printf.sprintf "%.15g" f
  | StringLiteral s -> "\"" ^ s ^ "\""
  | BoolLiteral true -> "true"
  | BoolLiteral false -> "false"
  | NullLiteral -> "null"
  | Identifier id -> id
  | BinaryOp (e1, op, e2) ->
      "(" ^ string_of_expr e1 ^ " " ^ string_of_arith_op op ^ " " ^ string_of_expr e2 ^ ")"
  | ComparisonOp (e1, op, e2) ->
      "(" ^ string_of_expr e1 ^ " " ^ string_of_comparison_op op ^ " " ^ string_of_expr e2 ^ ")"
  | LogicalOp (e1, op, e2) ->
      "(" ^ string_of_expr e1 ^ " " ^ string_of_logical_op op ^ " " ^ string_of_expr e2 ^ ")"
  | BitwiseOp (e1, op, e2) ->
      "(" ^ string_of_expr e1 ^ " " ^ string_of_bitwise_op op ^ " " ^ string_of_expr e2 ^ ")"
  | BitwiseNot e ->
      "~(" ^ string_of_expr e ^ ")"
  | LogicalNot e ->
      "!(" ^ string_of_expr e ^ ")"
  | ArrayLiteral es ->
      "[" ^ String.concat ", " (List.map string_of_expr es) ^ "]"
  | ArrayAccess (arr_expr, idx) ->
      string_of_expr arr_expr ^ "[" ^ string_of_expr idx ^ "]"
  | FunctionCall (name, args) ->
      name ^ "(" ^ String.concat ", " (List.map string_of_expr args) ^ ")"
  | NewObject (class_name, args) ->
      "new " ^ class_name ^ "(" ^ String.concat ", " (List.map string_of_expr args) ^ ")"
  | NewStruct struct_name ->
      "new struct " ^ struct_name
  | NewUnion union_name ->
      "new union " ^ union_name
  | Reference e ->
      "&(" ^ string_of_expr e ^ ")"
  | Dereference e ->
      "*(" ^ string_of_expr e ^ ")"
  | AddressOf var ->
      "&" ^ var
  | PointerArithmetic (e1, op, e2) ->
      "(" ^ string_of_expr e1 ^ " " ^ string_of_arith_op op ^ " " ^ string_of_expr e2 ^ ")"
  | FunctionRef func_name ->
      "&" ^ func_name
  | ToFixed e ->
      "to_fixed(" ^ string_of_expr e ^ ")"
  | FromFixed e ->
      "from_fixed(" ^ string_of_expr e ^ ")"
  | Parenthesized e ->
      "(" ^ string_of_expr e ^ ")"
  | Conditional (c, a, b) ->
      "(" ^ string_of_expr c ^ " ? " ^ string_of_expr a ^ " : " ^ string_of_expr b ^ ")"
  | Switch (e, cases, d) ->
      "switch(" ^ string_of_expr e ^ ") {"
      ^ String.concat "" (List.map (fun (vs, r) ->
          String.concat ", " (List.map string_of_expr vs) ^ " -> " ^ string_of_expr r ^ "; ") cases)
      ^ "_ -> " ^ string_of_expr d ^ "}"
  | Checked (e, t, what) -> "(" ^ string_of_expr e ^ " : " ^ string_of_typ t ^ " [" ^ what ^ "])"
  | Lambda (params, body) ->
      "fun(" ^ String.concat ", " params ^ ") {\n"
      ^ String.concat "\n" (List.map (string_of_stmt "  ") body) ^ "\n}"

and string_of_stmt indent = function
  | ConstDecl (name, expr) ->
      indent ^ "const " ^ name ^ " = " ^ string_of_expr expr
  | VarDecl (name, expr) ->
      indent ^ "var " ^ name ^ " = " ^ string_of_expr expr
  | ArrayDecl (name, exprs) ->
      indent ^ "array " ^ name ^ " = [" ^ String.concat ", " (List.map string_of_expr exprs) ^ "]"
  | Print expr ->
      indent ^ "print " ^ string_of_expr expr
  | PrintInline expr ->
      indent ^ "print_inline " ^ string_of_expr expr
  | Read name ->
      indent ^ "read " ^ name
  | Assign (name, expr) ->
      indent ^ name ^ " = " ^ string_of_expr expr
  | ArrayAssign (arr_expr, value_expr) ->
      indent ^ string_of_expr arr_expr ^ " = " ^ string_of_expr value_expr
  | If (cond, then_stmts, else_stmts_opt) ->
      let then_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) then_stmts) in
      let else_str = match else_stmts_opt with
        | None -> ""
        | Some stmts -> "\n" ^ indent ^ "else\n" ^
                        String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) stmts)
      in
      indent ^ "if " ^ string_of_expr cond ^ "\n" ^ then_str ^ else_str
  | For (var, a, b, step, body) ->
      let step_str = match step with None -> "" | Some e -> " step " ^ string_of_expr e in
      let body_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) body) in
      indent ^ "for " ^ var ^ " = " ^ string_of_expr a ^ " to " ^ string_of_expr b ^ step_str ^ "\n" ^ body_str
  | ForEach (var, coll, body) ->
      let body_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) body) in
      indent ^ "for " ^ var ^ " in " ^ string_of_expr coll ^ "\n" ^ body_str
  | While (cond, body) ->
      let body_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) body) in
      indent ^ "while " ^ string_of_expr cond ^ "\n" ^ body_str
  | FunctionCallStmt (name, args) ->
      indent ^ name ^ "(" ^ String.concat ", " (List.map string_of_expr args) ^ ")"
  | FunctionCallWithAssign (var, func, args) ->
      indent ^ var ^ " = " ^ func ^ "(" ^ String.concat ", " (List.map string_of_expr args) ^ ")"
  | Return None ->
      indent ^ "return"
  | Return (Some expr) ->
      indent ^ "return " ^ string_of_expr expr
  | Try (try_stmts, catch_var, catch_stmts, finally_stmts) ->
      let try_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) try_stmts) in
      let catch_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) catch_stmts) in
      let fin_str = if finally_stmts = [] then "" else
        "\n" ^ indent ^ "finally\n" ^ String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) finally_stmts) in
      indent ^ "try\n" ^ try_str ^ "\n" ^ indent ^ "catch " ^ catch_var ^ "\n" ^ catch_str ^ fin_str
  | Throw expr ->
      indent ^ "throw " ^ string_of_expr expr
  | Break ->
      indent ^ "break"
  | Continue ->
      indent ^ "continue"
  | Located (_, _, s) ->
      string_of_stmt indent s

(* Convert function declaration to string *)
(* Wszystkie wyrażenia wyboru jako wartość: wartość, przypadki, wyniki, wynik domyślny *)
let switch_exprs e cases d = e :: List.concat_map (fun (vs, r) -> vs @ [r]) cases @ [d]

(* Nazwy, do których sięgają wyrażenia i instrukcje (zmienne, funkcje, cele przypisań),
   bez parametrów i zmiennych zadeklarowanych wewnątrz zagnieżdżonych lambd *)
let rec expr_names = function
  | Identifier n | FunctionRef n | AddressOf n -> [n]
  | FunctionCall (n, args) -> n :: List.concat_map expr_names args
  | NewObject (_, args) | ArrayLiteral args -> List.concat_map expr_names args
  | BinaryOp (a, _, b) | ComparisonOp (a, _, b) | LogicalOp (a, _, b) | BitwiseOp (a, _, b)
  | ArrayAccess (a, b) | PointerArithmetic (a, _, b) -> expr_names a @ expr_names b
  | BitwiseNot e | LogicalNot e | ToFixed e | FromFixed e | Reference e | Dereference e
  | Parenthesized e | Checked (e, _, _) -> expr_names e
  | Conditional (c, a, b) -> expr_names c @ expr_names a @ expr_names b
  | Switch (e, cases, d) -> List.concat_map expr_names (switch_exprs e cases d)
  | Lambda (params, body) ->
      let own = params @ block_decls body in
      List.filter (fun n -> not (List.mem n own)) (List.concat_map stmt_names body)
  | IntLiteral _ | FloatLiteral _ | StringLiteral _ | BoolLiteral _ | NullLiteral
  | NewStruct _ | NewUnion _ -> []

and stmt_names = function
  | VarDecl (n, e) | ConstDecl (n, e) | Assign (n, e) -> n :: expr_names e
  | ArrayDecl (n, es) -> n :: List.concat_map expr_names es
  | Print e | PrintInline e | Throw e -> expr_names e
  | Read n -> [n]
  | ArrayAssign (a, v) -> expr_names a @ expr_names v
  | If (c, a, b) -> expr_names c @ List.concat_map stmt_names (a @ Option.value b ~default:[])
  | While (c, b) -> expr_names c @ List.concat_map stmt_names b
  | For (v, a, b, k, body) ->
      v :: expr_names a @ expr_names b @ (match k with Some k -> expr_names k | None -> [])
      @ List.concat_map stmt_names body
  | ForEach (v, c, b) -> v :: expr_names c @ List.concat_map stmt_names b
  | FunctionCallStmt (n, args) -> n :: List.concat_map expr_names args
  | FunctionCallWithAssign (v, n, args) -> v :: n :: List.concat_map expr_names args
  | Return e -> (match e with Some e -> expr_names e | None -> [])
  | Try (a, v, b, f) -> v :: List.concat_map stmt_names (a @ b @ f)
  | Located (_, _, s) -> stmt_names s
  | Break | Continue -> []

(* Zmienne deklarowane w bloku (CYCU PRZYNIEŚ NO, tablica, zmienna z HELENA MAM ZAWAŁ) - świeże przy
   każdym wywołaniu, więc lambda ich nie łapie *)
and block_decls stmts = List.concat_map (function
  | VarDecl (n, _) | ConstDecl (n, _) | ArrayDecl (n, _) -> [n]
  | Located (_, _, s) -> block_decls [s]
  | If (_, a, b) -> block_decls (a @ Option.value b ~default:[])
  | While (_, b) | For (_, _, _, _, b) | ForEach (_, _, b) -> block_decls b
  | Try (a, v, b, f) -> v :: block_decls (a @ b @ f)
  | _ -> []) stmts

(* Zmienne zadeklarowane (VarDecl/ArrayDecl/catch) i przypisane w bloku.
   Ferdek nie ma zasięgu blokowego: zmienna z pętli żyje w całej funkcji. *)
let rec targets_stmt (decl, assigned) = function
  | VarDecl (n, _) | ConstDecl (n, _) | ArrayDecl (n, _) -> (n :: decl, assigned)
  | Read n | Assign (n, _) | FunctionCallWithAssign (n, _, _) -> (decl, n :: assigned)
  | If (_, a, b) -> targets_block (targets_block (decl, assigned) a) (Option.value b ~default:[])
  | While (_, b) -> targets_block (decl, assigned) b
  | ForEach (v, _, b) -> targets_block (decl, v :: assigned) b
  | For (v, _, _, _, b) -> targets_block (decl, v :: assigned) b
  | Try (a, v, b, f) -> targets_block (targets_block (targets_block (v :: decl, assigned) a) b) f
  | Located (_, _, s) -> targets_stmt (decl, assigned) s
  | _ -> (decl, assigned)
and targets_block acc stmts = List.fold_left targets_stmt acc stmts

(* Podwyrażenia (bez wnętrza lambd - to osobne funkcje) *)
let subexprs = function
  | FunctionCall (_, es) | NewObject (_, es) | ArrayLiteral es -> es
  | BinaryOp (a, _, b) | ComparisonOp (a, _, b) | LogicalOp (a, _, b) | BitwiseOp (a, _, b)
  | ArrayAccess (a, b) | PointerArithmetic (a, _, b) -> [a; b]
  | BitwiseNot e | LogicalNot e | ToFixed e | FromFixed e | Reference e | Dereference e
  | Parenthesized e | Checked (e, _, _) -> [e]
  | Conditional (c, a, b) -> [c; a; b]
  | Switch (e, cases, d) -> switch_exprs e cases d
  | _ -> []

(* Wyrażenia instrukcji razem z zagnieżdżonymi instrukcjami *)
let rec stmt_exprs = function
  | VarDecl (_, e) | ConstDecl (_, e) | Assign (_, e) | Print e | PrintInline e | Throw e -> [e]
  | ArrayDecl (_, es) -> es
  | ArrayAssign (a, v) -> [a; v]
  | If (c, a, b) -> c :: List.concat_map stmt_exprs (a @ Option.value b ~default:[])
  | While (c, b) -> c :: List.concat_map stmt_exprs b
  | For (_, a, b, k, body) -> a :: b :: Option.to_list k @ List.concat_map stmt_exprs body
  | ForEach (_, c, b) -> c :: List.concat_map stmt_exprs b
  | FunctionCallStmt (n, args) | FunctionCallWithAssign (_, n, args) -> [FunctionCall (n, args)]
  | Return e -> Option.to_list e
  | Try (a, _, b, f) -> List.concat_map stmt_exprs (a @ b @ f)
  | Located (_, _, s) -> stmt_exprs s
  | Read _ | Break | Continue -> []

(* Przekształcenie bezpośrednich podwyrażeń (f nie schodzi sama głębiej - robi to wołający) *)
let map_subexprs f = function
  | FunctionCall (n, es) -> FunctionCall (n, List.map f es)
  | NewObject (c, es) -> NewObject (c, List.map f es)
  | ArrayLiteral es -> ArrayLiteral (List.map f es)
  | BinaryOp (a, o, b) -> BinaryOp (f a, o, f b)
  | ComparisonOp (a, o, b) -> ComparisonOp (f a, o, f b)
  | LogicalOp (a, o, b) -> LogicalOp (f a, o, f b)
  | BitwiseOp (a, o, b) -> BitwiseOp (f a, o, f b)
  | ArrayAccess (a, b) -> ArrayAccess (f a, f b)
  | PointerArithmetic (a, o, b) -> PointerArithmetic (f a, o, f b)
  | BitwiseNot e -> BitwiseNot (f e)
  | LogicalNot e -> LogicalNot (f e)
  | ToFixed e -> ToFixed (f e)
  | FromFixed e -> FromFixed (f e)
  | Reference e -> Reference (f e)
  | Dereference e -> Dereference (f e)
  | Parenthesized e -> Parenthesized (f e)
  | Conditional (c, a, b) -> Conditional (f c, f a, f b)
  | Switch (e, cases, d) -> Switch (f e, List.map (fun (vs, r) -> (List.map f vs, f r)) cases, f d)
  | Checked (e, t, w) -> Checked (f e, t, w)
  | e -> e

(* Wyrażenia instrukcji (także zagnieżdżonych instrukcji) przepuszczone przez f *)
let rec map_stmt_exprs f = function
  | VarDecl (n, e) -> VarDecl (n, f e)
  | ConstDecl (n, e) -> ConstDecl (n, f e)
  | Assign (n, e) -> Assign (n, f e)
  | ArrayDecl (n, es) -> ArrayDecl (n, List.map f es)
  | Print e -> Print (f e)
  | PrintInline e -> PrintInline (f e)
  | Throw e -> Throw (f e)
  | ArrayAssign (a, v) -> ArrayAssign (f a, f v)
  | If (c, a, b) -> If (f c, List.map (map_stmt_exprs f) a, Option.map (List.map (map_stmt_exprs f)) b)
  | While (c, b) -> While (f c, List.map (map_stmt_exprs f) b)
  | For (v, a, b, k, body) -> For (v, f a, f b, Option.map f k, List.map (map_stmt_exprs f) body)
  | ForEach (v, c, b) -> ForEach (v, f c, List.map (map_stmt_exprs f) b)
  | FunctionCallStmt (n, args) -> FunctionCallStmt (n, List.map f args)
  | FunctionCallWithAssign (v, n, args) -> FunctionCallWithAssign (v, n, List.map f args)
  | Return e -> Return (Option.map f e)
  | Try (a, v, b, fin) -> Try (List.map (map_stmt_exprs f) a, v, List.map (map_stmt_exprs f) b,
                               List.map (map_stmt_exprs f) fin)
  | Located (file, l, s) -> Located (file, l, map_stmt_exprs f s)
  | s -> s

let string_of_function_decl indent fdecl =
  let params_str = String.concat ", " fdecl.params in
  let body_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) fdecl.body) in
  let return_type = if fdecl.has_return then " -> value" else "" in
  indent ^ "function " ^ fdecl.name ^ "(" ^ params_str ^ ")" ^ return_type ^ "\n" ^ body_str

(* Convert class declaration to string *)
let string_of_class_decl indent cdecl =
  let parent_str = match cdecl.parent_class with
    | Some parent -> " extends " ^ parent
    | None -> ""
  in
  let fields_str = List.map (fun (name, expr) ->
    indent ^ "  " ^ name ^ " = " ^ string_of_expr expr
  ) cdecl.fields in
  let methods_str = List.map (string_of_function_decl (indent ^ "  ")) cdecl.methods in
  indent ^ "class " ^ cdecl.name ^ parent_str ^ "\n" ^
  String.concat "\n" fields_str ^ "\n" ^
  String.concat "\n" methods_str

(* Convert struct declaration to string *)
let string_of_struct_decl indent (sdecl : struct_decl) : string =
  let fields_str = List.map (fun (name, expr) ->
    indent ^ "  " ^ name ^ " = " ^ string_of_expr expr
  ) sdecl.fields in
  indent ^ "struct " ^ sdecl.name ^ "\n" ^
  String.concat "\n" fields_str

(* Convert union declaration to string *)
let string_of_union_decl indent (u : union_decl) =
  let fields_str = List.map (fun (name, expr) ->
    indent ^ "  " ^ name ^ " = " ^ string_of_expr expr
  ) u.fields in
  indent ^ "union " ^ u.name ^ "\n" ^
  String.concat "\n" fields_str

(* Convert enum declaration to string *)
let string_of_enum_decl indent (e : enum_decl) =
  let values_str = List.map (fun (name, value_opt) ->
    match value_opt with
    | Some v -> indent ^ "  " ^ name ^ " = " ^ string_of_int v
    | None -> indent ^ "  " ^ name
  ) e.values in
  indent ^ "enum " ^ e.name ^ "\n" ^
  String.concat "\n" values_str

(* Convert top-level declaration to string *)
let string_of_top_level_decl (decl : top_level_decl) : string = match decl with
  | Import module_name ->
      "import " ^ module_name
  | ImportAs (module_name, alias) ->
      "import " ^ module_name ^ " as " ^ alias
  | Statement stmt ->
      string_of_stmt "" stmt
  | FunctionDecl fdecl ->
      string_of_function_decl "" fdecl
  | ClassDecl cdecl ->
      string_of_class_decl "" cdecl
  | StructDecl s ->
      string_of_struct_decl "" s
  | UnionDecl u ->
      string_of_union_decl "" u
  | EnumDecl e ->
      string_of_enum_decl "" e

(* Convert entire program to string *)
let string_of_program prog =
  "program:\n" ^ String.concat "\n" (List.map string_of_top_level_decl prog.declarations)
