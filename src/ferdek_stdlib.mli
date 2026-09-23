(* Rejestr wbudowanych funkcji interpretera *)

val builtins : (string list * int option) list

(* Some arity (None = dowolna liczba argumentów) dla builtina, None dla innych nazw *)
val find : string -> int option option
