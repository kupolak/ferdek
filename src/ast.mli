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

(* Logical operators *)
type logical_op =
  | And  (* PIWO I TELEWIZOR *)
  | Or   (* ALBO JUTRO U ADWOKATA *)

(* ============ EXPRESSIONS ============ *)

(* Expression - basic computational unit *)
type expr =
  | IntLiteral of int
  | StringLiteral of string
  | BoolLiteral of bool
  | NullLiteral
  | Identifier of string
  | BinaryOp of expr * arith_op * expr
  | ComparisonOp of expr * comparison_op * expr
  | LogicalOp of expr * logical_op * expr
  | ArrayAccess of string * expr
  | FunctionCall of string * expr list
  | NewObject of string * expr list
  | Parenthesized of expr

(* ============ STATEMENTS ============ *)

(* Statement type *)
type stmt =
  | VarDecl of string * expr
  | ArrayDecl of string * expr list
  | Print of expr
  | Read of string
  | Assign of string * expr
  | ArrayAssign of string * expr * expr
  | If of expr * stmt list * stmt list option
  | While of expr * stmt list
  | FunctionCallStmt of string * expr list
  | FunctionCallWithAssign of string * string * expr list
  | Return of expr option
  | Try of stmt list * string * stmt list
  | Throw of expr
  | Break
  | Continue

(* ============ HIGH-LEVEL DECLARATIONS ============ *)

(* Function parameter *)
type param = string

(* Function declaration *)
type function_decl = {
  name: string;
  params: param list;
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

(* Module import *)
type import_stmt = string

(* ============ PROGRAM ============ *)

(* Top-level declaration *)
type top_level_decl =
  | Import of import_stmt
  | Statement of stmt
  | FunctionDecl of function_decl
  | ClassDecl of class_decl

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

(* ============ PRETTY PRINTING ============ *)

(* Convert expression to string *)
val string_of_expr : expr -> string

(* Convert statement to string *)
val string_of_stmt : string -> stmt -> string

(* Convert function declaration to string *)
val string_of_function_decl : string -> function_decl -> string

(* Convert class declaration to string *)
val string_of_class_decl : string -> class_decl -> string

(* Convert top-level declaration to string *)
val string_of_top_level_decl : top_level_decl -> string

(* Convert entire program to string *)
val string_of_program : program -> string
