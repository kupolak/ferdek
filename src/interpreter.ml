(* Interpreter for Ferdek Programming Language *)

open Ast

(* ============ EXTERNAL BINDINGS FOR GRAPHICS (X11) ============ *)

external ferdek_window_open : int -> int -> string -> int = "caml_ferdek_window_open"
external ferdek_window_close : unit -> unit = "caml_ferdek_window_close"
external ferdek_palette_set : bytes -> unit = "caml_ferdek_palette_set"
external ferdek_pixel_draw : int -> int -> int -> unit = "caml_ferdek_pixel_draw"
external ferdek_screen_refresh : unit -> unit = "caml_ferdek_screen_refresh"
external ferdek_screen_clear : int -> unit = "caml_ferdek_screen_clear"
external ferdek_framebuffer_get : int -> int -> int = "caml_ferdek_framebuffer_get"
external ferdek_event_poll : unit -> (int * int * int * int) = "caml_ferdek_event_poll"

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

(* ============ ZONE ALLOCATOR (DOOM-style Memory Management) ============ *)

(* Memory tags (like DOOM's PU_* tags) *)
type memory_tag =
  | TAG_TRWALE      (* PU_STATIC = 1 - never freed *)
  | TAG_POZIOM      (* PU_LEVEL = 50 - level data *)
  | TAG_SMIECIOWE   (* PU_CACHE = 100 - can be freed anytime *)

let tag_to_int = function
  | TAG_TRWALE -> 1
  | TAG_POZIOM -> 50
  | TAG_SMIECIOWE -> 100

let int_to_tag n =
  if n <= 1 then TAG_TRWALE
  else if n <= 50 then TAG_POZIOM
  else TAG_SMIECIOWE

(* Memory block structure *)
type memory_block = {
  mutable size: int;
  mutable tag: memory_tag;
  mutable data: value array;
  mutable id: int;
}

(* Global zone allocator state *)
let zone_blocks : (int, memory_block) Hashtbl.t = Hashtbl.create 128
let next_block_id = ref 0
let total_allocated = ref 0
let total_freed = ref 0

(* ============ FRAMEBUFFER & DIRECT MEMORY ACCESS ============ *)

(* Framebuffer structure (like DOOM's screens[]) *)
type framebuffer = {
  mutable width: int;
  mutable height: int;
  mutable pixels: int array;  (* Pixel data - array of color values *)
  mutable id: int;
}

(* Lookup table structure (like DOOM's ylookup[], columnofs[]) *)
type lookup_table = {
  mutable data: int array;
  mutable size: int;
  mutable id: int;
}

(* Global framebuffer and lookup table state *)
let framebuffers : (int, framebuffer) Hashtbl.t = Hashtbl.create 16
let lookup_tables : (int, lookup_table) Hashtbl.t = Hashtbl.create 16
let next_fb_id = ref 0
let next_table_id = ref 0

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

(* Evaluate expression *)
let rec eval_expr env = function
  | IntLiteral n -> VInt n
  | FloatLiteral f -> VFloat f
  | StringLiteral s -> VString s
  | BoolLiteral b -> VBool b
  | NullLiteral -> VNull
  | Identifier name -> get_var env name
  | BinaryOp (e1, op, e2) ->
      let v1 = eval_expr env e1 in
      let v2 = eval_expr env e2 in
      eval_arith_op op v1 v2
  | ComparisonOp (e1, op, e2) ->
      let v1 = eval_expr env e1 in
      let v2 = eval_expr env e2 in
      eval_comparison_op op v1 v2
  | LogicalOp (e1, op, e2) ->
      let v1 = eval_expr env e1 in
      let v2 = eval_expr env e2 in
      eval_logical_op op v1 v2
  | BitwiseOp (e1, op, e2) ->
      let v1 = eval_expr env e1 in
      let v2 = eval_expr env e2 in
      eval_bitwise_op op v1 v2
  | BitwiseNot e ->
      let v = eval_expr env e in
      let n = to_int v in
      VInt (lnot n)
  | LogicalNot e ->
      VBool (not (to_bool (eval_expr env e)))
  | ArrayLiteral es ->
      (* Nowa tablica przy każdym obliczeniu - literał w pętli nie jest współdzielony *)
      VArray (Array.of_list (List.map (eval_expr env) es))
  | ToFixed e ->
      (* Convert integer to fixed-point 16.16 format *)
      (match eval_expr env e with
       | VFloat f -> VInt (int_of_float (f *. 65536.))
       | v -> VInt (to_int v lsl 16))
  | FromFixed e ->
      (* Convert from fixed-point 16.16 format to integer *)
      let v = eval_expr env e in
      let n = to_int v in
      VInt (n lsr 16)
  | ArrayAccess (arr_expr, index_expr) ->
      let value = eval_expr env arr_expr in
      (match value with
       | VArray arr ->
           let index = to_int (eval_expr env index_expr) in
           if index < 0 || index >= Array.length arr then
             raise (RuntimeError "Indeks tablicy poza zakresem")
           else
             arr.(index)
       | VObject obj ->
           (* Support object field access: obj["field_name"] *)
           let field_name = match eval_expr env index_expr with
             | VString s -> s
             | VInt i -> string_of_int i
             | v -> raise (RuntimeError (Printf.sprintf "Nazwa pola obiektu musi być tekstem, a jest: %s" (string_of_value v)))
           in
           (match Hashtbl.find_opt obj field_name with
            | Some v -> v
            | None -> raise (RuntimeError (Printf.sprintf "Obiekt nie ma pola: %s" field_name)))
       | _ -> raise (RuntimeError "To nie jest tablica ani obiekt"))
  | FunctionCall (name, args) ->
      eval_function_call env name args
  | NewObject (class_name, args) ->
      eval_new_object env class_name args
  | NewStruct struct_name ->
      eval_new_struct env struct_name
  | NewUnion union_name ->
      eval_new_union env union_name
  | Reference e ->
      (* Create a reference to the evaluated expression *)
      (* Special case: if e is an Identifier referring to a function, return the function itself *)
      (match e with
       | Identifier name ->
           (try
             let value = get_var env name in
             (match value with
              | VFunction _ -> value  (* Function pointer - return function itself *)
              | _ -> VPointer (ref value))  (* Regular value - create pointer *)
           with RuntimeError _ ->
             raise (RuntimeError (Printf.sprintf "Nieznana zmienna: %s" name)))
       | _ ->
           (* For other expressions, evaluate and create pointer *)
           let value = eval_expr env e in
           VPointer (ref value))
  | Dereference e ->
      (* Dereference a pointer *)
      (match eval_expr env e with
       | VPointer r -> !r
       | _ -> raise (RuntimeError "CO TAM JEST: to nie jest wskaźnik"))
  | AddressOf var_name ->
      (* Get address/reference to a variable *)
      (try
        let value = get_var env var_name in
        VPointer (ref value)
      with RuntimeError _ ->
        raise (RuntimeError (Printf.sprintf "Nieznana zmienna: %s" var_name)))
  | PointerArithmetic (e1, op, e2) ->
      (* Pointer arithmetic - mainly for array/buffer access *)
      let ptr = eval_expr env e1 in
      let offset = eval_expr env e2 in
      (match ptr, offset with
       | VPointer r, VInt n ->
           (* For now, just return the pointer - proper array arithmetic would need array context *)
           VPointer r
       | VInt base, VInt n ->
           (* Integer arithmetic fallback *)
           (match op with
            | Plus -> VInt (base + n)
            | Minus -> VInt (base - n)
            | _ -> raise (RuntimeError "Tego działania nie da się wykonać na wskaźniku"))
       | _ -> raise (RuntimeError "Nieprawidłowe działanie na wskaźniku"))
  | FunctionRef func_name ->
      (* Create a function pointer - get the function and return it as a value *)
      (try
        let func_val = get_var env func_name in
        match func_val with
        | VFunction _ -> func_val  (* Return the function itself as a value *)
        | _ -> raise (RuntimeError (Printf.sprintf "%s to nie funkcja" func_name))
      with RuntimeError _ ->
        raise (RuntimeError (Printf.sprintf "Nieznana funkcja: %s" func_name)))
  | Parenthesized e -> eval_expr env e
  | Lambda (params, body) ->
      (* Zmienne lokalne (spoza środowiska globalnego) kopiujemy w chwili utworzenia - tak samo
         robi kompilator do C; globalne lambda widzi na żywo *)
      let rec root e = match e.parent with Some p -> root p | None -> e in
      let global = root env in
      let captured = create_env (Some global) in
      let rec capture e n =
        if e != global then
          match Hashtbl.find_opt e.vars n with
          | Some v -> Hashtbl.replace captured.vars n v
          | None -> Option.iter (fun p -> capture p n) e.parent in
      List.iter (capture env) (List.filter (fun n -> not (List.mem n params)) (expr_names body));
      VFunction ({ name = "anonimowa"; params; is_variadic = false; has_return = true;
                   body = [Return (Some body)] }, captured)

(* Evaluate function call *)
and eval_function_call env name args =
  match Hashtbl.find_opt builtins name with
  | Some (arity, impl) ->
      (match arity with
       | Some n when n <> List.length args ->
           raise (RuntimeError (Errors.wrong_arg_count name n (List.length args)))
       | _ -> ());
      impl env args
  | None ->
      (* Funkcja użytkownika (także trzymana w zmiennej) *)
      (match get_var env name with
       | VFunction (fdecl, closure_env) ->
           apply_function name fdecl closure_env (List.map (eval_expr env) args)
       | _ -> raise (RuntimeError (Printf.sprintf "%s to nie funkcja" name)))

(* Wywołanie funkcji użytkownika z gotowymi wartościami argumentów (też z builtinów, np. sortowania) *)
and apply_function name (fdecl : function_decl) closure_env arg_values =
    let func_env = create_env (Some closure_env) in
    (* Bind parameters *)
    let num_params = List.length fdecl.params in
    let num_args = List.length arg_values in

    if fdecl.is_variadic then begin
      (* Variadic function - must have at least as many args as fixed params *)
      if num_args < num_params then
        raise (RuntimeError (Printf.sprintf "Funkcja %s oczekuje co najmniej %s, podano %d"
                              name (Errors.argumentow num_params) num_args));

      (* Bind fixed parameters *)
      let fixed_args, var_args =
        let rec split n lst =
          if n = 0 then ([], lst)
          else match lst with
            | [] -> ([], [])
            | x::xs -> let (a, b) = split (n-1) xs in (x::a, b)
        in split num_params arg_values
      in
      List.iter2 (fun param value -> define_var func_env param value)
        fdecl.params fixed_args;

      (* Store variadic args as varargs array *)
      define_var func_env "varargs" (VArray (Array.of_list var_args));
    end else begin
      (* Non-variadic function - exact match required *)
      if num_params <> num_args then
        raise (RuntimeError (Printf.sprintf "Funkcja %s oczekuje %s, podano %d"
                              name (Errors.argumentow num_params) num_args));

      List.iter2 (fun param value -> define_var func_env param value)
        fdecl.params arg_values;
    end;

    (* Execute function body; po powrocie pozycja wraca do instrukcji wołającej *)
    let caller_loc = !current_loc in
    let result =
      (try
        List.iter (eval_stmt func_env) fdecl.body;
        VNull (* No explicit return *)
      with
      | ReturnValue v -> v
      (* break/continue nie wyskakują z funkcji do pętli, która ją wywołała *)
      | BreakLoop -> raise (RuntimeError "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ poza pętlą")
      | ContinueLoop -> raise (RuntimeError "AKUKARACZA poza pętlą"))
    in
    current_loc := caller_loc;
    result

(* Evaluate object creation *)
and eval_new_object env class_name args =
  (* Look up class definition *)
  try
    let class_val = get_var env class_name in
    match class_val with
    | VClass (cdecl, class_env) ->
        (* Create new object with fields *)
        let obj = Hashtbl.create 16 in

        (* First, inherit fields and methods from parent class if exists *)
        (match cdecl.parent_class with
         | Some parent_name ->
             (try
               let parent_val = get_var env parent_name in
               match parent_val with
               | VClass (parent_cdecl, parent_env) ->
                   (* Copy parent fields *)
                   List.iter (fun (field_name, init_expr) ->
                     let field_value = eval_expr parent_env init_expr in
                     Hashtbl.replace obj field_name field_value
                   ) parent_cdecl.fields;
                   (* Copy parent methods *)
                   List.iter (fun (method_decl : function_decl) ->
                     let method_env = { vars = obj; parent = Some parent_env } in
                     Hashtbl.replace obj method_decl.name (VFunction (method_decl, method_env))
                   ) parent_cdecl.methods
               | _ -> raise (RuntimeError (Printf.sprintf "Klasa bazowa %s to nie klasa" parent_name))
             with RuntimeError _ ->
               raise (RuntimeError (Printf.sprintf "Nieznana klasa bazowa: %s" parent_name)))
         | None -> ());

        (* Initialize fields from class definition (may override parent fields) *)
        List.iter (fun (field_name, init_expr) ->
          let field_value = eval_expr class_env init_expr in
          Hashtbl.replace obj field_name field_value
        ) cdecl.fields;

        (* Add methods to object (may override parent methods) *)
        (* Metody współdzielą tablicę pól z obiektem - widzą bieżące wartości pól *)
        List.iter (fun (method_decl : function_decl) ->
          let method_env = { vars = obj; parent = Some class_env } in
          Hashtbl.replace obj method_decl.name (VFunction (method_decl, method_env))
        ) cdecl.methods;

        VObject obj
    | _ ->
        raise (RuntimeError (Printf.sprintf "%s to nie klasa" class_name))
  with RuntimeError _ ->
    raise (RuntimeError (Printf.sprintf "Nieznana klasa: %s" class_name))

(* Evaluate struct instantiation *)
and eval_new_struct env struct_name =
  (* Look up struct definition *)
  try
    let struct_val = get_var env struct_name in
    match struct_val with
    | VStruct (sdecl, struct_env) ->
        (* Create new object with fields from struct definition *)
        let obj = Hashtbl.create 16 in

        (* Initialize fields from struct definition *)
        List.iter (fun (field_name, init_expr) ->
          let field_value = eval_expr struct_env init_expr in
          Hashtbl.replace obj field_name field_value
        ) sdecl.fields;

        VObject obj
    | _ ->
        raise (RuntimeError (Printf.sprintf "%s to nie struktura" struct_name))
  with RuntimeError _ ->
    raise (RuntimeError (Printf.sprintf "Nieznana struktura: %s" struct_name))

(* Evaluate new union instantiation *)
and eval_new_union env union_name =
  (* Look up union definition *)
  try
    let union_val = get_var env union_name in
    match union_val with
    | VUnion (udecl, union_env) ->
        (* Create new object with fields from union definition *)
        (* In a union, all fields share the same memory, so we initialize with first field only *)
        let obj = Hashtbl.create 16 in

        (* Initialize only the first field (union behavior) *)
        (match udecl.fields with
         | (field_name, init_expr) :: _ ->
             let field_value = eval_expr union_env init_expr in
             Hashtbl.replace obj field_name field_value
         | [] -> ());

        VObject obj
    | _ ->
        raise (RuntimeError (Printf.sprintf "%s to nie unia" union_name))
  with RuntimeError _ ->
    raise (RuntimeError (Printf.sprintf "Nieznana unia: %s" union_name))

(* ============ STATEMENT EXECUTION ============ *)

(* Execute statement *)
and eval_stmt env = function
  | VarDecl (name, expr) ->
      let value = eval_expr env expr in
      define_var env name value

  | ArrayDecl (name, exprs) ->
      let values = List.map (eval_expr env) exprs in
      let arr = Array.of_list values in
      define_var env name (VArray arr)

  | Print expr ->
      let value = eval_expr env expr in
      print_endline (string_of_value value)

  | PrintInline expr ->
      let value = eval_expr env expr in
      (* flush: kolejność z komunikatami błędów na stderr jak w skompilowanym C *)
      print_string (string_of_value value);
      flush stdout

  | Read name ->
      let line = read_line () in
      let value = match decimal_of_string line with Some n -> VInt n | None -> VString line in
      set_var env name value

  | Assign (name, expr) ->
      let value = eval_expr env expr in
      set_var env name value

  | ArrayAssign (arr_expr, value_expr) ->
      (* Handle nested array assignment like arr[i][j] = value *)
      let value = eval_expr env value_expr in
      let assign_to_array expr val_to_assign =
        match expr with
        | ArrayAccess (inner_expr, idx_expr) ->
            let container = eval_expr env inner_expr in
            let idx = eval_expr env idx_expr in
            (match container, idx with
             | VArray arr_vals, VInt i ->
                 if i < 0 || i >= Array.length arr_vals then
                   raise (RuntimeError (Printf.sprintf "Indeks poza zakresem: %d" i))
                 else
                   arr_vals.(i) <- val_to_assign
             | VObject obj, VString s ->
                 Hashtbl.replace obj s val_to_assign
             | VObject obj, VInt i ->
                 Hashtbl.replace obj (string_of_int i) val_to_assign
             | _, VInt _ ->
                 raise (RuntimeError "To nie jest tablica ani obiekt")
             | _, _ ->
                 raise (RuntimeError "Indeks tablicy musi być liczbą całkowitą"))
        | _ ->
            raise (RuntimeError "Nieprawidłowe przypisanie do tablicy")
      in
      assign_to_array arr_expr value

  | If (cond, then_stmts, else_stmts_opt) ->
      let cond_value = eval_expr env cond in
      if to_bool cond_value then
        List.iter (eval_stmt env) then_stmts
      else
        (match else_stmts_opt with
         | Some else_stmts -> List.iter (eval_stmt env) else_stmts
         | None -> ())

  | For (var, from_e, to_e, step_e, body) ->
      (* Granice liczone raz; zakres włącznie; continue też robi krok *)
      let start = to_int (eval_expr env from_e) in
      let stop = to_int (eval_expr env to_e) in
      let step = match step_e with None -> 1 | Some e -> to_int (eval_expr env e) in
      if step = 0 then raise (RuntimeError "KRĘCI CEMENT BETONIARA: krok nie może być zerem");
      set_var env var (VInt start);
      let in_range () =
        let i = to_int (get_var env var) in
        if step > 0 then i <= stop else i >= stop
      in
      (try
        while in_range () do
          (try List.iter (eval_stmt env) body with ContinueLoop -> ());
          set_var env var (VInt (to_int (get_var env var) + step))
        done
      with BreakLoop -> ())

  | While (cond, body) ->
      let rec loop () =
        let cond_value = eval_expr env cond in
        if to_bool cond_value then
          try
            List.iter (eval_stmt env) body;
            loop ()
          with
          | BreakLoop -> ()
          | ContinueLoop -> loop ()
      in
      loop ()

  | FunctionCallStmt (name, args) ->
      let _ = eval_function_call env name args in
      ()

  | FunctionCallWithAssign (var, func, args) ->
      let result = eval_function_call env func args in
      set_var env var result

  | Return expr_opt ->
      let value = match expr_opt with
        | Some expr -> eval_expr env expr
        | None -> VNull
      in
      raise (ReturnValue value)

  | Try (try_stmts, catch_var, catch_stmts) ->
      (try
        List.iter (eval_stmt env) try_stmts
      with ThrowException value ->
        let catch_env = create_env (Some env) in
        define_var catch_env catch_var value;
        List.iter (eval_stmt catch_env) catch_stmts)

  | Throw expr ->
      let value = eval_expr env expr in
      raise (ThrowException value)

  | Located (file, line, s) ->
      current_loc := (file, line);
      eval_stmt env s

  | Break -> raise BreakLoop

  | Continue -> raise ContinueLoop

(* ============ MODULE LOADING ============ *)

(* Module loader function type - will be set by the main program *)
let module_loader : (string -> program option) ref = ref (fun _ -> None)

(* Set the module loader function *)
let set_module_loader loader =
  module_loader := loader

(* Import a module *)
(* Każdy moduł wykonujemy raz na sesję - jak kompilator, który wkleja go raz *)
let imported_modules : (string, unit) Hashtbl.t = Hashtbl.create 8

(* ============ BUILTINS ============ *)

(* Funkcja przekazana builtinowi (np. do sortowania) jako OCamlowa funkcja na wartościach *)
let function_arg builtin = function
  | VFunction (fdecl, closure_env) -> apply_function fdecl.name fdecl closure_env
  | _ -> raise (RuntimeError (builtin ^ ": drugi argument musi być funkcją"))

(* Wbudowane funkcje: nazwy (z wariantami), liczba argumentów (None = dowolna), implementacja.
   Liczbę argumentów sprawdza eval_function_call; z tej tabeli czyta też ferdek --check. *)
let () =
  List.iter (fun (names, arity, impl) ->
    List.iter (fun n -> Hashtbl.replace builtins n (arity, impl)) names) [

  ["USIĄDŹ NA KANAPIE"; "USIADZ NA KANAPIE"], None, (fun env args ->
      let arg_values = List.map (eval_expr env) args in
      let strings = List.map to_string arg_values in
      VString (String.concat "" strings));

  (* ROZCIĄGNIJ KANAPĘ - Padduje string do określonej długości *)
  ["ROZCIĄGNIJ KANAPĘ"], Some 2, (fun env args ->
      (match args with
       | [str_arg; len_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let target_len = to_int (eval_expr env len_arg) in
           VString (Builtins_string.kanapa_rozciagnij s target_len)
       | _ -> raise (RuntimeError (Errors.wrong_arg_count "ROZCIĄGNIJ KANAPĘ" 2 (List.length args)))));

  (* POTNIJ KANAPĘ - Substring (początek, koniec) *)
  ["POTNIJ KANAPĘ"], Some 3, (fun env args ->
      (match args with
       | [str_arg; start_arg; end_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let start = to_int (eval_expr env start_arg) in
           let end_pos = to_int (eval_expr env end_arg) in
           (try
             VString (Builtins_string.kanapa_potnij s start end_pos)
           with Failure msg ->
             raise (RuntimeError msg))
       | _ -> raise (RuntimeError (Errors.wrong_arg_count "POTNIJ KANAPĘ" 3 (List.length args)))));

  (* PRZESUŃ NA KANAPIE - Split string *)
  ["PRZESUŃ NA KANAPIE"], Some 2, (fun env args ->
      (match args with
       | [str_arg; sep_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let sep = to_string (eval_expr env sep_arg) in
           let parts = Builtins_string.kanapa_przesun s sep in
           VArray (Array.of_list (List.map (fun p -> VString p) parts))
       | _ -> raise (RuntimeError "PRZESUŃ NA KANAPIE oczekuje 2 argumentów")));

  (* POSKŁADAJ KANAPĘ - Join - łączy listę stringów *)
  ["POSKŁADAJ KANAPĘ"], Some 2, (fun env args ->
      (match args with
       | [arr_arg; sep_arg] ->
           let arr_val = eval_expr env arr_arg in
           let sep = to_string (eval_expr env sep_arg) in
           (match arr_val with
            | VArray arr ->
                let strings = Array.to_list (Array.map to_string arr) in
                VString (String.concat sep strings)
            | _ -> raise (RuntimeError "POSKŁADAJ KANAPĘ: pierwszy argument musi być tablicą"))
       | _ -> raise (RuntimeError "POSKŁADAJ KANAPĘ oczekuje 2 argumentów")));

  (* WYTRZEP KANAPĘ - Usuwa białe znaki z początku i końca (trim) *)
  ["WYTRZEP KANAPĘ"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let s = to_string (eval_expr env arg) in
           VString (String.trim s)
       | _ -> raise (RuntimeError "WYTRZEP KANAPĘ oczekuje 1 argumentu")));

  (* ZAMIEŃ NA KANAPIE - Replace *)
  ["ZAMIEŃ NA KANAPIE"], Some 3, (fun env args ->
      (match args with
       | [str_arg; old_arg; new_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let old_str = to_string (eval_expr env old_arg) in
           let new_str = to_string (eval_expr env new_arg) in
           VString (Builtins_string.kanapa_zamien s old_str new_str)
       | _ -> raise (RuntimeError "ZAMIEŃ NA KANAPIE oczekuje 3 argumentów")));

  (* ZNAK Z KANAPY(s, i) - znak (bajt) na pozycji i, jak w POTNIJ KANAPĘ *)
  ["ZNAK Z KANAPY"], Some 2, (fun env args ->
      (match args with
       | [str_arg; idx_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let i = to_int (eval_expr env idx_arg) in
           let chars = Builtins_string.utf8_chars s in
           if i < 0 || i >= Array.length chars then raise (RuntimeError "ZNAK Z KANAPY: indeks poza zakresem");
           VString chars.(i)
       | _ -> raise (RuntimeError "ZNAK Z KANAPY oczekuje 2 argumentów")));

  ["KANAPA DO GÓRY"], Some 1, (fun env args ->
      (match args with
       | [arg] -> VString (Builtins_string.kanapa_do_gory (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "KANAPA DO GÓRY oczekuje 1 argumentu")));

  ["KANAPA W DÓŁ"], Some 1, (fun env args ->
      (match args with
       | [arg] -> VString (Builtins_string.kanapa_w_dol (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "KANAPA W DÓŁ oczekuje 1 argumentu")));

  (* ILE MIEJSCA NA KANAPIE - Zwraca długość stringu *)
  ["ILE MIEJSCA NA KANAPIE"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           VInt (Builtins_string.utf8_length (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "ILE MIEJSCA NA KANAPIE oczekuje 1 argumentu")));

  (* OTWÓRZ KIBEL(ścieżka) - otwiera plik do odczytu *)
  ["OTWÓRZ KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           (try
             let channel = open_in path in
             VFileHandle (InputHandle channel)
           with Sys_error msg ->
             raise (RuntimeError (Printf.sprintf "OTWÓRZ KIBEL: %s" msg)))
       | _ -> raise (RuntimeError "OTWÓRZ KIBEL oczekuje 1 argumentu")));

  (* ZAMKNIJ KIBEL(uchwyt) - zamyka plik *)
  ["ZAMKNIJ KIBEL"], Some 1, (fun env args ->
      (match args with
       | [handle_arg] ->
           let handle_val = eval_expr env handle_arg in
           (match handle_val with
            | VFileHandle (InputHandle ch) ->
                close_in ch;
                VNull
            | VFileHandle (OutputHandle ch) ->
                close_out ch;
                VNull
            | _ -> raise (RuntimeError "ZAMKNIJ_KIBEL: argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "ZAMKNIJ_KIBEL oczekuje 1 argumentu")));

  (* SPUŚĆ WODĘ(uchwyt, dane) - zapisuje do pliku *)
  ["SPUŚĆ WODĘ"], Some 2, (fun env args ->
      (match args with
       | [handle_arg; data_arg] ->
           let handle_val = eval_expr env handle_arg in
           let data = to_string (eval_expr env data_arg) in
           (match handle_val with
            | VFileHandle (OutputHandle ch) ->
                output_string ch data;
                flush ch;
                VNull
            | VFileHandle (InputHandle _) ->
                raise (RuntimeError "SPUŚĆ_WODĘ: nie można pisać do pliku otwartego do odczytu")
            | _ -> raise (RuntimeError "SPUŚĆ_WODĘ: pierwszy argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "SPUŚĆ_WODĘ oczekuje 2 argumentów")));

  (* WYPOMPUJ(uchwyt) - czyta cały plik *)
  ["WYPOMPUJ"], Some 1, (fun env args ->
      (match args with
       | [handle_arg] ->
           let handle_val = eval_expr env handle_arg in
           (match handle_val with
            | VFileHandle (InputHandle ch) ->
                let rec read_all acc =
                  try
                    let line = input_line ch in
                    read_all (line :: acc)
                  with End_of_file ->
                    List.rev acc
                in
                let lines = read_all [] in
                VArray (Array.of_list (List.map (fun s -> VString s) lines))
            | VFileHandle (OutputHandle _) ->
                raise (RuntimeError "WYPOMPUJ: nie można czytać z pliku otwartego do zapisu")
            | _ -> raise (RuntimeError "WYPOMPUJ: argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "WYPOMPUJ oczekuje 1 argumentu")));

  (* CZY KIBEL ZAJĘTY(ścieżka) - sprawdza czy plik istnieje *)
  ["CZY KIBEL ZAJĘTY"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Sys.file_exists path)
       | _ -> raise (RuntimeError "CZY_KIBEL_ZAJĘTY oczekuje 1 argumentu")));

  (* OTWÓRZ KIBEL DO ZAPISU(ścieżka) - otwiera plik do zapisu *)
  ["OTWÓRZ KIBEL DO ZAPISU"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           (try
             let channel = open_out path in
             VFileHandle (OutputHandle channel)
           with Sys_error msg ->
             raise (RuntimeError (Printf.sprintf "OTWÓRZ_KIBEL_DO_ZAPISU: %s" msg)))
       | _ -> raise (RuntimeError "OTWÓRZ_KIBEL_DO_ZAPISU oczekuje 1 argumentu")));

  (* SYSTEM(komenda) - wykonuje komendę systemową i zwraca output *)
  (* OPAKUJ W GAZETĘ(tekst) - bezpieczne cytowanie argumentu dla powłoki (do SYSTEM) *)
  ["OPAKUJ W GAZETĘ"], Some 1, (fun env args ->
      (match args with
       | [arg] -> VString (Filename.quote (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "OPAKUJ W GAZETĘ oczekuje 1 argumentu")));

  ["SYSTEM"], Some 1, (fun env args ->
      (match args with
       | [cmd_arg] ->
           let cmd = to_string (eval_expr env cmd_arg) in
           (try
             let ic = Unix.open_process_in cmd in
             let buf = Buffer.create 256 in
             (try
               while true do
                 Buffer.add_channel buf ic 1
               done;
               VString ""
             with End_of_file ->
               let _ = Unix.close_process_in ic in
               let output = Buffer.contents buf in
               VString output)
           with Unix.Unix_error (err, _, _) ->
             raise (RuntimeError (Printf.sprintf "SYSTEM: błąd: %s" (Unix.error_message err))))
       | _ -> raise (RuntimeError "SYSTEM oczekuje 1 argumentu")));

  (* ========== SZAFKA (HashMap/Dictionary) operations ========== *)
  (* OTWÓRZ SZAFKĘ(klucz1, wartość1, ...) - nowa mapa, opcjonalnie od razu z parami *)
  ["OTWÓRZ SZAFKĘ"], None, (fun env args ->
      if List.length args mod 2 <> 0 then
        raise (RuntimeError "OTWÓRZ SZAFKĘ: potrzebne pary klucz, wartość (parzysta liczba argumentów)");
      let tbl = Hashtbl.create 16 in
      let rec fill = function
        | k :: v :: rest ->
            let key = to_string (eval_expr env k) in
            Hashtbl.replace tbl key (eval_expr env v); fill rest
        | _ -> () in
      fill args;
      VHashMap tbl);

  (* WŁÓŻ DO SZAFKI(dict, key, value) - adds key-value pair *)
  ["WŁÓŻ DO SZAFKI"], Some 3, (fun env args ->
      (match args with
       | [dict_arg; key_arg; value_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           let value = eval_expr env value_arg in
           (match dict_val with
            | VHashMap tbl ->
                Hashtbl.replace tbl key value;
                VNull
            | _ -> raise (RuntimeError "WŁÓŻ DO SZAFKI: pierwszy argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "WŁÓŻ DO SZAFKI oczekuje 3 argumentów")));

  (* WYJMIJ Z SZAFKI(dict, key) - gets value by key *)
  ["WYJMIJ Z SZAFKI"], Some 2, (fun env args ->
      (match args with
       | [dict_arg; key_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           (match dict_val with
            | VHashMap tbl ->
                (match Hashtbl.find_opt tbl key with
                 | Some v -> v
                 | None -> VNull)
            | _ -> raise (RuntimeError "WYJMIJ Z SZAFKI: pierwszy argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "WYJMIJ Z SZAFKI oczekuje 2 argumentów")));

  (* WYRZUĆ ZE SZAFKI(dict, key) - removes key-value pair *)
  ["WYRZUĆ ZE SZAFKI"], Some 2, (fun env args ->
      (match args with
       | [dict_arg; key_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           (match dict_val with
            | VHashMap tbl ->
                Hashtbl.remove tbl key;
                VNull
            | _ -> raise (RuntimeError "WYRZUĆ ZE SZAFKI: pierwszy argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "WYRZUĆ ZE SZAFKI oczekuje 2 argumentów")));

  (* CZY W SZAFCE(dict, key) - checks if key exists *)
  ["CZY W SZAFCE"], Some 2, (fun env args ->
      (match args with
       | [dict_arg; key_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           (match dict_val with
            | VHashMap tbl ->
                VBool (Builtins_hashmap.szafka_czy_w_szafce tbl key)
            | _ -> raise (RuntimeError "CZY W SZAFCE: pierwszy argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "CZY W SZAFCE oczekuje 2 argumentów")));

  (* WSZYSTKIE SZUFLADKI(dict) - returns list of all keys *)
  ["WSZYSTKIE SZUFLADKI"], Some 1, (fun env args ->
      (match args with
       | [dict_arg] ->
           let dict_val = eval_expr env dict_arg in
           (match dict_val with
            | VHashMap tbl ->
                let keys = Builtins_hashmap.szafka_wszystkie_szufladki tbl in
                VArray (Array.of_list (List.map (fun k -> VString k) keys))
            | _ -> raise (RuntimeError "WSZYSTKIE SZUFLADKI: argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "WSZYSTKIE SZUFLADKI oczekuje 1 argumentu")));

  (* ILE W SZAFCE(dict) - returns number of elements *)
  ["ILE W SZAFCE"], Some 1, (fun env args ->
      (match args with
       | [dict_arg] ->
           let dict_val = eval_expr env dict_arg in
           (match dict_val with
            | VHashMap tbl ->
                VInt (Builtins_hashmap.szafka_ile_w_szafce tbl)
            | _ -> raise (RuntimeError "ILE W SZAFCE: argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "ILE W SZAFCE oczekuje 1 argumentu")));

  (* ========== KIBEL (File operations) ========== *)
  (* ZRÓB KIBEL(path) - creates directory *)
  ["ZRÓB KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Builtins_file.kibel_zrob path)
       | _ -> raise (RuntimeError "ZRÓB KIBEL oczekuje 1 argumentu")));

  (* WYWAL KIBEL(path) - removes directory *)
  ["WYWAL KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Builtins_file.kibel_wywal path)
       | _ -> raise (RuntimeError "WYWAL KIBEL oczekuje 1 argumentu")));

  (* CO W KIBLU(path) - lists files in directory *)
  ["CO W KIBLU"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           let files = Builtins_file.kibel_co_w_kiblu path in
           VArray (Array.of_list (List.map (fun f -> VString f) files))
       | _ -> raise (RuntimeError "CO W KIBLU oczekuje 1 argumentu")));

  (* CZY TO KIBEL(path) - checks if path is directory *)
  ["CZY TO KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Builtins_file.kibel_czy_to_kibel path)
       | _ -> raise (RuntimeError "CZY TO KIBEL oczekuje 1 argumentu")));

  (* PRZEKOPIUJ KIBEL(src, dest) - copies file *)
  ["PRZEKOPIUJ KIBEL"], Some 2, (fun env args ->
      (match args with
       | [src_arg; dest_arg] ->
           let src = to_string (eval_expr env src_arg) in
           let dest = to_string (eval_expr env dest_arg) in
           VBool (Builtins_file.kibel_przekopiuj src dest)
       | _ -> raise (RuntimeError "PRZEKOPIUJ KIBEL oczekuje 2 argumentów")));

  (* PRZENIEŚ KIBEL(src, dest) - moves/renames file *)
  ["PRZENIEŚ KIBEL"], Some 2, (fun env args ->
      (match args with
       | [src_arg; dest_arg] ->
           let src = to_string (eval_expr env src_arg) in
           let dest = to_string (eval_expr env dest_arg) in
           VBool (Builtins_file.kibel_przenies src dest)
       | _ -> raise (RuntimeError "PRZENIEŚ KIBEL oczekuje 2 argumentów")));

  (* WYKOP WSZYSTKIE KIBLE(path) - recursive delete *)
  ["WYKOP WSZYSTKIE KIBLE"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           Builtins_file.kibel_wykop_wszystkie path;
           VNull
       | _ -> raise (RuntimeError "WYKOP WSZYSTKIE KIBLE oczekuje 1 argumentu")));

  (* ========== WERSALKA (List/Array operations) ========== *)
  (* ILE NA WERSALCE(array) - returns array length *)
  ["ILE NA WERSALCE"], Some 1, (fun env args ->
      (match args with
       | [arr_arg] ->
           let arr_val = eval_expr env arr_arg in
           (match arr_val with
            | VArray arr -> VInt (Builtins_list.wersalka_ile_na arr)
            | _ -> raise (RuntimeError "ILE NA WERSALCE: argument musi być tablicą"))
       | _ -> raise (RuntimeError "ILE NA WERSALCE oczekuje 1 argumentu")));

  (* POŁÓŻ NA WERSALCE(array, element) - appends element to array *)
  ["POŁÓŻ NA WERSALCE"], Some 2, (fun env args ->
      (match args with
       | [arr_arg; elem_arg] ->
           let arr_val = eval_expr env arr_arg in
           let elem = eval_expr env elem_arg in
           (match arr_val with
            | VArray arr ->
                let new_arr = Builtins_list.wersalka_poloz_na arr elem in
                VArray new_arr
            | _ -> raise (RuntimeError "POŁÓŻ NA WERSALCE: pierwszy argument musi być tablicą"))
       | _ -> raise (RuntimeError "POŁÓŻ NA WERSALCE oczekuje 2 argumentów")));

  (* ZDEJMIJ Z WERSALKI(array) - pops last element *)
  ["ZDEJMIJ Z WERSALKI"], Some 1, (fun env args ->
      (match args with
       | [arr_arg] ->
           let arr_val = eval_expr env arr_arg in
           (match arr_val with
            | VArray arr ->
                (try
                  let (new_arr, popped) = Builtins_list.wersalka_zdejmij_z arr in
                  (* Return the popped element *)
                  popped
                with Failure msg ->
                  raise (RuntimeError msg))
            | _ -> raise (RuntimeError "ZDEJMIJ Z WERSALKI: argument musi być tablicą"))
       | _ -> raise (RuntimeError "ZDEJMIJ Z WERSALKI oczekuje 1 argumentu")));

  (* CZY LEŻY NA WERSALCE(array, element) - checks if element is in array *)
  ["CZY LEŻY NA WERSALCE"], Some 2, (fun env args ->
      (match args with
       | [arr_arg; elem_arg] ->
           let arr_val = eval_expr env arr_arg in
           let elem = eval_expr env elem_arg in
           (match arr_val with
            | VArray arr ->
                let equal_func a b =
                  match (a, b) with
                  | (VInt x, VInt y) -> x = y
                  | (VString x, VString y) -> x = y
                  | (VBool x, VBool y) -> x = y
                  | _ -> false
                in
                VBool (Builtins_list.wersalka_czy_lezy_na arr elem equal_func)
            | _ -> raise (RuntimeError "CZY LEŻY NA WERSALCE: pierwszy argument musi być tablicą"))
       | _ -> raise (RuntimeError "CZY LEŻY NA WERSALCE oczekuje 2 argumentów")));

  (* ============ MEMORY MANAGEMENT (DOOM-style Zone Allocator) ============ *)
  (* DAJ MI HAJS - Z_Malloc(size, tag) - Allocate memory block *)
  ["DAJ MI HAJS"], Some 2, (fun env args ->
      (match args with
       | [size_arg; tag_arg] ->
           let size = to_int (eval_expr env size_arg) in
           let tag_val = to_int (eval_expr env tag_arg) in
           if size <= 0 then
             raise (RuntimeError "DAJ MI HAJS: rozmiar musi być dodatni")
           else begin
             let tag = int_to_tag tag_val in
             let id = !next_block_id in
             next_block_id := !next_block_id + 1;
             let block = {
               size = size;
               tag = tag;
               data = Array.make size VNull;
               id = id;
             } in
             Hashtbl.add zone_blocks id block;
             total_allocated := !total_allocated + size;
             (* Return pointer to block ID *)
             VPointer (ref (VInt id))
           end
       | _ -> raise (RuntimeError "DAJ MI HAJS oczekuje 2 argumentów (size, tag)")));

  (* ODDAJ_WSZYSTKO - Z_Free(ptr) - Free memory block *)
  ["ODDAJ WSZYSTKO"], Some 1, (fun env args ->
      (match args with
       | [ptr_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       total_freed := !total_freed + block.size;
                       Hashtbl.remove zone_blocks block_id;
                       VNull
                     end else
                       raise (RuntimeError "ODDAJ WSZYSTKO: blok nie istnieje")
                 | _ -> raise (RuntimeError "ODDAJ WSZYSTKO: nieprawidłowy wskaźnik"))
            | _ -> raise (RuntimeError "ODDAJ WSZYSTKO: argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "ODDAJ WSZYSTKO oczekuje 1 argumentu (pointer)")));

  (* KOMORNICZY_WINDYKACJA - Z_FreeTags(lowtag, hightag) - Free blocks by tag range *)
  ["KOMORNICZY WINDYKACJA"], Some 2, (fun env args ->
      (match args with
       | [lowtag_arg; hightag_arg] ->
           let lowtag = to_int (eval_expr env lowtag_arg) in
           let hightag = to_int (eval_expr env hightag_arg) in
           let freed_count = ref 0 in
           let to_remove = ref [] in
           Hashtbl.iter (fun id block ->
             let tag_val = tag_to_int block.tag in
             if tag_val >= lowtag && tag_val <= hightag then begin
               total_freed := !total_freed + block.size;
               to_remove := id :: !to_remove;
               freed_count := !freed_count + 1
             end
           ) zone_blocks;
           List.iter (Hashtbl.remove zone_blocks) !to_remove;
           VInt !freed_count
       | _ -> raise (RuntimeError "KOMORNICZY WINDYKACJA oczekuje 2 argumentów (lowtag, hightag)")));

  (* ZAPISZ_DO_BLOKU - Write to memory block *)
  ["ZAPISZ DO BLOKU"], Some 3, (fun env args ->
      (match args with
       | [ptr_arg; index_arg; value_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           let index = to_int (eval_expr env index_arg) in
           let value = eval_expr env value_arg in
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       if index >= 0 && index < block.size then begin
                         block.data.(index) <- value;
                         VNull
                       end else
                         raise (RuntimeError (Printf.sprintf "ZAPISZ DO BLOKU: indeks %d poza zakresem (rozmiar: %d)" index block.size))
                     end else
                       raise (RuntimeError "ZAPISZ DO BLOKU: blok nie istnieje")
                 | _ -> raise (RuntimeError "ZAPISZ DO BLOKU: nieprawidłowy wskaźnik"))
            | _ -> raise (RuntimeError "ZAPISZ DO BLOKU: pierwszy argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "ZAPISZ DO BLOKU oczekuje 3 argumentów (ptr, index, value)")));

  (* CZYTAJ_Z_BLOKU - Read from memory block *)
  ["CZYTAJ Z BLOKU"], Some 2, (fun env args ->
      (match args with
       | [ptr_arg; index_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           let index = to_int (eval_expr env index_arg) in
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       if index >= 0 && index < block.size then
                         block.data.(index)
                       else
                         raise (RuntimeError (Printf.sprintf "CZYTAJ Z BLOKU: indeks %d poza zakresem (rozmiar: %d)" index block.size))
                     end else
                       raise (RuntimeError "CZYTAJ Z BLOKU: blok nie istnieje")
                 | _ -> raise (RuntimeError "CZYTAJ Z BLOKU: nieprawidłowy wskaźnik"))
            | _ -> raise (RuntimeError "CZYTAJ Z BLOKU: pierwszy argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "CZYTAJ Z BLOKU oczekuje 2 argumentów (ptr, index)")));

  (* ROZMIAR_BLOKU - Get memory block size *)
  ["ROZMIAR BLOKU"], Some 1, (fun env args ->
      (match args with
       | [ptr_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       VInt block.size
                     end else
                       raise (RuntimeError "ROZMIAR BLOKU: blok nie istnieje")
                 | _ -> raise (RuntimeError "ROZMIAR BLOKU: nieprawidłowy wskaźnik"))
            | _ -> raise (RuntimeError "ROZMIAR BLOKU: argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "ROZMIAR BLOKU oczekuje 1 argumentu (pointer)")));

  (* ILE_KASY_LECI - Get memory statistics *)
  ["ILE KASY LECI"], Some 0, (fun env args ->
      (match args with
       | [] ->
           let allocated = !total_allocated in
           let freed = !total_freed in
           let current = allocated - freed in
           let block_count = Hashtbl.length zone_blocks in
           (* Return hash map with stats *)
           let stats = Hashtbl.create 4 in
           Hashtbl.add stats "allocated" (VInt allocated);
           Hashtbl.add stats "freed" (VInt freed);
           Hashtbl.add stats "current" (VInt current);
           Hashtbl.add stats "blocks" (VInt block_count);
           VHashMap stats
       | _ -> raise (RuntimeError "ILE KASY LECI nie przyjmuje argumentów")));

  (* TAG_TRWALE - Memory tag constant (PU_STATIC) *)
  ["TAG_TRWALE"], Some 0, (fun env args ->
      (match args with
       | [] -> VInt 1
       | _ -> raise (RuntimeError "TAG_TRWALE to stała, nie przyjmuje argumentów")));

  (* TAG_POZIOM - Memory tag constant (PU_LEVEL) *)
  ["TAG_POZIOM"], Some 0, (fun env args ->
      (match args with
       | [] -> VInt 50
       | _ -> raise (RuntimeError "TAG_POZIOM to stała, nie przyjmuje argumentów")));

  (* TAG_SMIECIOWE - Memory tag constant (PU_CACHE) *)
  ["TAG_SMIECIOWE"], Some 0, (fun env args ->
      (match args with
       | [] -> VInt 100
       | _ -> raise (RuntimeError "TAG_SMIECIOWE to stała, nie przyjmuje argumentów")));

  (* ============ FRAMEBUFFER FUNCTIONS (TELEWIZOR) ============ *)
  (* WŁĄCZ TELEWIZOR(width, height) - Create framebuffer *)
  ["WŁĄCZ TELEWIZOR"; "WLACZ TELEWIZOR"], Some 2, (fun env args ->
      (match args with
       | [width_arg; height_arg] ->
           let width = to_int (eval_expr env width_arg) in
           let height = to_int (eval_expr env height_arg) in
           if width <= 0 || height <= 0 then
             raise (RuntimeError "WŁĄCZ TELEWIZOR: szerokość i wysokość muszą być dodatnie")
           else begin
             let id = !next_fb_id in
             next_fb_id := !next_fb_id + 1;
             let total_pixels = width * height in
             let fb = {
               width = width;
               height = height;
               pixels = Array.make total_pixels 0;  (* Initialize to black *)
               id = id;
             } in
             Hashtbl.add framebuffers id fb;
             (* Return pointer to framebuffer ID *)
             VPointer (ref (VInt id))
           end
       | _ -> raise (RuntimeError "WŁĄCZ TELEWIZOR oczekuje 2 argumentów (width, height)")));

  (* WYŁĄCZ TELEWIZOR(fb_ptr) - Destroy framebuffer *)
  ["WYŁĄCZ TELEWIZOR"; "WYLACZ TELEWIZOR"], Some 1, (fun env args ->
      (match args with
       | [fb_arg] ->
           let fb_val = eval_expr env fb_arg in
           (match fb_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt fb_id ->
                     if Hashtbl.mem framebuffers fb_id then begin
                       Hashtbl.remove framebuffers fb_id;
                       VNull
                     end else
                       raise (RuntimeError "WYŁĄCZ TELEWIZOR: nieprawidłowy ekran")
                 | _ -> raise (RuntimeError "WYŁĄCZ TELEWIZOR: argument musi być wskaźnikiem na ekran"))
            | _ -> raise (RuntimeError "WYŁĄCZ TELEWIZOR: argument musi być wskaźnikiem na ekran"))
       | _ -> raise (RuntimeError "WYŁĄCZ TELEWIZOR oczekuje 1 argumentu (framebuffer)")));

  (* ZMIEŃ KANAŁ(fb_ptr, x, y, color) - Write pixel to framebuffer *)
  ["ZMIEŃ KANAŁ"; "ZMIEN KANAL"], Some 4, (fun env args ->
      (match args with
       | [fb_arg; x_arg; y_arg; color_arg] ->
           let fb_val = eval_expr env fb_arg in
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           let color = to_int (eval_expr env color_arg) in
           (match fb_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt fb_id ->
                     if Hashtbl.mem framebuffers fb_id then begin
                       let fb = Hashtbl.find framebuffers fb_id in
                       if x < 0 || x >= fb.width || y < 0 || y >= fb.height then
                         raise (RuntimeError "ZMIEŃ KANAŁ: piksel poza ekranem")
                       else begin
                         let offset = y * fb.width + x in
                         fb.pixels.(offset) <- color;
                         VNull
                       end
                     end else
                       raise (RuntimeError "ZMIEŃ KANAŁ: nieprawidłowy ekran")
                 | _ -> raise (RuntimeError "ZMIEŃ KANAŁ: pierwszy argument musi być wskaźnikiem na ekran"))
            | _ -> raise (RuntimeError "ZMIEŃ KANAŁ: pierwszy argument musi być wskaźnikiem na ekran"))
       | _ -> raise (RuntimeError "ZMIEŃ KANAŁ oczekuje 4 argumentów (framebuffer, x, y, color)")));

  (* CO LECI W TELEWIZORZE(fb_ptr, x, y) - Read pixel from framebuffer *)
  ["CO LECI W TELEWIZORZE"], Some 3, (fun env args ->
      (match args with
       | [fb_arg; x_arg; y_arg] ->
           let fb_val = eval_expr env fb_arg in
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           (match fb_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt fb_id ->
                     if Hashtbl.mem framebuffers fb_id then begin
                       let fb = Hashtbl.find framebuffers fb_id in
                       if x < 0 || x >= fb.width || y < 0 || y >= fb.height then
                         raise (RuntimeError "CO LECI W TELEWIZORZE: piksel poza ekranem")
                       else begin
                         let offset = y * fb.width + x in
                         VInt fb.pixels.(offset)
                       end
                     end else
                       raise (RuntimeError "CO LECI W TELEWIZORZE: nieprawidłowy ekran")
                 | _ -> raise (RuntimeError "CO LECI W TELEWIZORZE: pierwszy argument musi być wskaźnikiem na ekran"))
            | _ -> raise (RuntimeError "CO LECI W TELEWIZORZE: pierwszy argument musi być wskaźnikiem na ekran"))
       | _ -> raise (RuntimeError "CO LECI W TELEWIZORZE oczekuje 3 argumentów (framebuffer, x, y)")));

  (* ============ LOOKUP TABLE FUNCTIONS ============ *)
  (* STWÓRZ TABELĘ(size) - Create lookup table *)
  ["STWÓRZ TABELĘ"; "STWORZ TABELE"], Some 1, (fun env args ->
      (match args with
       | [size_arg] ->
           let size = to_int (eval_expr env size_arg) in
           if size <= 0 then
             raise (RuntimeError "STWÓRZ TABELĘ: rozmiar musi być dodatni")
           else begin
             let id = !next_table_id in
             next_table_id := !next_table_id + 1;
             let table = {
               data = Array.make size 0;
               size = size;
               id = id;
             } in
             Hashtbl.add lookup_tables id table;
             VPointer (ref (VInt id))
           end
       | _ -> raise (RuntimeError "STWÓRZ TABELĘ oczekuje 1 argumentu (size)")));

  (* WPISZ DO TABELI(table_ptr, index, value) - Write to lookup table *)
  ["WPISZ DO TABELI"], Some 3, (fun env args ->
      (match args with
       | [table_arg; index_arg; value_arg] ->
           let table_val = eval_expr env table_arg in
           let index = to_int (eval_expr env index_arg) in
           let value = to_int (eval_expr env value_arg) in
           (match table_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt table_id ->
                     if Hashtbl.mem lookup_tables table_id then begin
                       let table = Hashtbl.find lookup_tables table_id in
                       if index < 0 || index >= table.size then
                         raise (RuntimeError "WPISZ DO TABELI: indeks poza zakresem")
                       else begin
                         table.data.(index) <- value;
                         VNull
                       end
                     end else
                       raise (RuntimeError "WPISZ DO TABELI: nieprawidłowa tabela")
                 | _ -> raise (RuntimeError "WPISZ DO TABELI: pierwszy argument musi być wskaźnikiem na tabelę"))
            | _ -> raise (RuntimeError "WPISZ DO TABELI: pierwszy argument musi być wskaźnikiem na tabelę"))
       | _ -> raise (RuntimeError "WPISZ DO TABELI oczekuje 3 argumentów (table, index, value)")));

  (* SPRAWDŹ W TABELI(table_ptr, index) - Read from lookup table *)
  ["SPRAWDŹ W TABELI"; "SPRAWDZ W TABELI"], Some 2, (fun env args ->
      (match args with
       | [table_arg; index_arg] ->
           let table_val = eval_expr env table_arg in
           let index = to_int (eval_expr env index_arg) in
           (match table_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt table_id ->
                     if Hashtbl.mem lookup_tables table_id then begin
                       let table = Hashtbl.find lookup_tables table_id in
                       if index < 0 || index >= table.size then
                         raise (RuntimeError "SPRAWDŹ W TABELI: indeks poza zakresem")
                       else
                         VInt table.data.(index)
                     end else
                       raise (RuntimeError "SPRAWDŹ W TABELI: nieprawidłowa tabela")
                 | _ -> raise (RuntimeError "SPRAWDŹ W TABELI: pierwszy argument musi być wskaźnikiem na tabelę"))
            | _ -> raise (RuntimeError "SPRAWDŹ W TABELI: pierwszy argument musi być wskaźnikiem na tabelę"))
       | _ -> raise (RuntimeError "SPRAWDŹ W TABELI oczekuje 2 argumentów (table, index)")));

  (* ============ DIRECT MEMORY ACCESS ============ *)
  (* PISZ BAJT(ptr, offset, value) - Write byte directly to memory block *)
  ["PISZ BAJT"], Some 3, (fun env args ->
      (match args with
       | [ptr_arg; offset_arg; value_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           let offset = to_int (eval_expr env offset_arg) in
           let value = to_int (eval_expr env value_arg) in
           (* Same as ZAPISZ DO BLOKU but emphasizes byte-level access *)
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       if offset < 0 || offset >= block.size then
                         raise (RuntimeError "PISZ BAJT: przesunięcie poza zakresem")
                       else begin
                         block.data.(offset) <- VInt value;
                         VNull
                       end
                     end else
                       raise (RuntimeError "PISZ BAJT: nieprawidłowy blok pamięci")
                 | _ -> raise (RuntimeError "PISZ BAJT: pierwszy argument musi być wskaźnikiem"))
            | _ -> raise (RuntimeError "PISZ BAJT: pierwszy argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "PISZ BAJT oczekuje 3 argumentów (ptr, offset, value)")));

  (* CZYTAJ BAJT(ptr, offset) - Read byte directly from memory block *)
  ["CZYTAJ BAJT"], Some 2, (fun env args ->
      (match args with
       | [ptr_arg; offset_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           let offset = to_int (eval_expr env offset_arg) in
           (* Same as CZYTAJ Z BLOKU but emphasizes byte-level access *)
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       if offset < 0 || offset >= block.size then
                         raise (RuntimeError "CZYTAJ BAJT: przesunięcie poza zakresem")
                       else
                         block.data.(offset)
                     end else
                       raise (RuntimeError "CZYTAJ BAJT: nieprawidłowy blok pamięci")
                 | _ -> raise (RuntimeError "CZYTAJ BAJT: pierwszy argument musi być wskaźnikiem"))
            | _ -> raise (RuntimeError "CZYTAJ BAJT: pierwszy argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "CZYTAJ BAJT oczekuje 2 argumentów (ptr, offset)")));

  (* KOPIUJ PAMIĘĆ(src_ptr, dst_ptr, size) - Memory copy (like memcpy) *)
  ["KOPIUJ PAMIĘĆ"; "KOPIUJ PAMIEC"], Some 3, (fun env args ->
      (match args with
       | [src_arg; dst_arg; size_arg] ->
           let src_val = eval_expr env src_arg in
           let dst_val = eval_expr env dst_arg in
           let size = to_int (eval_expr env size_arg) in
           (match src_val, dst_val with
            | VPointer src_ptr, VPointer dst_ptr ->
                (match !src_ptr, !dst_ptr with
                 | VInt src_id, VInt dst_id ->
                     if Hashtbl.mem zone_blocks src_id && Hashtbl.mem zone_blocks dst_id then begin
                       let src_block = Hashtbl.find zone_blocks src_id in
                       let dst_block = Hashtbl.find zone_blocks dst_id in
                       if size > src_block.size || size > dst_block.size then
                         raise (RuntimeError "KOPIUJ PAMIĘĆ: rozmiar większy niż blok")
                       else begin
                         Array.blit src_block.data 0 dst_block.data 0 size;
                         VNull
                       end
                     end else
                       raise (RuntimeError "KOPIUJ PAMIĘĆ: nieprawidłowe bloki pamięci")
                 | _ -> raise (RuntimeError "KOPIUJ PAMIĘĆ: argumenty muszą być wskaźnikami"))
            | _ -> raise (RuntimeError "KOPIUJ PAMIĘĆ: argumenty muszą być wskaźnikami"))
       | _ -> raise (RuntimeError "KOPIUJ PAMIĘĆ oczekuje 3 argumentów (src, dst, size)")));

  (* ============ TYPE CASTING FUNCTIONS ============ *)
  (* ZRÓB BAJCIK(expr) - Cast to byte (0-255) *)
  ["ZRÓB BAJCIK"; "ZROB BAJCIK"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           VByte (value land 0xFF)  (* Mask to 0-255 *)
       | _ -> raise (RuntimeError "ZRÓB BAJCIK oczekuje 1 argumentu")));

  (* ZRÓB KRÓTKI(expr) - Cast to short (16-bit) *)
  ["ZRÓB KRÓTKI"; "ZROB KROTKI"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           (* Sign-extend from 16-bit *)
           let masked = value land 0xFFFF in
           let short_val = if masked > 0x7FFF then masked - 0x10000 else masked in
           VShort short_val
       | _ -> raise (RuntimeError "ZRÓB KRÓTKI oczekuje 1 argumentu")));

  (* ZRÓB DŁUGI(expr) - Cast to int (32-bit, default) *)
  ["ZRÓB DŁUGI"; "ZROB DLUGI"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           (* Jawne obcięcie liczby z przecinkiem *)
           (match eval_expr env arg with
            | VFloat f -> VInt (int_of_float f)
            | v -> VInt (to_int v))
       | _ -> raise (RuntimeError "ZRÓB DŁUGI oczekuje 1 argumentu")));

  (* ZRÓB UŁAMEK(expr) - Cast to fixed-point (same as ZAMIEŃ NA FIXED) *)
  ["ZRÓB UŁAMEK"; "ZROB ULAMEK"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           VFixed (value lsl 16)  (* Convert to 16.16 fixed-point *)
       | _ -> raise (RuntimeError "ZRÓB UŁAMEK oczekuje 1 argumentu"))

  (* CO TO ZA TYP(var) - Return type name *)
  (* KARTA LUBI DYM(min, max) - losowa liczba; KARTA LUBI DYM(ziarno) - ustawia ziarno.
     Własny LCG zamiast Random: ten sam ciąg co w skompilowanym C *));

  ["KARTA LUBI DYM"], None, (fun env args ->
      let rng_next () =
        if !rng_state < 0 then rng_state := int_of_float (Unix.gettimeofday () *. 1000.) land 0x7FFFFFFF;
        rng_state := (!rng_state * 1103515245 + 12345) land 0x7FFFFFFF;
        !rng_state
      in
      (match List.map (eval_expr env) args with
       | [seed] -> rng_state := to_int seed land 0x7FFFFFFF; VNull
       | [lo; hi] ->
           let lo = to_int lo and hi = to_int hi in
           if lo > hi then raise (RuntimeError "KARTA LUBI DYM: min większe niż max");
           VInt (lo + rng_next () mod (hi - lo + 1))
       | _ -> raise (RuntimeError "KARTA LUBI DYM oczekuje 1 argumentu (ziarno) albo 2 (min, max)")));

  ["CO TO ZA TYP"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let value = eval_expr env arg in
           let type_name = match value with
             | VByte _ -> "BAJCIK"
             | VShort _ -> "KRÓTKI"
             | VInt _ -> "DŁUGI"
             | VFixed _ -> "UŁAMEK"
             | VFloat _ -> "PRZECINEK"
             | VString _ -> "TEKST"
             | VBool _ -> "PRAWDA/FAŁSZ"
             | VNull -> "NIC"
             | VArray _ -> "TABLICA"
             | VHashMap _ -> "SZAFKA"
             | VFunction _ -> "FUNKCJA"
             | VClass _ -> "KLASA"
             | VStruct _ -> "MEBEL"
             | VUnion _ -> "UNIA"
             | VEnum _ -> "LISTA"
             | VObject _ -> "OBIEKT"
             | VPointer _ -> "WSKAŹNIK"
             | VFileHandle _ -> "KIBEL"
           in
           VString type_name
       | _ -> raise (RuntimeError "CO TO ZA TYP oczekuje 1 argumentu")));

  (* ============ LOW-LEVEL I/O ============ *)
  (* OTWORZ(filename, mode) - open() - Open file *)
  ["OTWORZ"], Some 2, (fun env args ->
      (match args with
       | [filename_arg; mode_arg] ->
           let filename = match eval_expr env filename_arg with
             | VString s -> s
             | _ -> raise (RuntimeError "OTWORZ: nazwa pliku musi być tekstem")
           in
           let mode = match eval_expr env mode_arg with
             | VString s -> s
             | _ -> raise (RuntimeError "OTWORZ: tryb musi być tekstem")
           in
           (try
              let handle = match mode with
                | "r" | "rb" -> InputHandle (open_in_bin filename)
                | "w" | "wb" -> OutputHandle (open_out_bin filename)
                | "a" | "ab" -> OutputHandle (open_out_gen [Open_append; Open_binary; Open_creat] 0o666 filename)
                | _ -> raise (RuntimeError (Printf.sprintf "Nieprawidłowy tryb pliku: %s (dozwolone: 'r', 'w', 'a')" mode))
              in
              VFileHandle handle
            with Sys_error msg ->
              raise (RuntimeError (Printf.sprintf "Nie można otworzyć pliku '%s': %s" filename msg)))
       | _ -> raise (RuntimeError "OTWORZ oczekuje 2 argumentów (filename, mode)")));

  (* ZAMKNIJ(file_handle) - close() - Close file *)
  ["ZAMKNIJ"], Some 1, (fun env args ->
      (match args with
       | [handle_arg] ->
           let handle = eval_expr env handle_arg in
           (match handle with
            | VFileHandle (InputHandle ch) -> close_in ch; VNull
            | VFileHandle (OutputHandle ch) -> close_out ch; VNull
            | _ -> raise (RuntimeError "ZAMKNIJ: argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "ZAMKNIJ oczekuje 1 argumentu (file_handle)")));

  (* CZYTAJ(file_handle, [num_bytes]) - read() - Read bytes *)
  ["CZYTAJ"], None, (fun env args ->
      (match args with
       | [handle_arg; size_arg] ->
           let handle = eval_expr env handle_arg in
           let size = to_int (eval_expr env size_arg) in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                (try
                   let buffer = Bytes.create size in
                   let bytes_read = input ch buffer 0 size in
                   (* Return array of bytes *)
                   let byte_array = Array.init bytes_read (fun i -> VByte (Char.code (Bytes.get buffer i))) in
                   VArray byte_array
                 with End_of_file ->
                   VArray [||])  (* Return empty array on EOF *)
            | _ -> raise (RuntimeError "CZYTAJ GAZETĘ: pierwszy argument musi być uchwytem pliku do odczytu"))
       | [handle_arg] ->
           (* CZYTAJ BAJT - single argument means read single byte *)
           let handle = eval_expr env handle_arg in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                (try
                   let byte = input_byte ch in
                   VByte byte
                 with End_of_file ->
                   VInt (-1))  (* Return -1 on EOF like C *)
            | _ -> raise (RuntimeError "CZYTAJ: argument musi być uchwytem pliku do odczytu"))
       | _ -> raise (RuntimeError "CZYTAJ oczekuje 1 albo 2 argumentów")));

  (* PISZ(file_handle, data) - write() - Write bytes *)
  ["PISZ"], Some 2, (fun env args ->
      (match args with
       | [handle_arg; data_arg] ->
           let handle = eval_expr env handle_arg in
           let data = eval_expr env data_arg in
           (match handle with
            | VFileHandle (OutputHandle ch) ->
                (match data with
                 | VArray bytes ->
                     (* Write array of bytes *)
                     Array.iter (fun b ->
                       let byte_val = to_int b in
                       output_byte ch byte_val
                     ) bytes;
                     VInt (Array.length bytes)
                 | VString s ->
                     (* Write string as bytes *)
                     output_string ch s;
                     VInt (String.length s)
                 | VByte b | VInt b | VShort b ->
                     (* PISZ BAJT - single byte/int means write single byte *)
                     output_byte ch (b land 0xFF);
                     VInt 1
                 | _ -> raise (RuntimeError "PISZ: dane muszą być tablicą, tekstem albo bajtem"))
            | _ -> raise (RuntimeError "PISZ: pierwszy argument musi być uchwytem pliku do zapisu"))
       | _ -> raise (RuntimeError "PISZ oczekuje 2 argumentów (file_handle, data)"))

  (* SKOCZ(file_handle, offset, [mode]) - lseek() - Seek in file
     mode: 0 = absolute (default), 1 = relative forward, -1 = relative backward *));

  ["SKOCZ"], None, (fun env args ->
      (match args with
       | [handle_arg; offset_arg] ->
           (* Default: absolute seek *)
           let handle = eval_expr env handle_arg in
           let pos = to_int (eval_expr env offset_arg) in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                seek_in ch pos;
                VInt pos
            | VFileHandle (OutputHandle ch) ->
                seek_out ch pos;
                VInt pos
            | _ -> raise (RuntimeError "SKOCZ: pierwszy argument musi być uchwytem pliku"))
       | [handle_arg; offset_arg; mode_arg] ->
           (* With mode: 0 = absolute, 1 = forward, -1 = backward *)
           let handle = eval_expr env handle_arg in
           let offset = to_int (eval_expr env offset_arg) in
           let mode = to_int (eval_expr env mode_arg) in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                let new_pos = match mode with
                  | 0 -> offset  (* Absolute *)
                  | 1 -> pos_in ch + offset  (* Relative forward *)
                  | -1 -> max 0 (pos_in ch - offset)  (* Relative backward *)
                  | _ -> raise (RuntimeError "SKOCZ: tryb musi być 0 (od początku), 1 (do przodu) albo -1 (do tyłu)")
                in
                seek_in ch new_pos;
                VInt new_pos
            | VFileHandle (OutputHandle ch) ->
                let new_pos = match mode with
                  | 0 -> offset  (* Absolute *)
                  | 1 -> pos_out ch + offset  (* Relative forward *)
                  | -1 -> max 0 (pos_out ch - offset)  (* Relative backward *)
                  | _ -> raise (RuntimeError "SKOCZ: tryb musi być 0 (od początku), 1 (do przodu) albo -1 (do tyłu)")
                in
                seek_out ch new_pos;
                VInt new_pos
            | _ -> raise (RuntimeError "SKOCZ: pierwszy argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "SKOCZ oczekuje 2 albo 3 argumentów (file_handle, offset, [mode])")));

  (* POZYCJA(file_handle) - tell() - Get current file position *)
  ["POZYCJA"], Some 1, (fun env args ->
      (match args with
       | [handle_arg] ->
           let handle = eval_expr env handle_arg in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                VInt (pos_in ch)
            | VFileHandle (OutputHandle ch) ->
                VInt (pos_out ch)
            | _ -> raise (RuntimeError "POZYCJA: argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "POZYCJA oczekuje 1 argumentu (file_handle)")));

  (* ============ MULTIDIMENSIONAL ARRAYS ============ *)
  (* TABLICA 2D(rows, cols) - Create 2D array *)
  ["TABLICA 2D"], Some 2, (fun env args ->
      (match args with
       | [rows_arg; cols_arg] ->
           let rows = to_int (eval_expr env rows_arg) in
           let cols = to_int (eval_expr env cols_arg) in
           if rows <= 0 || cols <= 0 then
             raise (RuntimeError "TABLICA 2D: wymiary muszą być dodatnie")
           else
             (* Create array of arrays *)
             let inner_arrays = Array.init rows (fun _ -> VArray (Array.make cols (VInt 0))) in
             VArray inner_arrays
       | _ -> raise (RuntimeError "TABLICA 2D oczekuje 2 argumentów (rows, cols)")));

  (* TABLICA 3D(x, y, z) - Create 3D array *)
  ["TABLICA 3D"], Some 3, (fun env args ->
      (match args with
       | [x_arg; y_arg; z_arg] ->
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           let z = to_int (eval_expr env z_arg) in
           if x <= 0 || y <= 0 || z <= 0 then
             raise (RuntimeError "TABLICA 3D: wymiary muszą być dodatnie")
           else
             (* Create array of arrays of arrays *)
             let inner_arrays = Array.init x (fun _ ->
               VArray (Array.init y (fun _ ->
                 VArray (Array.make z (VInt 0))
               ))
             ) in
             VArray inner_arrays
       | _ -> raise (RuntimeError "TABLICA 3D oczekuje 3 argumentów (x, y, z)")));

  (* POLAŁA SIĘ KREW(format, ...) - Variadic error function like I_Error *)
  ["POLAŁA SIĘ KREW"; "POLALA SIE KREW"], None, (fun env args ->
      (match args with
       | [] -> raise (RuntimeError "POLAŁA SIĘ KREW: potrzeba co najmniej jednego argumentu")
       | format_arg :: rest_args ->
           let format = to_string (eval_expr env format_arg) in
           let arg_values = List.map (eval_expr env) rest_args in
           (* Simple printf-like formatting: replace %d, %s, %i with arguments *)
           let rec format_string fmt args_left acc =
             if String.length fmt = 0 then
               acc
             else if String.length fmt >= 2 && String.get fmt 0 = '%' then
               let spec = String.get fmt 1 in
               match spec, args_left with
               | 'd', v::rest | 'i', v::rest ->
                   let num = to_int v in
                   format_string (String.sub fmt 2 (String.length fmt - 2)) rest (acc ^ string_of_int num)
               | 's', v::rest ->
                   let str = to_string v in
                   format_string (String.sub fmt 2 (String.length fmt - 2)) rest (acc ^ str)
               | '%', _ ->
                   format_string (String.sub fmt 2 (String.length fmt - 2)) args_left (acc ^ "%")
               | _, [] ->
                   (* No more args, keep format specifier *)
                   format_string (String.sub fmt 1 (String.length fmt - 1)) [] (acc ^ String.make 1 (String.get fmt 0))
               | _, _ ->
                   (* Unknown specifier, keep it *)
                   format_string (String.sub fmt 2 (String.length fmt - 2)) args_left (acc ^ "%" ^ String.make 1 spec)
             else
               format_string (String.sub fmt 1 (String.length fmt - 1)) args_left (acc ^ String.make 1 (String.get fmt 0))
           in
           let message = format_string format arg_values "" in
           raise (RuntimeError (Printf.sprintf "I_Error: %s" message))));

  (* ============ GRAPHICS (X11 - DOOM style) ============ *)
  (* OKNO_OTWORZ(width, height, title) - Initialize graphics window *)
  ["OKNO_OTWORZ"; "OKNO OTWORZ"], Some 3, (fun env args ->
      (match args with
       | [width_arg; height_arg; title_arg] ->
           let width = to_int (eval_expr env width_arg) in
           let height = to_int (eval_expr env height_arg) in
           let title = to_string (eval_expr env title_arg) in
           let result = ferdek_window_open width height title in
           if result = 0 then
             raise (RuntimeError "OKNO_OTWORZ: nie udało się otworzyć okna")
           else
             VInt result
       | _ -> raise (RuntimeError "OKNO_OTWORZ oczekuje 3 argumentów (width, height, title)")));

  (* OKNO_ZAMKNIJ() - Close graphics window *)
  ["OKNO_ZAMKNIJ"; "OKNO ZAMKNIJ"], Some 0, (fun env args ->
      (match args with
       | [] ->
           ferdek_window_close ();
           VNull
       | _ -> raise (RuntimeError "OKNO_ZAMKNIJ oczekuje 0 argumentów")));

  (* PALETA_USTAW(palette_array) - Set 256-color palette *)
  ["PALETA_USTAW"; "PALETA USTAW"], Some 1, (fun env args ->
      (match args with
       | [palette_arg] ->
           let palette_val = eval_expr env palette_arg in
           (match palette_val with
            | VArray arr ->
                (* Palette should be 768 bytes (256 colors * 3 RGB) *)
                if Array.length arr <> 768 then
                  raise (RuntimeError "PALETA_USTAW: paleta musi mieć 768 bajtów (256 kolorów * RGB)")
                else begin
                  (* Convert array of VByte to bytes *)
                  let palette_bytes = Bytes.create 768 in
                  Array.iteri (fun i v ->
                    let byte_val = to_int v land 0xFF in
                    Bytes.set palette_bytes i (Char.chr byte_val)
                  ) arr;
                  ferdek_palette_set palette_bytes;
                  VNull
                end
            | _ -> raise (RuntimeError "PALETA_USTAW: argument musi być tablicą"))
       | _ -> raise (RuntimeError "PALETA_USTAW oczekuje 1 argumentu (palette_array)")));

  (* PIKSEL_MALUJ(x, y, color) - Draw pixel *)
  ["PIKSEL_MALUJ"; "PIKSEL MALUJ"], Some 3, (fun env args ->
      (match args with
       | [x_arg; y_arg; color_arg] ->
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           let color = to_int (eval_expr env color_arg) land 0xFF in
           ferdek_pixel_draw x y color;
           VNull
       | _ -> raise (RuntimeError "PIKSEL_MALUJ oczekuje 3 argumentów (x, y, color)")));

  (* EKRAN_ODŚWIEŻ() - Refresh screen (blit framebuffer) *)
  ["EKRAN_ODŚWIEŹ"; "EKRAN_ODŚWIEŻ"; "EKRAN ODŚWIEŹ"; "EKRAN ODŚWIEŻ"; "EKRAN_ODSWIEZ"; "EKRAN ODSWIEZ"], Some 0, (fun env args ->
      (match args with
       | [] ->
           ferdek_screen_refresh ();
           VNull
       | _ -> raise (RuntimeError "EKRAN_ODŚWIEŻ oczekuje 0 argumentów")));

  (* EKRAN_CZYŚĆ(color) - Clear screen to color *)
  ["EKRAN_CZYŚĆ"; "EKRAN CZYŚĆ"; "EKRAN_CZYSĆ"; "EKRAN CZYSĆ"; "EKRAN_CZYSC"; "EKRAN CZYSC"], Some 1, (fun env args ->
      (match args with
       | [color_arg] ->
           let color = to_int (eval_expr env color_arg) land 0xFF in
           ferdek_screen_clear color;
           VNull
       | _ -> raise (RuntimeError "EKRAN_CZYŚĆ oczekuje 1 argumentu (color)")));

  (* BUFOR_RAMKI_POBIERZ(x, y) - Get pixel from framebuffer *)
  ["BUFOR_RAMKI_POBIERZ"; "BUFOR RAMKI POBIERZ"], Some 2, (fun env args ->
      (match args with
       | [x_arg; y_arg] ->
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           let pixel = ferdek_framebuffer_get x y in
           VInt pixel
       | _ -> raise (RuntimeError "BUFOR_RAMKI_POBIERZ oczekuje 2 argumentów (x, y)")));

  (* ZDARZENIE_CZEKAJ() - Poll for event (non-blocking) *)
  ["ZDARZENIE_CZEKAJ"; "ZDARZENIE CZEKAJ"], Some 0, (fun env args ->
      (match args with
       | [] ->
           let (ev_type, key, x, y) = ferdek_event_poll () in
           (* Return array [type, key, x, y] *)
           VArray [| VInt ev_type; VInt key; VInt x; VInt y |]
       | _ -> raise (RuntimeError "ZDARZENIE_CZEKAJ oczekuje 0 argumentów")));

  (* ============ NETWORKING (UDP - DOOM multiplayer style) ============ *)
  (* GNIAZDKO_OTWORZ(port) - Create UDP socket and bind to port *)
  ["GNIAZDKO_OTWORZ"; "GNIAZDKO OTWORZ"], Some 1, (fun env args ->
      (match args with
       | [port_arg] ->
           let port = to_int (eval_expr env port_arg) in
           (try
              let sockfd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
              (* Set non-blocking *)
              Unix.set_nonblock sockfd;
              (* Allow address reuse *)
              Unix.setsockopt sockfd Unix.SO_REUSEADDR true;
              (* Bind to port *)
              let addr = Unix.ADDR_INET (Unix.inet_addr_any, port) in
              Unix.bind sockfd addr;
              Printf.printf "Gniazdko UDP otwarte na porcie %d\n%!" port;
              VInt (Obj.magic sockfd : int)  (* Convert Unix.file_descr to int *)
            with Unix.Unix_error (err, fn, _) ->
              raise (RuntimeError (Printf.sprintf "GNIAZDKO_OTWORZ: %s: %s" fn (Unix.error_message err))))
       | _ -> raise (RuntimeError "GNIAZDKO_OTWORZ oczekuje 1 argumentu (port)")));

  (* GNIAZDKO_WYSLIJ(sockfd, host, port, data) - Send UDP packet *)
  ["GNIAZDKO_WYSLIJ"; "GNIAZDKO WYSLIJ"], Some 4, (fun env args ->
      (match args with
       | [sockfd_arg; host_arg; port_arg; data_arg] ->
           let sockfd = (Obj.magic (to_int (eval_expr env sockfd_arg)) : Unix.file_descr) in
           let host = to_string (eval_expr env host_arg) in
           let port = to_int (eval_expr env port_arg) in
           let data_val = eval_expr env data_arg in
           (match data_val with
            | VString s ->
                (try
                   let addr = Unix.ADDR_INET (Unix.inet_addr_of_string host, port) in
                   let sent = Unix.sendto sockfd (Bytes.of_string s) 0 (String.length s) [] addr in
                   VInt sent
                 with Unix.Unix_error (err, fn, _) ->
                   raise (RuntimeError (Printf.sprintf "GNIAZDKO_WYSLIJ: %s: %s" fn (Unix.error_message err))))
            | VArray arr ->
                (* Convert byte array to string *)
                let bytes = Bytes.create (Array.length arr) in
                Array.iteri (fun i v ->
                  let byte_val = to_int v land 0xFF in
                  Bytes.set bytes i (Char.chr byte_val)
                ) arr;
                (try
                   let addr = Unix.ADDR_INET (Unix.inet_addr_of_string host, port) in
                   let sent = Unix.sendto sockfd bytes 0 (Bytes.length bytes) [] addr in
                   VInt sent
                 with Unix.Unix_error (err, fn, _) ->
                   raise (RuntimeError (Printf.sprintf "GNIAZDKO_WYSLIJ: %s: %s" fn (Unix.error_message err))))
            | _ -> raise (RuntimeError "GNIAZDKO_WYSLIJ: dane muszą być tekstem albo tablicą bajtów"))
       | _ -> raise (RuntimeError "GNIAZDKO_WYSLIJ oczekuje 4 argumentów (sockfd, host, port, data)")));

  (* GNIAZDKO_ODBIERZ(sockfd, bufsize) - Receive UDP packet (non-blocking) *)
  ["GNIAZDKO_ODBIERZ"; "GNIAZDKO ODBIERZ"], Some 2, (fun env args ->
      (match args with
       | [sockfd_arg; bufsize_arg] ->
           let sockfd = (Obj.magic (to_int (eval_expr env sockfd_arg)) : Unix.file_descr) in
           let bufsize = to_int (eval_expr env bufsize_arg) in
           let buffer = Bytes.create bufsize in
           (try
              let (received, from_addr) = Unix.recvfrom sockfd buffer 0 bufsize [] in
              if received = 0 then
                VInt 0  (* No data *)
              else begin
                (* Extract sender info *)
                let (host, port) = match from_addr with
                  | Unix.ADDR_INET (addr, p) -> (Unix.string_of_inet_addr addr, p)
                  | _ -> ("unknown", 0)
                in
                (* Return tuple [data, host, port] *)
                let data_str = Bytes.sub_string buffer 0 received in
                VArray [| VString data_str; VString host; VInt port |]
              end
            with
            | Unix.Unix_error (Unix.EAGAIN, _, _)
            | Unix.Unix_error (Unix.EWOULDBLOCK, _, _) ->
                VInt 0  (* No data available *)
            | Unix.Unix_error (err, fn, _) ->
                raise (RuntimeError (Printf.sprintf "GNIAZDKO_ODBIERZ: %s: %s" fn (Unix.error_message err))))
       | _ -> raise (RuntimeError "GNIAZDKO_ODBIERZ oczekuje 2 argumentów (sockfd, bufsize)")));

  (* GNIAZDKO_ZAMKNIJ(sockfd) - Close UDP socket *)
  ["GNIAZDKO_ZAMKNIJ"; "GNIAZDKO ZAMKNIJ"], Some 1, (fun env args ->
      (match args with
       | [sockfd_arg] ->
           let sockfd = (Obj.magic (to_int (eval_expr env sockfd_arg)) : Unix.file_descr) in
           (try
              Unix.close sockfd;
              Printf.printf "Gniazdko UDP zamknięte\n%!";
              VNull
            with Unix.Unix_error (err, fn, _) ->
              raise (RuntimeError (Printf.sprintf "GNIAZDKO_ZAMKNIJ: %s: %s" fn (Unix.error_message err))))
       | _ -> raise (RuntimeError "GNIAZDKO_ZAMKNIJ oczekuje 1 argumentu (sockfd)")));

  (* WERSALKA: sortowanie, odwracanie, map, filter - zawsze nowa tablica *)
  ["POSKŁADAJ WERSALKĘ"], None, (fun env args ->
      let arr, cmp = match List.map (eval_expr env) args with
        | [VArray a] -> a, (fun x y -> compare_values x y)
        | [VArray a; f] ->
            let f = function_arg "POSKŁADAJ WERSALKĘ" f in
            a, (fun x y -> let r = f [x; y] in compare (to_float r) 0.0)
        | [_] | [_; _] -> raise (RuntimeError "POSKŁADAJ WERSALKĘ: pierwszy argument musi być tablicą")
        | _ -> raise (RuntimeError "POSKŁADAJ WERSALKĘ oczekuje 1 albo 2 argumentów")
      in
      (* stable_sort = merge sort, jak w runtime C - przy remisach ta sama kolejność *)
      VArray (Array.of_list (List.stable_sort cmp (Array.to_list arr))));

  ["ODWRÓĆ WERSALKĘ"], Some 1, (fun env args ->
      match eval_expr env (List.hd args) with
      | VArray a -> VArray (Builtins_list.wersalka_odwroc a)
      | _ -> raise (RuntimeError "ODWRÓĆ WERSALKĘ: argument musi być tablicą"));

  ["PRZERABIAJ WERSALKĘ"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a; f] -> let f = function_arg "PRZERABIAJ WERSALKĘ" f in VArray (Array.map (fun x -> f [x]) a)
      | _ -> raise (RuntimeError "PRZERABIAJ WERSALKĘ: pierwszy argument musi być tablicą"));

  ["PRZEFILTRUJ WERSALKĘ"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a; f] ->
          let f = function_arg "PRZEFILTRUJ WERSALKĘ" f in
          VArray (Array.of_list (List.filter (fun x -> to_bool (f [x])) (Array.to_list a)))
      | _ -> raise (RuntimeError "PRZEFILTRUJ WERSALKĘ: pierwszy argument musi być tablicą"));

  (* SKRZYNKA: pierwiastek, sinus, cosinus (w radianach) - wynik z przecinkiem *)
  ["PIERWIASTEK ZE SKRZYNKI"], Some 1, (fun env args ->
      let x = to_float (eval_expr env (List.hd args)) in
      if x < 0.0 then raise (RuntimeError "PIERWIASTEK ZE SKRZYNKI: pierwiastek z liczby ujemnej");
      VFloat (sqrt x));

  ["SINUS ZE SKRZYNKI"], Some 1, (fun env args -> VFloat (sin (to_float (eval_expr env (List.hd args)))));

  ["COSINUS ZE SKRZYNKI"], Some 1, (fun env args -> VFloat (cos (to_float (eval_expr env (List.hd args)))));

  (* Czas: TRZEBA SPAĆ(ms) usypia, JEST TRZECIA W NOCY() - milisekundy od startu programu *)
  ["TRZEBA SPAĆ"], Some 1, (fun env args ->
      let ms = to_float (eval_expr env (List.hd args)) in
      if ms < 0.0 then raise (RuntimeError "TRZEBA SPAĆ: czas nie może być ujemny");
      flush stdout;
      Unix.sleepf (ms /. 1000.);
      VNull);

  ["JEST TRZECIA W NOCY"], Some 0, (fun _ _ ->
      VInt (int_of_float ((Unix.gettimeofday () -. program_start) *. 1000.)));

  (* PO PIERWSZE PRIMO(x, miejsca) - liczba jako tekst z ustaloną liczbą miejsc po przecinku *)
  ["PO PIERWSZE PRIMO"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [x; places] ->
          let n = to_int places in
          if n < 0 || n > 30 then raise (RuntimeError "PO PIERWSZE PRIMO: liczba miejsc musi być od 0 do 30");
          VString (Printf.sprintf "%.*f" n (to_float x))
      | _ -> VNull);
  ]


let rec import_module env module_name =
  if Hashtbl.mem imported_modules module_name then () else begin
  Hashtbl.add imported_modules module_name ();
  match !module_loader module_name with
  | Some module_ast ->
      (* Execute module in current environment *)
      List.iter (eval_top_level_decl env) module_ast.declarations
  | None ->
      raise (RuntimeError (Printf.sprintf "Nie ma takiego modułu: %s" module_name))
  end

(* ============ TOP-LEVEL DECLARATIONS ============ *)

(* Execute top-level declaration *)
and eval_top_level_decl env = function
  | Import module_name ->
      import_module env module_name

  | Statement stmt ->
      eval_stmt env stmt

  | FunctionDecl fdecl ->
      define_var env fdecl.name (VFunction (fdecl, env))

  | ClassDecl cdecl ->
      (* Store class definition in environment *)
      define_var env cdecl.name (VClass (cdecl, env))

  | StructDecl sdecl ->
      (* Store struct definition in environment *)
      define_var env sdecl.name (VStruct (sdecl, env))

  | UnionDecl udecl ->
      (* Store union definition in environment *)
      define_var env udecl.name (VUnion (udecl, env))

  | EnumDecl edecl ->
      (* Store enum definition in environment *)
      define_var env edecl.name (VEnum (edecl, env));
      (* Also define all enum values as constants *)
      let rec define_enum_values values next_value =
        match values with
        | [] -> ()
        | (name, value_opt) :: rest ->
            let actual_value = match value_opt with
              | Some v -> v
              | None -> next_value
            in
            define_var env name (VInt actual_value);
            define_enum_values rest (actual_value + 1)
      in
      define_enum_values edecl.values 0

(* ============ PROGRAM EXECUTION ============ *)

(* Execute program *)
(* Sesja = środowisko globalne żyjące między kolejnymi programami (REPL) *)
let new_session () =
  Hashtbl.reset imported_modules;
  global_env ()

let eval_in env prog =
  current_loc := ("", 0);
  try
    List.iter (eval_top_level_decl env) prog.declarations;
    Ok ()
  with
  | RuntimeError msg ->
      Error (Printf.sprintf "%s%s" msg (loc_suffix ()))
  | ThrowException value ->
      Error (Printf.sprintf "Nikt nie złapał wyjątku: %s%s" (string_of_value value) (loc_suffix ()))
  | ReturnValue _ -> Error ("I JA INFORMUJĘ ŻE WYCHODZĘ poza funkcją" ^ loc_suffix ())
  | BreakLoop -> Error ("A POCAŁUJCIE MNIE WSZYSCY W DUPĘ poza pętlą" ^ loc_suffix ())
  | ContinueLoop -> Error ("AKUKARACZA poza pętlą" ^ loc_suffix ())
  | Failure msg ->
      Error (Printf.sprintf "Poważna awaria: %s%s" msg (loc_suffix ()))
  | e ->
      Error (Printf.sprintf "Nieoczekiwany błąd: %s%s" (Printexc.to_string e) (loc_suffix ()))

let eval_program prog = eval_in (new_session ()) prog
