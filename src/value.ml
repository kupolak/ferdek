(* Wartości w czasie wykonania, środowiska, konwersje i tabela builtinów interpretera *)

open Ast

(* ============ RUNTIME VALUES ============ *)

(* Runtime value types *)
type value =
  | VInt of int                                      (* Default 32-bit integer *)
  | VByte of int                                     (* 8-bit unsigned (0-255) *)
  | VShort of int                                    (* 16-bit integer *)
  | VFixed of int                                    (* 32-bit fixed-point 16.16 *)
  | VFloat of float                                  (* Liczba z przecinkiem *)
  | VString of string
  | VBool of bool
  | VNull
  | VArray of value array
  | VHashMap of (string, value) Hashtbl.t  (* SZAFKA - dictionaries/maps *)
  | VFunction of function_decl * environment
  | VClass of class_decl * environment       (* Class definition *)
  | VStruct of struct_decl * environment     (* Struct definition *)
  | VUnion of union_decl * environment       (* Union definition *)
  | VEnum of enum_decl * environment         (* Enum definition *)
  | VObject of (string, value) Hashtbl.t
  | VPointer of value ref                    (* Pointer/reference (PALCEM POKAZUJĘ) *)
  | VFileHandle of file_handle

and file_handle =
  | InputHandle of in_channel
  | OutputHandle of out_channel

and environment = {
  mutable vars: (string, value) Hashtbl.t;
  parent: environment option;
}

(* Plik i linia wykonywanej instrukcji - doklejane do komunikatu błędu *)
let current_loc = ref ("", 0)

let loc_suffix () =
  match !current_loc with
  | (_, 0) -> ""
  | ("", line) -> Printf.sprintf " (linia %d)" line
  | (file, line) -> Printf.sprintf " (%s, linia %d)" file line

(* Chwila startu programu - dla JEST TRZECIA W NOCY *)
let program_start = Unix.gettimeofday ()

(* Stan generatora liczb losowych; -1 = jeszcze nie zasiany (zasiewamy czasem) *)
let rng_state = ref (-1)

(* Runtime exceptions *)
exception RuntimeError of string
exception ReturnValue of value
exception BreakLoop
exception ContinueLoop
exception ThrowException of value

(* ============ ENVIRONMENT MANAGEMENT ============ *)

(* Create a new environment *)
let create_env parent =
  { vars = Hashtbl.create 16; parent }

(* Create the global environment *)
let global_env () =
  create_env None

(* Get variable from environment *)
let rec get_var env name =
  try
    Hashtbl.find env.vars name
  with Not_found ->
    match env.parent with
    | Some parent -> get_var parent name
    | None -> raise (RuntimeError (Printf.sprintf "Nieznana zmienna: %s" name))

(* Set variable in environment *)
let rec set_var env name value =
  if Hashtbl.mem env.vars name then
    Hashtbl.replace env.vars name value
  else
    match env.parent with
    | Some parent ->
        if Hashtbl.mem parent.vars name then
          set_var parent name value
        else
          Hashtbl.add env.vars name value
    | None ->
        Hashtbl.add env.vars name value

(* Define variable in current scope *)
let define_var env name value =
  Hashtbl.replace env.vars name value

(* ============ VALUE OPERATIONS ============ *)

(* Convert value to string *)
(* Liczba z przecinkiem jako tekst - ten sam format co runtime C (%.15g, "2.0" zamiast "2") *)
let string_of_float_ferdek f =
  let s = Printf.sprintf "%.15g" f in
  if String.exists (fun c -> c = '.' || c = 'e' || c = 'n') s then s else s ^ ".0"

let rec string_of_value = function
  | VFloat f -> string_of_float_ferdek f
  | VInt n -> string_of_int n
  | VByte n -> string_of_int n
  | VShort n -> string_of_int n
  | VFixed n -> string_of_int n
  | VString s -> s
  | VBool true -> "true"
  | VBool false -> "false"
  | VNull -> "null"
  | VArray arr ->
      "[" ^ String.concat ", " (Array.to_list (Array.map string_of_value arr)) ^ "]"
  | VHashMap tbl ->
      (* Klucze posortowane: kolejność z Hashtbl zależy od hasza i nie da się jej powtórzyć w C *)
      let keys = Builtins_hashmap.szafka_wszystkie_szufladki tbl in
      let pairs = List.map (fun k -> k ^ ": " ^ string_of_value (Hashtbl.find tbl k)) keys in
      "{" ^ String.concat ", " pairs ^ "}"
  | VFunction (fdecl, _) ->
      Printf.sprintf "<function %s>" fdecl.name
  | VClass (cdecl, _) ->
      Printf.sprintf "<class %s>" cdecl.name
  | VStruct (sdecl, _) ->
      Printf.sprintf "<struct %s>" sdecl.name
  | VUnion (udecl, _) ->
      Printf.sprintf "<union %s>" udecl.name
  | VEnum (edecl, _) ->
      Printf.sprintf "<enum %s>" edecl.name
  | VObject _ ->
      "<object>"
  | VPointer r ->
      Printf.sprintf "<pointer to %s>" (string_of_value !r)
  | VFileHandle _ ->
      "<file handle>"

(* Convert value to boolean *)
let to_bool = function
  | VBool b -> b
  | VInt 0 -> false
  | VInt _ -> true
  | VByte 0 -> false
  | VByte _ -> true
  | VShort 0 -> false
  | VShort _ -> true
  | VFixed 0 -> false
  | VFixed _ -> true
  | VFloat f -> f <> 0.0
  | VString "" -> false
  | VString _ -> true
  | VNull -> false
  | _ -> true

