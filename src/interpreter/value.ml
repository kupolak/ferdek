(* Wartości w czasie wykonania, środowiska, konwersje i tabela builtinów interpretera *)

open Ast

(* ============ RUNTIME VALUES ============ *)

(* Zmienne i pola obiektów: tablica z kluczem tekstowym. Własna, bo przy odczycie zmiennej hasz
   liczymy raz i używamy go na każdym poziomie środowiska (Hashtbl liczyłby go od nowa, a do tego
   porównuje klucze polimorficznym compare). Ta sama tablica służy za pola obiektu. *)
module Vars = struct
  (* cell: jeden wpis; przy powiększaniu tablicy przepinamy te same komórki, więc skompilowany
     kod (Eval) może trzymać komórkę zmiennej i czytać ją bez szukania *)
  type 'a bucket = Empty | Cons of 'a cell
  and 'a cell = { key : string; hash : int; mutable data : 'a; mutable next : 'a bucket }
  type 'a t = { mutable size : int; mutable buckets : 'a bucket array }

  (* nazwy są krótkie - pętla w OCamlu jest tańsza niż wywołanie caml_hash *)
  let hash s =
    let h = ref 5381 in
    for i = 0 to String.length s - 1 do
      h := !h * 33 + Char.code (String.unsafe_get s i)
    done;
    !h land max_int

  let create n =
    let rec pow2 k = if k >= n then k else pow2 (2 * k) in
    { size = 0; buckets = Array.make (pow2 1) Empty }
  let index t h = h land (Array.length t.buckets - 1)
  let is_empty t = t.size = 0

  let rec cell_in key h = function
    | Empty -> None
    | Cons c -> if c.hash = h && String.equal c.key key then Some c else cell_in key h c.next

  let find_cell_h t key h = cell_in key h t.buckets.(index t h)

  let rec find_in key h = function
    | Empty -> None
    | Cons c -> if c.hash = h && String.equal c.key key then Some c.data else find_in key h c.next

  let find_h t key h = find_in key h t.buckets.(index t h)
  let find_opt t key = find_h t key (hash key)
  let mem_h t key h = find_cell_h t key h <> None
  let mem t key = mem_h t key (hash key)

  let resize t =
    let old = t.buckets in
    t.buckets <- Array.make (2 * Array.length old) Empty;
    let rec move = function
      | Empty -> ()
      | Cons c as b ->
          let rest = c.next in
          let i = index t c.hash in
          c.next <- t.buckets.(i);
          t.buckets.(i) <- b;
          move rest in
    Array.iter move old

  (* Zmienia istniejący wpis albo dodaje nowy *)
  let replace_h t key h data =
    match find_cell_h t key h with
    | Some c -> c.data <- data
    | None ->
        if t.size >= 2 * Array.length t.buckets then resize t;
        let i = index t h in
        t.buckets.(i) <- Cons { key; hash = h; data; next = t.buckets.(i) };
        t.size <- t.size + 1

  let replace t key data = replace_h t key (hash key) data

  let fold f t acc =
    let rec go acc = function Empty -> acc | Cons c -> go (f c.key c.data acc) c.next in
    Array.fold_left go acc t.buckets

  (* Kopia z nowymi komórkami - zmiana w kopii nie rusza oryginału *)
  let copy t =
    let rec dup = function Empty -> Empty | Cons c -> Cons { c with next = dup c.next } in
    { size = t.size; buckets = Array.map dup t.buckets }
end

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
  | VObject of value Vars.t
  | VPointer of value ref                    (* Pointer/reference (PALCEM POKAZUJĘ) *)
  | VFileHandle of file_handle

and file_handle =
  | InputHandle of in_channel
  | OutputHandle of out_channel

(* Środowisko: zmienne po nazwie (vars) i - w wywołaniu funkcji - zmienne funkcji w slotach.
   layout: nazwa -> numer slotu, wspólny dla wszystkich wywołań tej funkcji (Eval liczy go raz).
   Pusty slot (unset) znaczy "jeszcze nie zdefiniowana tutaj" - wtedy szukamy dalej po nazwie,
   dokładnie jak wcześniej w samych tablicach. *)
and environment = {
  mutable vars: value Vars.t;
  parent: environment option;
  slots: value array;
  layout: int Vars.t;
}

(* Plik i linia wykonywanej instrukcji - doklejane do komunikatu błędu. Trzymamy numer miejsca
   z tabeli (loc_id), bo zapis liczby przy każdej instrukcji nie przechodzi przez barierę
   odśmiecacza, a zapis pary (plik, linia) tak. *)
let locs = ref [| ("", 0) |]
let loc_count = ref 1
let loc_ids : (string * int, int) Hashtbl.t = Hashtbl.create 64
let loc_id = ref 0

(* Numer miejsca (ten sam dla tej samej pary) *)
let register_loc loc =
  match Hashtbl.find_opt loc_ids loc with
  | Some id -> id
  | None ->
      if !loc_count = Array.length !locs then
        locs := Array.append !locs (Array.make (Array.length !locs) ("", 0));
      let id = !loc_count in
      !locs.(id) <- loc;
      incr loc_count;
      Hashtbl.replace loc_ids loc id;
      id

