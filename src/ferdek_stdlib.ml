(* Standard Library Functions for Ferdek *)

(* Type for builtin functions *)
type builtin_func = {
  name: string;
  arity: int option;  (* None = variadic *)
  category: string;   (* KANAPA, KIBEL, SKRZYNKA, KLATKA *)
}

(* Registry of all builtin functions *)
let builtins = [
  (* KANAPA (String operations) *)
  { name = "USIĄDŹ NA KANAPIE"; arity = None; category = "KANAPA" };
  { name = "ROZCIĄGNIJ KANAPĘ"; arity = Some 2; category = "KANAPA" };
  { name = "POTNIJ KANAPĘ"; arity = Some 3; category = "KANAPA" };
  { name = "PRZESUŃ NA KANAPIE"; arity = Some 2; category = "KANAPA" };
  { name = "POSKŁADAJ KANAPĘ"; arity = Some 2; category = "KANAPA" };
  { name = "WYTRZEP KANAPĘ"; arity = Some 1; category = "KANAPA" };
  { name = "ZAMIEŃ NA KANAPIE"; arity = Some 3; category = "KANAPA" };
  { name = "ILE MIEJSCA NA KANAPIE"; arity = Some 1; category = "KANAPA" };

  (* KIBEL (File operations) *)
  { name = "OTWÓRZ KIBEL"; arity = Some 1; category = "KIBEL" };
  { name = "ZAMKNIJ KIBEL"; arity = Some 1; category = "KIBEL" };
  { name = "SPUŚĆ WODĘ"; arity = Some 2; category = "KIBEL" };
  { name = "WYPOMPUJ"; arity = Some 1; category = "KIBEL" };
  { name = "CZY KIBEL ZAJĘTY"; arity = Some 1; category = "KIBEL" };
  { name = "OTWÓRZ KIBEL DO ZAPISU"; arity = Some 1; category = "KIBEL" };

  (* SKRZYNKA (Math operations) *)
  { name = "ILE W SKRZYNCE"; arity = Some 1; category = "SKRZYNKA" };
  { name = "POLICZ SKRZYNKI"; arity = Some 1; category = "SKRZYNKA" };
  { name = "ZAOKRĄGLIJ DO SKRZYNKI"; arity = Some 1; category = "SKRZYNKA" };
  { name = "OTWÓRZ SKRZYNKĘ"; arity = Some 1; category = "SKRZYNKA" };
  { name = "PODZIEL SKRZYNKI"; arity = Some 2; category = "SKRZYNKA" };
  { name = "RESZTA ZE SKRZYNKI"; arity = Some 2; category = "SKRZYNKA" };
  { name = "LOSUJ ZE SKRZYNKI"; arity = Some 1; category = "SKRZYNKA" };

  (* KLATKA (Network operations) *)
  { name = "WYJDŹ NA KLATKĘ"; arity = Some 1; category = "KLATKA" };
  { name = "ZAPUKAJ DO SĄSIADA"; arity = Some 2; category = "KLATKA" };
  { name = "KTO NA KLATCE"; arity = None; category = "KLATKA" };
  { name = "CZY SĄSIAD W DOMU"; arity = Some 1; category = "KLATKA" };
]

(* Check if function is builtin *)
let is_builtin name =
  List.exists (fun f -> f.name = name) builtins

(* Get builtin function info *)
let get_builtin name =
  List.find_opt (fun f -> f.name = name) builtins

(* Get all builtins in a category *)
let get_by_category category =
  List.filter (fun f -> f.category = category) builtins

(* Get list of all categories *)
let categories =
  List.fold_left (fun acc f ->
    if List.mem f.category acc then acc else acc @ [f.category]
  ) [] builtins

(* Pretty print builtin info *)
let string_of_builtin f =
  let arity_str = match f.arity with
    | None -> "variadic"
    | Some n -> Printf.sprintf "%d" n
  in
  Printf.sprintf "%s (%s args) [%s]" f.name arity_str f.category

(* Validate function call *)
let validate_call name arg_count =
  match get_builtin name with
  | None -> None
  | Some f ->
      match f.arity with
      | None -> Some true  (* Variadic - always valid *)
      | Some expected ->
          if arg_count = expected then Some true
          else Some false
