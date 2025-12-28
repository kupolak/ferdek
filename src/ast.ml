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
type expr =
  | IntLiteral of int                                    (* Integer literal *)
  | StringLiteral of string                              (* String literal *)
  | BoolLiteral of bool                                  (* Boolean literal: true (A ŻEBYŚ PAN WIEDZIAŁ), false (GÓWNO PRAWDA) *)
  | NullLiteral                                          (* Null value (W TYM KRAJU NIE MA PRACY DLA LUDZI Z MOIM WYKSZTAŁCENIEM) *)
  | Identifier of string                                 (* Variable identifier *)
  | BinaryOp of expr * arith_op * expr                   (* Binary arithmetic operation *)
  | ComparisonOp of expr * comparison_op * expr          (* Comparison operation *)
  | LogicalOp of expr * logical_op * expr                (* Logical operation *)
  | BitwiseOp of expr * bitwise_op * expr                (* Bitwise operation *)
  | BitwiseNot of expr                                   (* Bitwise NOT (NA OPAK) *)
  | ArrayAccess of string * expr                         (* Array element access (WYPIERDZIELAJ PAN NA POZYCJĘ) *)
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

(* ============ STATEMENTS ============ *)

(* Statement type *)
type stmt =
  | VarDecl of string * expr                             (* Variable declaration (CYCU PRZYNIEŚ NO ... TO NIE SĄ TANIE RZECZY) *)
  | ArrayDecl of string * expr list                      (* Array declaration (PANIE TO JEST PRYWATNA PUBLICZNA TABLICA) *)
  | Print of expr                                        (* Print statement (PANIE SENSACJA REWELACJA) *)
  | Read of string                                       (* Read input (CO TAM U PANA SŁYCHAĆ) *)
  | Assign of string * expr                              (* Assignment (O KURDE MAM POMYSŁA ... A PROSZĘ BARDZO ... NO I GITARA) *)
  | ArrayAssign of string * expr * expr                  (* Array element assignment (O KURDE MAM POMYSŁA arr[idx] ... A PROSZĘ BARDZO ... NO I GITARA) *)
  | If of expr * stmt list * stmt list option            (* If statement (NO JAK NIE JAK TAK ... A DUPA TAM ... DO CHAŁUPY ALE JUŻ) *)
  | While of expr * stmt list                            (* While loop (CHLUŚNIEM BO UŚNIEM ... A ROBIĆ NI MA KOMU) *)
  | FunctionCallStmt of string * expr list               (* Function call statement (W MORDĘ JEŻA) *)
  | FunctionCallWithAssign of string * string * expr list (* Function call with assignment (AFERA JEST ... W MORDĘ JEŻA) *)
  | Return of expr option                                (* Return statement (I JA INFORMUJĘ ŻE WYCHODZĘ) *)
  | Try of stmt list * string * stmt list                (* Try-catch block (HELENA MUSZĘ CI COŚ POWIEDZIEĆ ... HELENA MAM ZAWAŁ) *)
  | Throw of expr                                        (* Throw exception (O KARWASZ TWARZ) *)
  | Break                                                (* Break statement (A POCAŁUJCIE MNIE WSZYSCY W DUPĘ) *)
  | Continue                                             (* Continue statement (AKUKARACZA) *)

(* ============ HIGH-LEVEL DECLARATIONS ============ *)

(* Function parameter *)
type param = string

(* Function declaration *)
type function_decl = {
  name: string;                                          (* Function name *)
  params: param list;                                    (* Parameter list *)
  has_return: bool;                                      (* Whether function returns a value (NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ) *)
  body: stmt list;                                       (* Function body *)
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
let rec string_of_expr = function
  | IntLiteral n -> string_of_int n
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
  | ArrayAccess (name, idx) ->
      name ^ "[" ^ string_of_expr idx ^ "]"
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

(* Convert statement to string (simplified) *)
let rec string_of_stmt indent = function
  | VarDecl (name, expr) ->
      indent ^ "var " ^ name ^ " = " ^ string_of_expr expr
  | ArrayDecl (name, exprs) ->
      indent ^ "array " ^ name ^ " = [" ^ String.concat ", " (List.map string_of_expr exprs) ^ "]"
  | Print expr ->
      indent ^ "print " ^ string_of_expr expr
  | Read name ->
      indent ^ "read " ^ name
  | Assign (name, expr) ->
      indent ^ name ^ " = " ^ string_of_expr expr
  | ArrayAssign (name, idx, expr) ->
      indent ^ name ^ "[" ^ string_of_expr idx ^ "] = " ^ string_of_expr expr
  | If (cond, then_stmts, else_stmts_opt) ->
      let then_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) then_stmts) in
      let else_str = match else_stmts_opt with
        | None -> ""
        | Some stmts -> "\n" ^ indent ^ "else\n" ^
                        String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) stmts)
      in
      indent ^ "if " ^ string_of_expr cond ^ "\n" ^ then_str ^ else_str
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
  | Try (try_stmts, catch_var, catch_stmts) ->
      let try_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) try_stmts) in
      let catch_str = String.concat "\n" (List.map (string_of_stmt (indent ^ "  ")) catch_stmts) in
      indent ^ "try\n" ^ try_str ^ "\n" ^ indent ^ "catch " ^ catch_var ^ "\n" ^ catch_str
  | Throw expr ->
      indent ^ "throw " ^ string_of_expr expr
  | Break ->
      indent ^ "break"
  | Continue ->
      indent ^ "continue"

(* Convert function declaration to string *)
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
