(* Interpreter for Ferdek Programming Language *)

open Ast

(* ============ RUNTIME VALUES ============ *)

(* Runtime value types *)
type value =
  | VInt of int                                      (* Default 32-bit integer *)
  | VByte of int                                     (* 8-bit unsigned (0-255) *)
  | VShort of int                                    (* 16-bit integer *)
  | VFixed of int                                    (* 32-bit fixed-point 16.16 *)
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
    | None -> raise (RuntimeError (Printf.sprintf "Undefined variable: %s" name))

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
let rec string_of_value = function
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
      let pairs = Hashtbl.fold (fun k v acc -> (k ^ ": " ^ string_of_value v) :: acc) tbl [] in
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
  | VString "" -> false
  | VString _ -> true
  | VNull -> false
  | _ -> true

(* Convert value to integer *)
let to_int = function
  | VInt n -> n
  | VByte n -> n
  | VShort n -> n
  | VFixed n -> n  (* Return raw fixed-point value *)
  | VBool true -> 1
  | VBool false -> 0
  | VString s -> (try int_of_string s with _ -> 0)
  | VNull -> 0
  | _ -> raise (RuntimeError "Cannot convert to integer")

(* Convert value to string for concatenation *)
let to_string = function
  | VInt n -> string_of_int n
  | VByte n -> string_of_int n
  | VShort n -> string_of_int n
  | VFixed n -> string_of_int n  (* Show raw fixed value *)
  | VString s -> s
  | VBool true -> "true"
  | VBool false -> "false"
  | VNull -> "null"
  | v -> string_of_value v

(* ============ EXPRESSION EVALUATION ============ *)

(* Evaluate arithmetic operator *)
let eval_arith_op op v1 v2 =
  let n1 = to_int v1 in
  let n2 = to_int v2 in
  VInt (match op with
    | Plus -> n1 + n2
    | Minus -> n1 - n2
    | Multiply -> n1 * n2
    | Divide ->
        if n2 = 0 then raise (RuntimeError "Division by zero")
        else n1 / n2
    | Modulo ->
        if n2 = 0 then raise (RuntimeError "Modulo by zero")
        else n1 mod n2
  )

(* Evaluate comparison operator *)
let eval_comparison_op op v1 v2 =
  let n1 = to_int v1 in
  let n2 = to_int v2 in
  VBool (match op with
    | Equal -> n1 = n2
    | NotEqual -> n1 <> n2
    | Greater -> n1 > n2
    | Less -> n1 < n2
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

(* Evaluate expression *)
let rec eval_expr env = function
  | IntLiteral n -> VInt n
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
  | ToFixed e ->
      (* Convert integer to fixed-point 16.16 format *)
      let v = eval_expr env e in
      let n = to_int v in
      VInt (n lsl 16)
  | FromFixed e ->
      (* Convert from fixed-point 16.16 format to integer *)
      let v = eval_expr env e in
      let n = to_int v in
      VInt (n lsr 16)
  | ArrayAccess (name, index_expr) ->
      let value = get_var env name in
      (match value with
       | VArray arr ->
           let index = to_int (eval_expr env index_expr) in
           if index < 0 || index >= Array.length arr then
             raise (RuntimeError "Array index out of bounds")
           else
             arr.(index)
       | VObject obj ->
           (* Support object field access: obj["field_name"] *)
           let field_name = match eval_expr env index_expr with
             | VString s -> s
             | VInt i -> string_of_int i
             | v -> raise (RuntimeError (Printf.sprintf "Object field name must be a string, got %s" (string_of_value v)))
           in
           (match Hashtbl.find_opt obj field_name with
            | Some v -> v
            | None -> raise (RuntimeError (Printf.sprintf "Object has no field: %s" field_name)))
       | _ -> raise (RuntimeError "Not an array or object"))
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
             raise (RuntimeError (Printf.sprintf "Undefined variable: %s" name)))
       | _ ->
           (* For other expressions, evaluate and create pointer *)
           let value = eval_expr env e in
           VPointer (ref value))
  | Dereference e ->
      (* Dereference a pointer *)
      (match eval_expr env e with
       | VPointer r -> !r
       | _ -> raise (RuntimeError "Cannot dereference non-pointer value"))
  | AddressOf var_name ->
      (* Get address/reference to a variable *)
      (try
        let value = get_var env var_name in
        VPointer (ref value)
      with RuntimeError _ ->
        raise (RuntimeError (Printf.sprintf "Undefined variable: %s" var_name)))
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
            | _ -> raise (RuntimeError "Unsupported pointer arithmetic operation"))
       | _ -> raise (RuntimeError "Invalid pointer arithmetic"))
  | FunctionRef func_name ->
      (* Create a function pointer - get the function and return it as a value *)
      (try
        let func_val = get_var env func_name in
        match func_val with
        | VFunction _ -> func_val  (* Return the function itself as a value *)
        | _ -> raise (RuntimeError (Printf.sprintf "%s is not a function" func_name))
      with RuntimeError _ ->
        raise (RuntimeError (Printf.sprintf "Undefined function: %s" func_name)))
  | Parenthesized e -> eval_expr env e

