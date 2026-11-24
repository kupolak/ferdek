(* Compiler Interface for Ferdek Programming Language *)

open Ast

(* Błąd w programie (np. nieznana zmienna) *)
exception Compile_error of string

(* Wklejenie importowanych modułów w miejscu importu; brak modułu -> Compile_error *)
val expand_imports : (string -> program option) -> top_level_decl list -> top_level_decl list

(* load_module: jak w interpreterze, zwraca AST modułu do wklejenia w miejscu importu *)
val compile_program : ?load_module:(string -> program option) -> program -> string

(* Funkcje wbudowane, które zna kompilator: nazwa i liczba argumentów (None = dowolna) *)
val builtin_arities : unit -> (string * int option) list
