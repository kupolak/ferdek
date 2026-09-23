(* Wspólne komunikaty błędów *)

(* "1 argumentu", "2 argumentów" - dopełniacz po "oczekuje" *)
let argumentow n = Printf.sprintf "%d %s" n (if n = 1 then "argumentu" else "argumentów")

let wrong_arg_count func_name expected got =
  Printf.sprintf "%s oczekuje %s, podano %d" func_name (argumentow expected) got
