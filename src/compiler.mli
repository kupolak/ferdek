(* Compiler Interface for Ferdek Programming Language *)

open Ast

(* Nieobsługiwana konstrukcja albo błąd w programie (np. nieznana zmienna) *)
exception Compile_error of string

(* Compile a Ferdek program to C code *)
(* load_module: jak w interpreterze, zwraca AST modułu do wklejenia w miejscu importu *)
val compile_program : ?load_module:(string -> program option) -> program -> string
