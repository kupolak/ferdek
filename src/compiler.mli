(* Compiler Interface for Ferdek Programming Language *)

open Ast

(* Nieobsługiwana konstrukcja albo błąd w programie (np. nieznana zmienna) *)
exception Compile_error of string

(* Compile a Ferdek program to C code *)
(* Zmienne (zadeklarowane, przypisane) w bloku instrukcji; używa też checker *)
val block_names : string list * string list -> stmt list -> string list * string list

(* Wklejenie importowanych modułów w miejscu importu; brak modułu -> Compile_error *)
val expand_imports : (string -> program option) -> top_level_decl list -> top_level_decl list

(* load_module: jak w interpreterze, zwraca AST modułu do wklejenia w miejscu importu *)
val compile_program : ?load_module:(string -> program option) -> program -> string
