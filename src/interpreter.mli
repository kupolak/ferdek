(* Interpreter Interface for Ferdek Programming Language *)

open Ast

(* Runtime value types *)
type value =
  | VInt of int
  | VString of string
  | VBool of bool
  | VNull
  | VArray of value array
  | VHashMap of (string, value) Hashtbl.t
  | VFunction of function_decl * environment
  | VClass of class_decl * environment
  | VStruct of struct_decl * environment
  | VObject of (string, value) Hashtbl.t
  | VFileHandle of file_handle

and file_handle =
  | InputHandle of in_channel
  | OutputHandle of out_channel

and environment

(* Convert value to string *)
val string_of_value : value -> string

(* Set module loader function *)
val set_module_loader : (string -> program option) -> unit

(* Execute a program *)
val eval_program : program -> (unit, string) result
