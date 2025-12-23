(* Interpreter for Ferdek Programming Language *)

open Ast

(* ============ RUNTIME VALUES ============ *)

(* Runtime value types *)
type value =
  | VInt of int
  | VString of string
  | VBool of bool
  | VNull
  | VArray of value array
  | VHashMap of (string, value) Hashtbl.t  (* SZAFKA - dictionaries/maps *)
  | VFunction of function_decl * environment
  | VClass of class_decl * environment       (* Class definition *)
  | VObject of (string, value) Hashtbl.t
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
  | VObject _ ->
      "<object>"
  | VFileHandle _ ->
      "<file handle>"

(* Convert value to boolean *)
let to_bool = function
  | VBool b -> b
  | VInt 0 -> false
  | VInt _ -> true
  | VString "" -> false
  | VString _ -> true
  | VNull -> false
  | _ -> true

(* Convert value to integer *)
let to_int = function
  | VInt n -> n
  | VBool true -> 1
  | VBool false -> 0
  | VString s -> (try int_of_string s with _ -> 0)
  | VNull -> 0
  | _ -> raise (RuntimeError "Cannot convert to integer")

(* Convert value to string for concatenation *)
let to_string = function
  | VInt n -> string_of_int n
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
