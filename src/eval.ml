(* Wykonywanie wyrażeń i instrukcji; builtiny siedzą w tabeli (Interp_builtins) *)

open Ast
open Value

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
       | VFloat f -> VInt (float_to_int "ZAMIEŃ NA FIXED" (f *. 65536.))
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
      Hashtbl.replace captured.vars lambda_marker VNull;
      let rec capture e n =
        if e != global then
          match Hashtbl.find_opt e.vars n with
          | Some v -> Hashtbl.replace captured.vars n v
          | None -> Option.iter (fun p -> capture p n) e.parent in
      List.iter (capture env) (expr_names (Lambda (params, body)));
      VFunction ({ name = "anonimowa"; params; is_variadic = false; has_return = true; body }, captured)

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
      let f = try get_var env name with RuntimeError _ ->
        (* nieznana nazwa: podpowiedź z funkcji i zmiennych programu oraz wbudowanych *)
        raise (RuntimeError (Errors.unknown "funkcja" name
          (visible_names env @ Hashtbl.fold (fun n _ acc -> n :: acc) builtins []))) in
      (match f with
       | VFunction (fdecl, closure_env) ->
           apply_function name fdecl closure_env (List.map (eval_expr env) args)
       | _ -> raise (RuntimeError (Printf.sprintf "%s to nie funkcja" name)))

(* Wywołanie funkcji użytkownika z gotowymi wartościami argumentów (też z builtinów, np. sortowania) *)
and apply_function name (fdecl : function_decl) closure_env arg_values =
    (* Lambda: złapane zmienne kopiujemy do środowiska wywołania, a jego rodzicem jest globalne -
       każde wywołanie zaczyna od tych samych kopii, przypisanie do globalnej działa jak w funkcji *)
    let func_env = match closure_env.parent with
      | Some global when Hashtbl.mem closure_env.vars lambda_marker ->
          { vars = Hashtbl.copy closure_env.vars; parent = Some global }
      | _ -> create_env (Some closure_env) in
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
    let caller_stack = !call_stack in
    call_stack := (fdecl.name, caller_loc) :: caller_stack;
    let result =
      (try
        List.iter (eval_stmt func_env) fdecl.body;
        VNull (* No explicit return *)
      with
      | ReturnValue v -> v
      (* break/continue nie wyskakują z funkcji do pętli, która ją wywołała *)
      | BreakLoop -> raise (Fatal "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ poza pętlą")
      | ContinueLoop -> raise (Fatal "AKUKARACZA poza pętlą"))
    in
    current_loc := caller_loc;
    call_stack := caller_stack;
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
  | VarDecl (name, expr) | ConstDecl (name, expr) ->
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

  | ForEach (var, coll, body) ->
      (* Kolekcja liczona raz, pętla idzie po kopii: tablica - elementy, szafka - klucze
         (posortowane), tekst - znaki *)
      let items = match eval_expr env coll with
        | VArray a -> Array.to_list a
        | VHashMap tbl -> List.map (fun k -> VString k) (Builtins_hashmap.szafka_wszystkie_szufladki tbl)
        | VString s -> List.map (fun c -> VString c) (Array.to_list (Builtins_string.utf8_chars s))
        | _ -> raise (RuntimeError "KRĘCI CEMENT BETONIARA ... Z: po tym nie da się przejść (tablica, szafka albo tekst)")
      in
      (try
        List.iter (fun v ->
          set_var env var v;
          try List.iter (eval_stmt env) body with ContinueLoop -> ()) items
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
      let entry_stack = !call_stack in
      let catch value =
        call_stack := entry_stack;
        let catch_env = create_env (Some env) in
        define_var catch_env catch_var value;
        List.iter (eval_stmt catch_env) catch_stmts in
      (try
        List.iter (eval_stmt env) try_stmts
      with
      | ThrowException value -> catch value
      | RuntimeError msg -> catch (VString msg))   (* błąd wykonania też - jako tekst komunikatu *)

  | Throw expr ->
      let value = eval_expr env expr in
      raise (ThrowException value)

  | Located (file, line, s) ->
      current_loc := (file, line);
      (match !stmt_hook with Some hook -> hook file line env | None -> ());
      eval_stmt env s

  | Break -> raise BreakLoop

  | Continue -> raise ContinueLoop

