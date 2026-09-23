(* Compiler Interface for Ferdek Programming Language *)

open Ast

(* Nieobsługiwana konstrukcja albo błąd w programie (np. nieznana zmienna) *)
exception Compile_error of string

(* Compile a Ferdek program to C code *)
val compile_program : program -> string
