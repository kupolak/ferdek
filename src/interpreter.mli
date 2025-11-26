(* Interpreter Interface for Ferdek Programming Language *)

open Ast

(* Runtime value types *)
type value =
  | VInt of int
  | VString of string
  | VBool of bool
  | VNull
  | VArray of value array
  | VFunction of function_decl * environment
  | VObject of (string, value) Hashtbl.t

and environment

(* Convert value to string *)
val string_of_value : value -> string

(* Execute a program *)
val eval_program : program -> (unit, string) result