(* Evaluate function call *)
and eval_function_call env name args =
  (* Check for built-in string functions - only Ferdek-style names from KLAMOTY/KANAPA *)
  match name with
  (* USIĄDŹ NA KANAPIE / USIADZ NA KANAPIE - Konkatenacja stringów *)
  | "USIĄDŹ NA KANAPIE" | "USIADZ NA KANAPIE" ->
      let arg_values = List.map (eval_expr env) args in
      let strings = List.map to_string arg_values in
      VString (String.concat "" strings)

  (* ROZCIĄGNIJ KANAPĘ - Padduje string do określonej długości *)
  | "ROZCIĄGNIJ KANAPĘ" ->
      (match args with
       | [str_arg; len_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let target_len = to_int (eval_expr env len_arg) in
           VString (Builtins_string.kanapa_rozciagnij s target_len)
       | _ -> raise (RuntimeError (Errors.wrong_arg_count "ROZCIĄGNIJ KANAPĘ" 2 (List.length args))))

  (* POTNIJ KANAPĘ - Substring (początek, koniec) *)
  | "POTNIJ KANAPĘ" ->
      (match args with
       | [str_arg; start_arg; end_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let start = to_int (eval_expr env start_arg) in
           let end_pos = to_int (eval_expr env end_arg) in
           (try
             VString (Builtins_string.kanapa_potnij s start end_pos)
           with Failure msg ->
             raise (RuntimeError msg))
       | _ -> raise (RuntimeError (Errors.wrong_arg_count "POTNIJ KANAPĘ" 3 (List.length args))))

  (* PRZESUŃ NA KANAPIE - Split string *)
  | "PRZESUŃ NA KANAPIE" ->
      (match args with
       | [str_arg; sep_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let sep = to_string (eval_expr env sep_arg) in
           let parts = Builtins_string.kanapa_przesun s sep in
           VArray (Array.of_list (List.map (fun p -> VString p) parts))
       | _ -> raise (RuntimeError "PRZESUŃ NA KANAPIE expects 2 arguments"))

  (* POSKŁADAJ KANAPĘ - Join - łączy listę stringów *)
  | "POSKŁADAJ KANAPĘ" ->
      (match args with
       | [arr_arg; sep_arg] ->
           let arr_val = eval_expr env arr_arg in
           let sep = to_string (eval_expr env sep_arg) in
           (match arr_val with
            | VArray arr ->
                let strings = Array.to_list (Array.map to_string arr) in
                VString (String.concat sep strings)
            | _ -> raise (RuntimeError "POSKŁADAJ KANAPĘ expects an array as first argument"))
       | _ -> raise (RuntimeError "POSKŁADAJ KANAPĘ expects 2 arguments"))

  (* WYTRZEP KANAPĘ - Usuwa białe znaki z początku i końca (trim) *)
  | "WYTRZEP KANAPĘ" ->
      (match args with
       | [arg] ->
           let s = to_string (eval_expr env arg) in
           VString (String.trim s)
       | _ -> raise (RuntimeError "WYTRZEP KANAPĘ expects 1 argument"))

  (* ZAMIEŃ NA KANAPIE - Replace *)
  | "ZAMIEŃ NA KANAPIE" ->
      (match args with
       | [str_arg; old_arg; new_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let old_str = to_string (eval_expr env old_arg) in
           let new_str = to_string (eval_expr env new_arg) in
           VString (Builtins_string.kanapa_zamien s old_str new_str)
       | _ -> raise (RuntimeError "ZAMIEŃ NA KANAPIE expects 3 arguments"))

  (* ILE MIEJSCA NA KANAPIE - Zwraca długość stringu *)
  | "ILE MIEJSCA NA KANAPIE" ->
      (match args with
       | [arg] ->
           let v = eval_expr env arg in
           let s = to_string v in
           VInt (String.length s)
       | _ -> raise (RuntimeError "ILE MIEJSCA NA KANAPIE expects 1 argument"))

  (* OTWÓRZ KIBEL(ścieżka) - otwiera plik do odczytu *)
  | "OTWÓRZ KIBEL" ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           (try
             let channel = open_in path in
             VFileHandle (InputHandle channel)
           with Sys_error msg ->
             raise (RuntimeError (Printf.sprintf "OTWÓRZ KIBEL: %s" msg)))
       | _ -> raise (RuntimeError "OTWÓRZ KIBEL expects 1 argument"))

  (* ZAMKNIJ KIBEL(uchwyt) - zamyka plik *)
  | "ZAMKNIJ KIBEL" ->
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
            | _ -> raise (RuntimeError "ZAMKNIJ_KIBEL: argument must be a file handle"))
       | _ -> raise (RuntimeError "ZAMKNIJ_KIBEL expects 1 argument"))

  (* SPUŚĆ WODĘ(uchwyt, dane) - zapisuje do pliku *)
  | "SPUŚĆ WODĘ" ->
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
                raise (RuntimeError "SPUŚĆ_WODĘ: cannot write to input file handle")
            | _ -> raise (RuntimeError "SPUŚĆ_WODĘ: first argument must be a file handle"))
       | _ -> raise (RuntimeError "SPUŚĆ_WODĘ expects 2 arguments"))

  (* WYPOMPUJ(uchwyt) - czyta cały plik *)
  | "WYPOMPUJ" ->
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
                raise (RuntimeError "WYPOMPUJ: cannot read from output file handle")
            | _ -> raise (RuntimeError "WYPOMPUJ: argument must be a file handle"))
       | _ -> raise (RuntimeError "WYPOMPUJ expects 1 argument"))

  (* CZY KIBEL ZAJĘTY(ścieżka) - sprawdza czy plik istnieje *)
  | "CZY KIBEL ZAJĘTY" ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Sys.file_exists path)
       | _ -> raise (RuntimeError "CZY_KIBEL_ZAJĘTY expects 1 argument"))

  (* OTWÓRZ KIBEL DO ZAPISU(ścieżka) - otwiera plik do zapisu *)
  | "OTWÓRZ KIBEL DO ZAPISU" ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           (try
             let channel = open_out path in
             VFileHandle (OutputHandle channel)
           with Sys_error msg ->
             raise (RuntimeError (Printf.sprintf "OTWÓRZ_KIBEL_DO_ZAPISU: %s" msg)))
       | _ -> raise (RuntimeError "OTWÓRZ_KIBEL_DO_ZAPISU expects 1 argument"))

  (* SYSTEM(komenda) - wykonuje komendę systemową i zwraca output *)
  | "SYSTEM" ->
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
             raise (RuntimeError (Printf.sprintf "SYSTEM error: %s" (Unix.error_message err))))
       | _ -> raise (RuntimeError "SYSTEM expects 1 argument"))

  (* ========== SZAFKA (HashMap/Dictionary) operations ========== *)

  (* OTWÓRZ SZAFKĘ() - creates empty dictionary *)
  | "OTWÓRZ SZAFKĘ" ->
      (match args with
       | [] -> VHashMap (Hashtbl.create 16)
       | _ -> raise (RuntimeError "OTWÓRZ SZAFKĘ expects 0 arguments"))

  (* WŁÓŻ DO SZAFKI(dict, key, value) - adds key-value pair *)
  | "WŁÓŻ DO SZAFKI" ->
      (match args with
       | [dict_arg; key_arg; value_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           let value = eval_expr env value_arg in
           (match dict_val with
            | VHashMap tbl ->
                Hashtbl.replace tbl key value;
                VNull
            | _ -> raise (RuntimeError "WŁÓŻ DO SZAFKI: first argument must be a dictionary"))
       | _ -> raise (RuntimeError "WŁÓŻ DO SZAFKI expects 3 arguments"))

  (* WYJMIJ Z SZAFKI(dict, key) - gets value by key *)
  | "WYJMIJ Z SZAFKI" ->
      (match args with
       | [dict_arg; key_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           (match dict_val with
            | VHashMap tbl ->
                (match Hashtbl.find_opt tbl key with
                 | Some v -> v
                 | None -> VNull)
            | _ -> raise (RuntimeError "WYJMIJ Z SZAFKI: first argument must be a dictionary"))
       | _ -> raise (RuntimeError "WYJMIJ Z SZAFKI expects 2 arguments"))

  (* WYRZUĆ ZE SZAFKI(dict, key) - removes key-value pair *)
  | "WYRZUĆ ZE SZAFKI" ->
      (match args with
       | [dict_arg; key_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           (match dict_val with
            | VHashMap tbl ->
                Hashtbl.remove tbl key;
                VNull
            | _ -> raise (RuntimeError "WYRZUĆ ZE SZAFKI: first argument must be a dictionary"))
       | _ -> raise (RuntimeError "WYRZUĆ ZE SZAFKI expects 2 arguments"))

  (* CZY W SZAFCE(dict, key) - checks if key exists *)
  | "CZY W SZAFCE" ->
      (match args with
       | [dict_arg; key_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           (match dict_val with
            | VHashMap tbl ->
                VBool (Builtins_hashmap.szafka_czy_w_szafce tbl key)
            | _ -> raise (RuntimeError "CZY W SZAFCE: first argument must be a dictionary"))
       | _ -> raise (RuntimeError "CZY W SZAFCE expects 2 arguments"))

  (* WSZYSTKIE SZUFLADKI(dict) - returns list of all keys *)
  | "WSZYSTKIE SZUFLADKI" ->
      (match args with
       | [dict_arg] ->
           let dict_val = eval_expr env dict_arg in
           (match dict_val with
            | VHashMap tbl ->
                let keys = Builtins_hashmap.szafka_wszystkie_szufladki tbl in
                VArray (Array.of_list (List.map (fun k -> VString k) keys))
            | _ -> raise (RuntimeError "WSZYSTKIE SZUFLADKI: argument must be a dictionary"))
       | _ -> raise (RuntimeError "WSZYSTKIE SZUFLADKI expects 1 argument"))

  (* ILE W SZAFCE(dict) - returns number of elements *)
  | "ILE W SZAFCE" ->
      (match args with
       | [dict_arg] ->
           let dict_val = eval_expr env dict_arg in
           (match dict_val with
            | VHashMap tbl ->
                VInt (Builtins_hashmap.szafka_ile_w_szafce tbl)
            | _ -> raise (RuntimeError "ILE W SZAFCE: argument must be a dictionary"))
       | _ -> raise (RuntimeError "ILE W SZAFCE expects 1 argument"))

  (* ========== KIBEL (File operations) ========== *)

  (* ZRÓB KIBEL(path) - creates directory *)
  | "ZRÓB KIBEL" ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Builtins_file.kibel_zrob path)
       | _ -> raise (RuntimeError "ZRÓB KIBEL expects 1 argument"))

  (* WYWAL KIBEL(path) - removes directory *)
  | "WYWAL KIBEL" ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Builtins_file.kibel_wywal path)
       | _ -> raise (RuntimeError "WYWAL KIBEL expects 1 argument"))

  (* CO W KIBLU(path) - lists files in directory *)
  | "CO W KIBLU" ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           let files = Builtins_file.kibel_co_w_kiblu path in
           VArray (Array.of_list (List.map (fun f -> VString f) files))
       | _ -> raise (RuntimeError "CO W KIBLU expects 1 argument"))

  (* CZY TO KIBEL(path) - checks if path is directory *)
  | "CZY TO KIBEL" ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Builtins_file.kibel_czy_to_kibel path)
       | _ -> raise (RuntimeError "CZY TO KIBEL expects 1 argument"))

  (* PRZEKOPIUJ KIBEL(src, dest) - copies file *)
  | "PRZEKOPIUJ KIBEL" ->
      (match args with
       | [src_arg; dest_arg] ->
           let src = to_string (eval_expr env src_arg) in
           let dest = to_string (eval_expr env dest_arg) in
           VBool (Builtins_file.kibel_przekopiuj src dest)
       | _ -> raise (RuntimeError "PRZEKOPIUJ KIBEL expects 2 arguments"))

  (* PRZENIEŚ KIBEL(src, dest) - moves/renames file *)
  | "PRZENIEŚ KIBEL" ->
      (match args with
       | [src_arg; dest_arg] ->
           let src = to_string (eval_expr env src_arg) in
           let dest = to_string (eval_expr env dest_arg) in
           VBool (Builtins_file.kibel_przenies src dest)
       | _ -> raise (RuntimeError "PRZENIEŚ KIBEL expects 2 arguments"))

  (* WYKOP WSZYSTKIE KIBLE(path) - recursive delete *)
  | "WYKOP WSZYSTKIE KIBLE" ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           Builtins_file.kibel_wykop_wszystkie path;
           VNull
       | _ -> raise (RuntimeError "WYKOP WSZYSTKIE KIBLE expects 1 argument"))

  (* ========== WERSALKA (List/Array operations) ========== *)

  (* ILE NA WERSALCE(array) - returns array length *)
  | "ILE NA WERSALCE" ->
      (match args with
       | [arr_arg] ->
           let arr_val = eval_expr env arr_arg in
           (match arr_val with
            | VArray arr -> VInt (Builtins_list.wersalka_ile_na arr)
            | _ -> raise (RuntimeError "ILE NA WERSALCE: argument must be an array"))
       | _ -> raise (RuntimeError "ILE NA WERSALCE expects 1 argument"))

  (* POŁÓŻ NA WERSALCE(array, element) - appends element to array *)
  | "POŁÓŻ NA WERSALCE" ->
      (match args with
       | [arr_arg; elem_arg] ->
           let arr_val = eval_expr env arr_arg in
           let elem = eval_expr env elem_arg in
           (match arr_val with
            | VArray arr ->
                let new_arr = Builtins_list.wersalka_poloz_na arr elem in
                VArray new_arr
            | _ -> raise (RuntimeError "POŁÓŻ NA WERSALCE: first argument must be an array"))
       | _ -> raise (RuntimeError "POŁÓŻ NA WERSALCE expects 2 arguments"))

  (* ZDEJMIJ Z WERSALKI(array) - pops last element *)
  | "ZDEJMIJ Z WERSALKI" ->
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
            | _ -> raise (RuntimeError "ZDEJMIJ Z WERSALKI: argument must be an array"))
       | _ -> raise (RuntimeError "ZDEJMIJ Z WERSALKI expects 1 argument"))

  (* CZY LEŻY NA WERSALCE(array, element) - checks if element is in array *)
  | "CZY LEŻY NA WERSALCE" ->
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
            | _ -> raise (RuntimeError "CZY LEŻY NA WERSALCE: first argument must be an array"))
       | _ -> raise (RuntimeError "CZY LEŻY NA WERSALCE expects 2 arguments"))

  (* ============ MEMORY MANAGEMENT (DOOM-style Zone Allocator) ============ *)

  (* DAJ MI HAJS - Z_Malloc(size, tag) - Allocate memory block *)
  | "DAJ MI HAJS" ->
      (match args with
       | [size_arg; tag_arg] ->
           let size = to_int (eval_expr env size_arg) in
           let tag_val = to_int (eval_expr env tag_arg) in
           if size <= 0 then
             raise (RuntimeError "DAJ MI HAJS: size must be positive")
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
       | _ -> raise (RuntimeError "DAJ MI HAJS expects 2 arguments (size, tag)"))

  (* ODDAJ_WSZYSTKO - Z_Free(ptr) - Free memory block *)
  | "ODDAJ WSZYSTKO" ->
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
                       raise (RuntimeError "ODDAJ WSZYSTKO: block does not exist")
                 | _ -> raise (RuntimeError "ODDAJ WSZYSTKO: invalid pointer"))
            | _ -> raise (RuntimeError "ODDAJ WSZYSTKO expects a pointer"))
       | _ -> raise (RuntimeError "ODDAJ WSZYSTKO expects 1 argument (pointer)"))

  (* KOMORNICZY_WINDYKACJA - Z_FreeTags(lowtag, hightag) - Free blocks by tag range *)
  | "KOMORNICZY WINDYKACJA" ->
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
       | _ -> raise (RuntimeError "KOMORNICZY WINDYKACJA expects 2 arguments (lowtag, hightag)"))

  (* ZAPISZ_DO_BLOKU - Write to memory block *)
  | "ZAPISZ DO BLOKU" ->
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
                         raise (RuntimeError (Printf.sprintf "ZAPISZ DO BLOKU: index %d out of bounds (size: %d)" index block.size))
                     end else
                       raise (RuntimeError "ZAPISZ DO BLOKU: block does not exist")
                 | _ -> raise (RuntimeError "ZAPISZ DO BLOKU: invalid pointer"))
            | _ -> raise (RuntimeError "ZAPISZ DO BLOKU expects a pointer as first argument"))
       | _ -> raise (RuntimeError "ZAPISZ DO BLOKU expects 3 arguments (ptr, index, value)"))

  (* CZYTAJ_Z_BLOKU - Read from memory block *)
  | "CZYTAJ Z BLOKU" ->
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
                         raise (RuntimeError (Printf.sprintf "CZYTAJ Z BLOKU: index %d out of bounds (size: %d)" index block.size))
                     end else
                       raise (RuntimeError "CZYTAJ Z BLOKU: block does not exist")
                 | _ -> raise (RuntimeError "CZYTAJ Z BLOKU: invalid pointer"))
            | _ -> raise (RuntimeError "CZYTAJ Z BLOKU expects a pointer as first argument"))
       | _ -> raise (RuntimeError "CZYTAJ Z BLOKU expects 2 arguments (ptr, index)"))

  (* ROZMIAR_BLOKU - Get memory block size *)
  | "ROZMIAR BLOKU" ->
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
                       raise (RuntimeError "ROZMIAR BLOKU: block does not exist")
                 | _ -> raise (RuntimeError "ROZMIAR BLOKU: invalid pointer"))
            | _ -> raise (RuntimeError "ROZMIAR BLOKU expects a pointer"))
       | _ -> raise (RuntimeError "ROZMIAR BLOKU expects 1 argument (pointer)"))

  (* ILE_KASY_LECI - Get memory statistics *)
  | "ILE KASY LECI" ->
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
       | _ -> raise (RuntimeError "ILE KASY LECI expects no arguments"))

  (* TAG_TRWALE - Memory tag constant (PU_STATIC) *)
  | "TAG_TRWALE" ->
      (match args with
       | [] -> VInt 1
       | _ -> raise (RuntimeError "TAG_TRWALE is a constant, no arguments expected"))

  (* TAG_POZIOM - Memory tag constant (PU_LEVEL) *)
  | "TAG_POZIOM" ->
      (match args with
       | [] -> VInt 50
       | _ -> raise (RuntimeError "TAG_POZIOM is a constant, no arguments expected"))

  (* TAG_SMIECIOWE - Memory tag constant (PU_CACHE) *)
  | "TAG_SMIECIOWE" ->
      (match args with
       | [] -> VInt 100
       | _ -> raise (RuntimeError "TAG_SMIECIOWE is a constant, no arguments expected"))

  (* ============ FRAMEBUFFER FUNCTIONS (TELEWIZOR) ============ *)

  (* WŁĄCZ TELEWIZOR(width, height) - Create framebuffer *)
  | "WŁĄCZ TELEWIZOR" | "WLACZ TELEWIZOR" ->
      (match args with
       | [width_arg; height_arg] ->
           let width = to_int (eval_expr env width_arg) in
           let height = to_int (eval_expr env height_arg) in
           if width <= 0 || height <= 0 then
             raise (RuntimeError "WŁĄCZ TELEWIZOR: width and height must be positive")
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
       | _ -> raise (RuntimeError "WŁĄCZ TELEWIZOR expects 2 arguments (width, height)"))

  (* WYŁĄCZ TELEWIZOR(fb_ptr) - Destroy framebuffer *)
  | "WYŁĄCZ TELEWIZOR" | "WYLACZ TELEWIZOR" ->
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
                       raise (RuntimeError "WYŁĄCZ TELEWIZOR: invalid framebuffer")
                 | _ -> raise (RuntimeError "WYŁĄCZ TELEWIZOR: argument must be framebuffer pointer"))
            | _ -> raise (RuntimeError "WYŁĄCZ TELEWIZOR: argument must be framebuffer pointer"))
       | _ -> raise (RuntimeError "WYŁĄCZ TELEWIZOR expects 1 argument (framebuffer)"))

  (* ZMIEŃ KANAŁ(fb_ptr, x, y, color) - Write pixel to framebuffer *)
  | "ZMIEŃ KANAŁ" | "ZMIEN KANAL" ->
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
                         raise (RuntimeError "ZMIEŃ KANAŁ: pixel coordinates out of bounds")
                       else begin
                         let offset = y * fb.width + x in
                         fb.pixels.(offset) <- color;
                         VNull
                       end
                     end else
                       raise (RuntimeError "ZMIEŃ KANAŁ: invalid framebuffer")
                 | _ -> raise (RuntimeError "ZMIEŃ KANAŁ: first argument must be framebuffer pointer"))
            | _ -> raise (RuntimeError "ZMIEŃ KANAŁ: first argument must be framebuffer pointer"))
       | _ -> raise (RuntimeError "ZMIEŃ KANAŁ expects 4 arguments (framebuffer, x, y, color)"))

  (* CO LECI W TELEWIZORZE(fb_ptr, x, y) - Read pixel from framebuffer *)
  | "CO LECI W TELEWIZORZE" ->
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
                         raise (RuntimeError "CO LECI W TELEWIZORZE: pixel coordinates out of bounds")
                       else begin
                         let offset = y * fb.width + x in
                         VInt fb.pixels.(offset)
                       end
                     end else
                       raise (RuntimeError "CO LECI W TELEWIZORZE: invalid framebuffer")
                 | _ -> raise (RuntimeError "CO LECI W TELEWIZORZE: first argument must be framebuffer pointer"))
            | _ -> raise (RuntimeError "CO LECI W TELEWIZORZE: first argument must be framebuffer pointer"))
       | _ -> raise (RuntimeError "CO LECI W TELEWIZORZE expects 3 arguments (framebuffer, x, y)"))

  (* ============ LOOKUP TABLE FUNCTIONS ============ *)

  (* STWÓRZ TABELĘ(size) - Create lookup table *)
  | "STWÓRZ TABELĘ" | "STWORZ TABELE" ->
      (match args with
       | [size_arg] ->
           let size = to_int (eval_expr env size_arg) in
           if size <= 0 then
             raise (RuntimeError "STWÓRZ TABELĘ: size must be positive")
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
       | _ -> raise (RuntimeError "STWÓRZ TABELĘ expects 1 argument (size)"))

  (* WPISZ DO TABELI(table_ptr, index, value) - Write to lookup table *)
  | "WPISZ DO TABELI" ->
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
                         raise (RuntimeError "WPISZ DO TABELI: index out of bounds")
                       else begin
                         table.data.(index) <- value;
                         VNull
                       end
                     end else
                       raise (RuntimeError "WPISZ DO TABELI: invalid lookup table")
                 | _ -> raise (RuntimeError "WPISZ DO TABELI: first argument must be table pointer"))
            | _ -> raise (RuntimeError "WPISZ DO TABELI: first argument must be table pointer"))
       | _ -> raise (RuntimeError "WPISZ DO TABELI expects 3 arguments (table, index, value)"))

  (* SPRAWDŹ W TABELI(table_ptr, index) - Read from lookup table *)
  | "SPRAWDŹ W TABELI" | "SPRAWDZ W TABELI" ->
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
                         raise (RuntimeError "SPRAWDŹ W TABELI: index out of bounds")
                       else
                         VInt table.data.(index)
                     end else
                       raise (RuntimeError "SPRAWDŹ W TABELI: invalid lookup table")
                 | _ -> raise (RuntimeError "SPRAWDŹ W TABELI: first argument must be table pointer"))
            | _ -> raise (RuntimeError "SPRAWDŹ W TABELI: first argument must be table pointer"))
       | _ -> raise (RuntimeError "SPRAWDŹ W TABELI expects 2 arguments (table, index)"))

  (* ============ DIRECT MEMORY ACCESS ============ *)

  (* PISZ BAJT(ptr, offset, value) - Write byte directly to memory block *)
  | "PISZ BAJT" ->
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
                         raise (RuntimeError "PISZ BAJT: offset out of bounds")
                       else begin
                         block.data.(offset) <- VInt value;
                         VNull
                       end
                     end else
                       raise (RuntimeError "PISZ BAJT: invalid memory block")
                 | _ -> raise (RuntimeError "PISZ BAJT: first argument must be pointer"))
            | _ -> raise (RuntimeError "PISZ BAJT: first argument must be pointer"))
       | _ -> raise (RuntimeError "PISZ BAJT expects 3 arguments (ptr, offset, value)"))

  (* CZYTAJ BAJT(ptr, offset) - Read byte directly from memory block *)
  | "CZYTAJ BAJT" ->
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
                         raise (RuntimeError "CZYTAJ BAJT: offset out of bounds")
                       else
                         block.data.(offset)
                     end else
                       raise (RuntimeError "CZYTAJ BAJT: invalid memory block")
                 | _ -> raise (RuntimeError "CZYTAJ BAJT: first argument must be pointer"))
            | _ -> raise (RuntimeError "CZYTAJ BAJT: first argument must be pointer"))
       | _ -> raise (RuntimeError "CZYTAJ BAJT expects 2 arguments (ptr, offset)"))

  (* KOPIUJ PAMIĘĆ(src_ptr, dst_ptr, size) - Memory copy (like memcpy) *)
  | "KOPIUJ PAMIĘĆ" | "KOPIUJ PAMIEC" ->
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
                         raise (RuntimeError "KOPIUJ PAMIĘĆ: size exceeds block size")
                       else begin
                         Array.blit src_block.data 0 dst_block.data 0 size;
                         VNull
                       end
                     end else
                       raise (RuntimeError "KOPIUJ PAMIĘĆ: invalid memory blocks")
                 | _ -> raise (RuntimeError "KOPIUJ PAMIĘĆ: arguments must be pointers"))
            | _ -> raise (RuntimeError "KOPIUJ PAMIĘĆ: arguments must be pointers"))
       | _ -> raise (RuntimeError "KOPIUJ PAMIĘĆ expects 3 arguments (src, dst, size)"))

  (* ============ TYPE CASTING FUNCTIONS ============ *)

  (* ZRÓB BAJCIK(expr) - Cast to byte (0-255) *)
  | "ZRÓB BAJCIK" | "ZROB BAJCIK" ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           VByte (value land 0xFF)  (* Mask to 0-255 *)
       | _ -> raise (RuntimeError "ZRÓB BAJCIK expects 1 argument"))

  (* ZRÓB KRÓTKI(expr) - Cast to short (16-bit) *)
  | "ZRÓB KRÓTKI" | "ZROB KROTKI" ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           (* Sign-extend from 16-bit *)
           let masked = value land 0xFFFF in
           let short_val = if masked > 0x7FFF then masked - 0x10000 else masked in
           VShort short_val
       | _ -> raise (RuntimeError "ZRÓB KRÓTKI expects 1 argument"))

  (* ZRÓB DŁUGI(expr) - Cast to int (32-bit, default) *)
  | "ZRÓB DŁUGI" | "ZROB DLUGI" ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           VInt value
       | _ -> raise (RuntimeError "ZRÓB DŁUGI expects 1 argument"))

  (* ZRÓB UŁAMEK(expr) - Cast to fixed-point (same as ZAMIEŃ NA FIXED) *)
  | "ZRÓB UŁAMEK" | "ZROB ULAMEK" ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           VFixed (value lsl 16)  (* Convert to 16.16 fixed-point *)
       | _ -> raise (RuntimeError "ZRÓB UŁAMEK expects 1 argument"))

  (* CO TO ZA TYP(var) - Return type name *)
  | "CO TO ZA TYP" ->
      (match args with
       | [arg] ->
           let value = eval_expr env arg in
           let type_name = match value with
             | VByte _ -> "BAJCIK"
             | VShort _ -> "KRÓTKI"
             | VInt _ -> "DŁUGI"
             | VFixed _ -> "UŁAMEK"
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
       | _ -> raise (RuntimeError "CO TO ZA TYP expects 1 argument"))

  | _ ->
      (* Try to find user-defined function *)
      try
        let func = get_var env name in
        match func with
        | VFunction (fdecl, closure_env) ->
            (* Create new environment for function execution *)
            let func_env = create_env (Some closure_env) in

            (* Evaluate arguments *)
            let arg_values = List.map (eval_expr env) args in

            (* Bind parameters *)
            if List.length fdecl.params <> List.length arg_values then
              raise (RuntimeError (Printf.sprintf "Function %s expects %d arguments, got %d"
                                    name (List.length fdecl.params) (List.length arg_values)));

            List.iter2 (fun param value -> define_var func_env param value)
              fdecl.params arg_values;

            (* Execute function body *)
            (try
              List.iter (eval_stmt func_env) fdecl.body;
              VNull (* No explicit return *)
            with ReturnValue v -> v)
        | _ -> raise (RuntimeError (Printf.sprintf "%s is not a function" name))
      with RuntimeError _ as e -> raise e

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
                     let method_env = create_env (Some parent_env) in
                     Hashtbl.iter (fun fn fv -> define_var method_env fn fv) obj;
                     Hashtbl.replace obj method_decl.name (VFunction (method_decl, method_env))
                   ) parent_cdecl.methods
               | _ -> raise (RuntimeError (Printf.sprintf "Parent %s is not a class" parent_name))
             with RuntimeError _ ->
               raise (RuntimeError (Printf.sprintf "Undefined parent class: %s" parent_name)))
         | None -> ());

        (* Initialize fields from class definition (may override parent fields) *)
        List.iter (fun (field_name, init_expr) ->
          let field_value = eval_expr class_env init_expr in
          Hashtbl.replace obj field_name field_value
        ) cdecl.fields;

        (* Add methods to object (may override parent methods) *)
        List.iter (fun (method_decl : function_decl) ->
          let method_env = create_env (Some class_env) in
          Hashtbl.iter (fun field_name field_value ->
            define_var method_env field_name field_value
          ) obj;
          Hashtbl.replace obj method_decl.name (VFunction (method_decl, method_env))
        ) cdecl.methods;

        VObject obj
    | _ ->
        raise (RuntimeError (Printf.sprintf "%s is not a class" class_name))
  with RuntimeError _ ->
    raise (RuntimeError (Printf.sprintf "Undefined class: %s" class_name))

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
        raise (RuntimeError (Printf.sprintf "%s is not a struct" struct_name))
  with RuntimeError _ ->
    raise (RuntimeError (Printf.sprintf "Undefined struct: %s" struct_name))

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
        raise (RuntimeError (Printf.sprintf "%s is not a union" union_name))
  with RuntimeError _ ->
    raise (RuntimeError (Printf.sprintf "Undefined union: %s" union_name))

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

  | Read name ->
      let line = read_line () in
      let value = try VInt (int_of_string line) with _ -> VString line in
      set_var env name value

  | Assign (name, expr) ->
      let value = eval_expr env expr in
      set_var env name value

  | ArrayAssign (name, idx_expr, value_expr) ->
      let container = get_var env name in
      let value = eval_expr env value_expr in
      (match container with
       | VArray arr_vals ->
           let idx = eval_expr env idx_expr in
           (match idx with
            | VInt i ->
                if i < 0 || i >= Array.length arr_vals then
                  raise (Failure (Printf.sprintf "Indeks poza zakresem: %d" i))
                else
                  arr_vals.(i) <- value
            | _ ->
                raise (Failure "Indeks tablicy musi być liczbą całkowitą"))
       | VObject obj ->
           (* Support object field assignment: obj["field_name"] = value *)
           let field_name = match eval_expr env idx_expr with
             | VString s -> s
             | VInt i -> string_of_int i
             | v -> raise (RuntimeError (Printf.sprintf "Object field name must be a string, got %s" (string_of_value v)))
           in
           Hashtbl.replace obj field_name value
       | _ ->
           raise (Failure (Printf.sprintf "%s nie jest tablicą ani obiektem" name))
      )

  | If (cond, then_stmts, else_stmts_opt) ->
      let cond_value = eval_expr env cond in
      if to_bool cond_value then
        List.iter (eval_stmt env) then_stmts
      else
        (match else_stmts_opt with
         | Some else_stmts -> List.iter (eval_stmt env) else_stmts
         | None -> ())

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

  | Break -> raise BreakLoop

  | Continue -> raise ContinueLoop

(* ============ MODULE LOADING ============ *)

(* Module loader function type - will be set by the main program *)
let module_loader : (string -> program option) ref = ref (fun _ -> None)

(* Set the module loader function *)
let set_module_loader loader =
  module_loader := loader

(* Import a module *)
let rec import_module env module_name =
  match !module_loader module_name with
  | Some module_ast ->
      (* Execute module in current environment *)
      List.iter (eval_top_level_decl env) module_ast.declarations
  | None ->
      Printf.eprintf "Failed to load module: %s\n" module_name

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
let eval_program prog =
  let env = global_env () in
  try
    List.iter (eval_top_level_decl env) prog.declarations;
    Ok ()
  with
  | RuntimeError msg ->
      Error (Printf.sprintf "Runtime error: %s" msg)
  | ThrowException value ->
      Error (Printf.sprintf "Uncaught exception: %s" (string_of_value value))
  | Failure msg ->
      Error (Printf.sprintf "Fatal error: %s" msg)
  | e ->
      Error (Printf.sprintf "Unexpected error: %s" (Printexc.to_string e))