(* Convert value to integer *)
(* Tekst jako liczba: tylko zapis dziesiętny ("-12"), jak w runtime C.
   int_of_string przyjąłby też 0x1F, 0b101, 1_000 - a C nie. *)
let decimal_of_string s =
  let n = String.length s in
  let start = if n > 0 && s.[0] = '-' then 1 else 0 in
  if n = start then None
  else if String.for_all (fun c -> c >= '0' && c <= '9') (String.sub s start (n - start))
  then int_of_string_opt s
  else None

let is_numeric = function
  | VString s -> decimal_of_string s <> None
  | _ -> true

let to_int = function
  | VInt n -> n
  | VByte n -> n
  | VShort n -> n
  | VFixed n -> n  (* Return raw fixed-point value *)
  | VBool true -> 1
  | VBool false -> 0
  | VString s ->
      (match decimal_of_string s with
       | Some n -> n
       | None -> raise (RuntimeError (Printf.sprintf "Tekst \"%s\" to nie liczba" s)))
  | VNull -> 0
  | VFloat _ -> raise (RuntimeError "Liczba z przecinkiem tam, gdzie trzeba całkowitej (użyj ZRÓB DŁUGI)")
  | _ -> raise (RuntimeError "Tego nie da się zamienić na liczbę")

let is_float = function VFloat _ -> true | _ -> false
let to_float = function VFloat f -> f | v -> float_of_int (to_int v)

(* Convert value to string for concatenation *)
let to_string = function
  | VInt n -> string_of_int n
  | VByte n -> string_of_int n
  | VShort n -> string_of_int n
  | VFixed n -> string_of_int n  (* Show raw fixed value *)
  | VFloat f -> string_of_float_ferdek f
  | VString s -> s
  | VBool true -> "true"
  | VBool false -> "false"
  | VNull -> "null"
  | v -> string_of_value v

(* ============ EXPRESSION EVALUATION ============ *)

(* Evaluate arithmetic operator *)
let eval_arith_op op v1 v2 =
  match op, v1, v2 with
  (* + z tekstem po którejkolwiek stronie skleja *)
  | Plus, VString _, _ | Plus, _, VString _ -> VString (to_string v1 ^ to_string v2)
  (* Przecinek po którejkolwiek stronie = wynik z przecinkiem *)
  | _ when is_float v1 || is_float v2 ->
      let a = to_float v1 and b = to_float v2 in
      VFloat (match op with
        | Plus -> a +. b
        | Minus -> a -. b
        | Multiply -> a *. b
        | Divide -> if b = 0.0 then raise (RuntimeError "Dzielenie przez zero") else a /. b
        | Modulo -> if b = 0.0 then raise (RuntimeError "Reszta z dzielenia przez zero") else Float.rem a b)
  | _ ->
  let n1 = to_int v1 in
  let n2 = to_int v2 in
  VInt (match op with
    | Plus -> n1 + n2
    | Minus -> n1 - n2
    | Multiply -> n1 * n2
    | Divide ->
        if n2 = 0 then raise (RuntimeError "Dzielenie przez zero")
        else n1 / n2
    | Modulo ->
        if n2 = 0 then raise (RuntimeError "Reszta z dzielenia przez zero")
        else n1 mod n2
  )

(* Evaluate comparison operator *)
(* Porównanie trójwartościowe (<0, 0, >0). Stringi jako tekst. Tekst z liczbą: przy
   równości po prostu różne, przy porządku błąd - chyba że tekst jest liczbą ("5") *)
let compare_values ?(equality = false) v1 v2 =
  match v1, v2 with
  | VString a, VString b -> compare a b
  | _ when is_numeric v1 && is_numeric v2 && (is_float v1 || is_float v2) ->
      compare (to_float v1) (to_float v2)
  | _ when is_numeric v1 && is_numeric v2 -> compare (to_int v1) (to_int v2)
  | _ when equality -> 1
  | _ -> raise (RuntimeError "Nie można porównać tekstu z liczbą")

let eval_comparison_op op v1 v2 =
  let c = compare_values ~equality:(op = Equal || op = NotEqual) v1 v2 in
  VBool (match op with
    | Equal -> c = 0
    | NotEqual -> c <> 0
    | Greater -> c > 0
    | Less -> c < 0
    | GreaterEqual -> c >= 0
  )

(* Evaluate logical operator *)
let eval_logical_op op v1 v2 =
  let b1 = to_bool v1 in
  let b2 = to_bool v2 in
  VBool (match op with
    | And -> b1 && b2
    | Or -> b1 || b2
  )

(* Evaluate bitwise operator *)
let eval_bitwise_op op v1 v2 =
  let n1 = to_int v1 in
  let n2 = to_int v2 in
  VInt (match op with
    | BitAnd -> n1 land n2
    | BitOr -> n1 lor n2
    | BitXor -> n1 lxor n2
    | BitShiftLeft -> n1 lsl n2
    | BitShiftRight -> n1 lsr n2
  )

(* Tabela wbudowanych funkcji - wypełniana po definicji eval_expr (sekcja BUILTINS) *)
let builtins : (string, int option * (environment -> expr list -> value)) Hashtbl.t = Hashtbl.create 128

(* Nazwy i liczba argumentów wszystkich builtinów - dla ferdek --check *)
let builtin_arities () = Hashtbl.fold (fun n (a, _) acc -> (n, a) :: acc) builtins []

