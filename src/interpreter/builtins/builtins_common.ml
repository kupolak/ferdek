(* Wspólne dla modułów z funkcjami wbudowanymi *)

open Value
open Eval

(* Wpisy: nazwy (z wariantami), liczba argumentów (None = dowolna), implementacja.
   Liczbę argumentów sprawdza eval_function_call; z tej tabeli czyta też ferdek --check. *)
let add entries =
  List.iter (fun (names, arity, impl) ->
    List.iter (fun n -> Vars.replace builtins n (arity, impl)) names) entries

(* Funkcja przekazana builtinowi (np. do sortowania) jako OCamlowa funkcja na wartościach *)
let function_arg builtin = function
  | VFunction (fdecl, closure_env) -> apply_function fdecl.name fdecl closure_env
  | _ -> raise (RuntimeError (builtin ^ ": drugi argument musi być funkcją"))

(* Generator liczb losowych - wspólny dla KARTA LUBI DYM i WYLOSUJ Z WERSALKI (jak ferdek_rng w C) *)
let rng_next () =
  if !rng_state < 0 then rng_state := int_of_float (Unix.gettimeofday () *. 1000.) land 0x7FFFFFFF;
  rng_state := (!rng_state * 1103515245 + 12345) land 0x7FFFFFFF;
  !rng_state

(* Równość jak w CZY LEŻY NA WERSALCE: liczby całkowite, teksty i prawda/fałsz *)
let same_element a b =
  match a, b with
  | VInt x, VInt y -> x = y
  | VString x, VString y -> x = y
  | VBool x, VBool y -> x = y
  | _ -> false

(* Argumenty builtinów przychodzą skompilowane (Value.code) - obliczenie to wywołanie *)
let eval_expr env (c : code) = c env
