(* Compiler Interface for Ferdek Programming Language *)

open Ast

(* Compile a Ferdek program to C code *)
val compile_program : program -> string
