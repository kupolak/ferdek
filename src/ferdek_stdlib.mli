(* Standard Library Functions Interface *)

(* Type for builtin functions *)
type builtin_func = {
  name: string;
  arity: int option;  (* None = variadic *)
  category: string;   (* KANAPA, KIBEL, SKRZYNKA, KLATKA *)
}

(* Check if function is builtin *)
val is_builtin : string -> bool

(* Get builtin function info *)
val get_builtin : string -> builtin_func option

(* Get all builtins in a category *)
val get_by_category : string -> builtin_func list

(* Get list of all categories *)
val categories : string list

(* Pretty print builtin info *)
val string_of_builtin : builtin_func -> string

(* Validate function call *)
val validate_call : string -> int -> bool option
