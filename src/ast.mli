(* AST - Abstract Syntax Tree Interface for Ferdek Programming Language *)

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
type expr =
  | IntLiteral of int
  | FloatLiteral of float                                (* Liczba z przecinkiem: 3.14 *)
  | StringLiteral of string
  | BoolLiteral of bool
  | NullLiteral
  | Identifier of string
  | BinaryOp of expr * arith_op * expr
  | ComparisonOp of expr * comparison_op * expr
  | LogicalOp of expr * logical_op * expr
  | BitwiseOp of expr * bitwise_op * expr
  | ArrayLiteral of expr list                             (* [a, b, c] jako wyrażenie *)
  | LogicalNot of expr                                   (* Negacja logiczna (TAK BYĆ NIE BĘDZIE) *)
  | BitwiseNot of expr
  | ArrayAccess of expr * expr  (* Changed to support nested access: arr[i][j] *)
  | FunctionCall of string * expr list
  | NewObject of string * expr list
  | NewStruct of string
  | NewUnion of string
  | Reference of expr
  | Dereference of expr
  | AddressOf of string
  | PointerArithmetic of expr * arith_op * expr
  | FunctionRef of string
  | ToFixed of expr
  | FromFixed of expr
  | Parenthesized of expr
  | Lambda of string list * stmt list   (* ciało z wyrażeniem = [Return (Some e)] *)

(* ============ STATEMENTS ============ *)

(* Statement type *)
and stmt =
  | VarDecl of string * expr
  | ConstDecl of string * expr   (* TO JE NA AMEN - jak VarDecl, ale nie wolno zmieniać (Consts.check) *)
  | ArrayDecl of string * expr list
  | Print of expr
  | PrintInline of expr
  | Read of string
  | Assign of string * expr
  | ArrayAssign of expr * expr  (* Changed to support nested access: arr[i][j] = val *)
  | If of expr * stmt list * stmt list option
  | While of expr * stmt list
  | For of string * expr * expr * expr option * stmt list  (* KRĘCI CEMENT BETONIARA i OD a DO b [CO krok] ... A ROBIĆ NI MA KOMU *)
  | ForEach of string * expr * stmt list                 (* KRĘCI CEMENT BETONIARA x Z kolekcja ... A ROBIĆ NI MA KOMU *)
  | FunctionCallStmt of string * expr list
  | FunctionCallWithAssign of string * string * expr list
  | Return of expr option
  | Try of stmt list * string * stmt list
  | Throw of expr
  | Break
  | Continue
  | Located of string * int * stmt  (* plik, linia *)

(* ============ HIGH-LEVEL DECLARATIONS ============ *)

(* Function parameter *)
type param = string

(* Function declaration *)
type function_decl = {
  name: string;
  params: param list;
  is_variadic: bool;
  has_return: bool;
  body: stmt list;
}

(* Class declaration *)
type class_decl = {
  name: string;
  parent_class: string option;
  fields: (string * expr) list;
  methods: function_decl list;
}

(* Struct declaration *)
type struct_decl = {
  name: string;
  fields: (string * expr) list;
}

(* Union declaration *)
type union_decl = {
  name: string;
  fields: (string * expr) list;  (* Union fields share the same memory *)
}

(* Enum declaration *)
type enum_decl = {
  name: string;
  values: (string * int option) list;  (* Enum values with optional explicit numbers *)
}

(* Module import *)
type import_stmt = string

(* ============ PROGRAM ============ *)

(* Top-level declaration *)
type top_level_decl =
  | Import of import_stmt
  | ImportAs of import_stmt * string   (* moduł, alias *)
  | Statement of stmt
  | FunctionDecl of function_decl
  | ClassDecl of class_decl
  | StructDecl of struct_decl
  | UnionDecl of union_decl
  | EnumDecl of enum_decl

(* Program - main AST structure *)
type program = {
  declarations: top_level_decl list;
}

(* ============ HELPER FUNCTIONS ============ *)

(* Create an empty program *)
val empty_program : unit -> program

(* Add a declaration to a program *)
val add_declaration : program -> top_level_decl -> program

(* Convert operators to strings *)
val string_of_arith_op : arith_op -> string
val string_of_comparison_op : comparison_op -> string
val string_of_logical_op : logical_op -> string
val string_of_bitwise_op : bitwise_op -> string

(* ============ PRETTY PRINTING ============ *)

(* Convert expression to string *)
val string_of_expr : expr -> string

(* Nazwy zmiennych i funkcji użyte w wyrażeniu/instrukcji (bez własnych nazw lambd) *)
val expr_names : expr -> string list
val stmt_names : stmt -> string list

(* Zmienne deklarowane w bloku: CYCU PRZYNIEŚ NO, tablice, zmienna z HELENA MAM ZAWAŁ *)
val block_decls : stmt list -> string list

(* (zadeklarowane, przypisane) w bloku - nazwy, które instrukcje tworzą albo zmieniają *)
val targets_stmt : string list * string list -> stmt -> string list * string list
val targets_block : string list * string list -> stmt list -> string list * string list

(* Convert statement to string *)
val string_of_stmt : string -> stmt -> string

(* Convert function declaration to string *)
val string_of_function_decl : string -> function_decl -> string

(* Convert class declaration to string *)
val string_of_class_decl : string -> class_decl -> string

(* Convert struct declaration to string *)
val string_of_struct_decl : string -> struct_decl -> string

(* Convert union declaration to string *)
val string_of_union_decl : string -> union_decl -> string

(* Convert enum declaration to string *)
val string_of_enum_decl : string -> enum_decl -> string

(* Convert top-level declaration to string *)
val string_of_top_level_decl : top_level_decl -> string

(* Convert entire program to string *)
val string_of_program : program -> string