let current_loc () = !locs.(!loc_id)
let set_loc loc = loc_id := register_loc loc

let loc_suffix () =
  match current_loc () with
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
(* Błąd, którego HELENA MAM ZAWAŁ nie łapie (break/continue poza pętlą w funkcji) - jak ferdek_fatal w C *)
exception Fatal of string

(* Ścieżka wywołań: (funkcja, miejsce wywołania), od najgłębszej. Przy błędzie zostaje taka, jaka
   była w chwili błędu; HELENA MAM ZAWAŁ przywraca ją do stanu z wejścia do bloku. *)
let call_stack : (string * (string * int)) list ref = ref []

(* Wejście dla CO TAM U PANA SŁYCHAĆ: linia bez końca linii, End_of_file na końcu.
   ferdek --dap podmienia je na tekst z konfiguracji (stdin to tam protokół). *)
let read_input : (unit -> string) ref = ref read_line

(* Debugger (ferdek --debug): wołany przed każdą instrukcją z plikiem, linią i środowiskiem *)
let stmt_hook : (string -> int -> environment -> unit) option ref = ref None

(* ============ ENVIRONMENT MANAGEMENT ============ *)

(* Wartość pustego slotu - porównujemy fizycznie (==), nigdy nie wychodzi poza środowisko *)
let unset = VString "(unset)"

(* Wspólny pusty układ dla środowisk bez slotów (globalne, obiekt, catch) - nigdy nie zmieniany *)
let no_layout : int Vars.t = Vars.create 1

(* Wspólna pusta tablica zmiennych wywołania funkcji: prawdziwą zakładamy dopiero przy pierwszej
   zmiennej spoza slotów (define_var_h) - zwykle nigdy *)
let no_vars : value Vars.t = Vars.create 1

(* Create a new environment *)
let create_env parent =
  { vars = Vars.create 8; parent; slots = [||]; layout = no_layout }

(* Create the global environment *)
let global_env () =
  create_env None

(* Klucz, po którym apply_function poznaje złapane zmienne lambdy (nazwa zmiennej tak wyglądać nie może) *)
let lambda_marker = "(lambda)"

(* Liczba z przecinkiem -> całkowita (obcięcie). Poza zakresem int (±2^62) i NaN to błąd, a nie
   przypadkowa wartość - tak samo robi float_to_int w C *)
let float_to_int what f =
  if Float.is_nan f || f >= 4611686018427387904. || f < -4611686018427387904. then
    raise (RuntimeError (what ^ ": liczba za duża, żeby zrobić z niej całkowitą"))
  else int_of_float f

(* Typy: czy wartość pasuje i jak ją nazwać w błędzie - te same słowa co check_type w C *)
let value_kind = function
  | VInt _ -> "liczba całkowita" | VFloat _ -> "liczba z przecinkiem" | VString _ -> "tekst"
  | VBool _ -> "prawda/fałsz" | VNull -> "nic" | VArray _ -> "tablica" | VHashMap _ -> "szafka"
  | VFunction _ -> "funkcja" | VByte _ -> "bajcik" | VShort _ -> "krótki" | VFixed _ -> "ułamek"
  | VObject _ -> "obiekt" | VPointer _ -> "wskaźnik" | VFileHandle _ -> "kibel (plik)"
  | VClass _ | VStruct _ | VUnion _ | VEnum _ -> "definicja typu"

let check_type v t what =
  let ok = match t, v with
    | TInt, VInt _ | TFloat, VFloat _ | TString, VString _ | TBool, VBool _
    | TArray, VArray _ | TMap, VHashMap _ | TFunction, VFunction _ -> true
    | _ -> false in
  if not ok then
    raise (RuntimeError (Printf.sprintf "%s: %s, a jest %s" what (string_of_typ t) (value_kind v)));
  v

(* Zmienna zdefiniowana w tym środowisku (slot albo tablica), bez rodziców *)
let local_opt_h env name h =
  match Vars.find_h env.layout name h with
  | Some i when env.slots.(i) != unset -> Some env.slots.(i)
  | _ -> Vars.find_h env.vars name h

let local_opt env name = local_opt_h env name (Vars.hash name)

(* Zmienne tego środowiska (bez rodziców) - dla debuggera *)
let local_bindings env =
  Vars.fold (fun n i acc -> if env.slots.(i) != unset then (n, env.slots.(i)) :: acc else acc) env.layout
    (Vars.fold (fun n v acc -> if Vars.mem env.layout n && env.slots.(Option.get (Vars.find_opt env.layout n)) != unset
                               then acc else (n, v) :: acc) env.vars [])

(* Wszystkie nazwy widoczne ze środowiska - do podpowiedzi przy literówce *)
let rec visible_names env =
  List.filter_map (fun (n, _) -> if n = "(lambda)" then None else Some n) (local_bindings env)
  @ (match env.parent with Some p -> visible_names p | None -> [])

