(* Error message helpers *)

(* Standardize error messages for function arguments *)
let wrong_arg_count func_name expected got =
  Printf.sprintf "%s expects %d argument(s), got %d" func_name expected got

let missing_arg func_name arg_type =
  Printf.sprintf "%s expects %s argument" func_name arg_type

let invalid_type func_name expected got =
  Printf.sprintf "%s expects %s, got %s" func_name expected got

(* Common error messages *)
let array_index_out_of_bounds =
  "Array index out of bounds"

let not_an_array =
  "Not an array"

let division_by_zero =
  "Division by zero"

let modulo_by_zero =
  "Modulo by zero"

let type_conversion_error typ =
  Printf.sprintf "Cannot convert to %s" typ

(* Standardize error raising *)
let raise_error msg = raise (Failure msg)

(* Combine with RuntimeError *)
type error = {
  message: string;
  location: string option;
  code: int option;
}

let make_error message =
  { message; location = None; code = None }

let string_of_error err =
  match err.location with
  | Some loc -> Printf.sprintf "Error at %s: %s" loc err.message
  | None -> Printf.sprintf "Error: %s" err.message