let get_var_h env name h =
  let rec go e =
    match local_opt_h e name h with
    | Some v -> v
    | None ->
        match e.parent with
        | Some parent -> go parent
        | None -> raise (RuntimeError (Errors.unknown "zmienna" name (visible_names env))) in
  go env

let get_var env name = get_var_h env name (Vars.hash name)

(* Define variable in current scope *)
let define_var_h env name h value =
  match Vars.find_h env.layout name h with
  | Some i -> env.slots.(i) <- value
  | None ->
      if env.vars == no_vars then env.vars <- Vars.create 8;
      Vars.replace_h env.vars name h value

let define_var env name value = define_var_h env name (Vars.hash name) value

(* Zmiana wartości już zdefiniowanej tutaj zmiennej; false, gdy jej tu nie ma *)
let update_local_h env name h value =
  match Vars.find_h env.layout name h with
  | Some i when env.slots.(i) != unset -> env.slots.(i) <- value; true
  | _ ->
      match Vars.find_cell_h env.vars name h with
      | Some c -> c.data <- value; true
      | None -> false

(* Set variable in environment: tutaj, jeśli jest; u rodzica, jeśli tam jest; inaczej nowa tutaj *)
let set_var_h env name h value =
  if not (update_local_h env name h value) then
    match env.parent with
    | Some parent when update_local_h parent name h value -> ()
    | _ -> define_var_h env name h value

let set_var env name value = set_var_h env name (Vars.hash name) value

(* ============ VALUE OPERATIONS ============ *)


(* Convert value to string *)
(* Liczba z przecinkiem jako tekst - ten sam format co runtime C (%.15g, "2.0" zamiast "2") *)
let string_of_float_ferdek f =
  let s = Printf.sprintf "%.15g" f in
  if String.exists (fun c -> c = '.' || c = 'e' || c = 'n') s then s else s ^ ".0"

(* Liczba całkowita jako tekst - to samo co string_of_int, ale bez printf z biblioteki C (przy
   sklejaniu tekstu z liczbą w pętli to była większość czasu). Na ujemnych, żeby min_int też działał. *)
let int_to_string n =
  if n >= 0 && n < 10 then String.make 1 (Char.unsafe_chr (48 + n))
  else begin
    let buf = Bytes.create 20 in
    let pos = ref 20 and m = ref (if n < 0 then n else - n) in
    while !m <> 0 do
      decr pos;
      Bytes.unsafe_set buf !pos (Char.unsafe_chr (48 - (!m mod 10)));
      m := !m / 10
    done;
    if n < 0 then (decr pos; Bytes.unsafe_set buf !pos '-');
    Bytes.sub_string buf !pos (20 - !pos)
  end

let rec string_of_value = function
  | VFloat f -> string_of_float_ferdek f
  | VInt n -> int_to_string n
  | VByte n -> int_to_string n
  | VShort n -> int_to_string n
  | VFixed n -> int_to_string n
  | VString s -> s
  | VBool true -> "true"
  | VBool false -> "false"
  | VNull -> "null"
  | VArray arr ->
      "[" ^ String.concat ", " (Array.to_list (Array.map string_of_value arr)) ^ "]"
  | VHashMap tbl ->
      (* Klucze posortowane: kolejność z Hashtbl zależy od hasza i nie da się jej powtórzyć w C *)
      let keys = Map_utils.szafka_wszystkie_szufladki tbl in
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
  | VInt n -> int_to_string n
  | VByte n -> int_to_string n
  | VShort n -> int_to_string n
  | VFixed n -> int_to_string n  (* Show raw fixed value *)
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
  (* najczęstszy przypadek - od razu, bez sprawdzania tekstu i przecinka *)
  | Plus, VInt a, VInt b -> VInt (a + b)
  | Minus, VInt a, VInt b -> VInt (a - b)
  | Multiply, VInt a, VInt b -> VInt (a * b)
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
  let c = match v1, v2 with
    | VInt a, VInt b -> Int.compare a b
    | _ -> compare_values ~equality:(match op with Equal | NotEqual -> true | _ -> false) v1 v2 in
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
    (* poza 0..62 OCaml daje przypadkowy wynik - jak w C: błąd *)
    | BitShiftLeft | BitShiftRight when n2 < 0 || n2 > 62 ->
        raise (RuntimeError (Printf.sprintf "Przesunięcie o %d bitów - można od 0 do 62" n2))
    | BitShiftLeft -> n1 lsl n2
    | BitShiftRight -> n1 lsr n2
  )

(* Tabela wbudowanych funkcji - wypełniana po definicji eval_expr (sekcja BUILTINS) *)
(* Skompilowane wyrażenie (Eval): wartość w danym środowisku. Builtiny dostają argumenty w tej postaci. *)
type code = environment -> value

let builtins : (int option * (environment -> code list -> value)) Vars.t = Vars.create 128

(* Nazwy i liczba argumentów wszystkich builtinów - dla ferdek --check *)
let builtin_arities () = Vars.fold (fun n (a, _) acc -> (n, a) :: acc) builtins []

