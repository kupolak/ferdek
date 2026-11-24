(* Wykonywanie wyrażeń i instrukcji. AST kompilujemy raz do domknięć OCamla (code: środowisko ->
   wartość), więc przy każdym wykonaniu nie ma już dopasowywania drzewa ani szukania builtinów.
   Zmienne funkcji leżą w slotach (Value.environment), a globalne czytamy przez zapamiętaną
   komórkę tablicy. Znaczenie programu jest dokładnie takie jak przy szukaniu po nazwie:
   pusty slot albo nietrafiona pamięć podręczna wracają do get_var/set_var. Builtiny siedzą
   w tabeli (moduły builtins/) i dostają argumenty już skompilowane. *)

open Ast
open Value

type scode = environment -> unit

(* Tryb kompilacji: układ slotów funkcji, której ciało kompilujemy; None - zmienne tylko po nazwie
   (program główny, catch, moduły, debugger - środowisko bez slotów albo nieznane z góry) *)
type cx = { layout : int Vars.t option }

let dynamic = { layout = None }

(* ============ ZMIENNE ============ *)

(* Pamięć podręczna jednego miejsca w kodzie: środowisko i komórka, w której ostatnio była zmienna *)
type cache = { mutable env : environment; mutable cell : value Vars.cell }

let dummy_env = create_env None
let new_cache () = { env = dummy_env; cell = { Vars.key = ""; hash = 0; data = VNull; next = Vars.Empty } }

(* Odczyt, gdy bliższe środowiska już odpadły i szukanie zaczyna się od e. Komórka jest ważna, dopóki
   e to to samo środowisko: wpisy nigdy nie znikają, a e bez slotów nie ma nic, co by je przesłoniło. *)
let read_in cache name h e orig =
  if e == cache.env then cache.cell.data
  else if e.layout == no_layout then
    match Vars.find_cell_h e.vars name h with
    | Some c -> cache.env <- e; cache.cell <- c; c.data
    | None -> get_var_h orig name h
  else get_var_h orig name h

let slot_of cx name h = match cx.layout with Some l -> Vars.find_h l name h | None -> None

let reader cx name : code =
  let h = Vars.hash name in
  let cache = new_cache () in
  match cx.layout, slot_of cx name h with
  | _, Some i ->
      (* pusty slot: zmienna jeszcze nie lokalna - np. pole obiektu albo globalna zmieniana w funkcji *)
      fun env -> let v = env.slots.(i) in
        if v != unset then v
        else (match env.parent with
          | Some p when Vars.is_empty env.vars -> read_in cache name h p env
          | _ -> get_var_h env name h)
  | Some _, None ->
      (* nazwa spoza funkcji (globalna, funkcja, pole obiektu): od rodzica, jeśli tu nic nie ma *)
      fun env -> (match env.parent with
        | Some p when Vars.is_empty env.vars -> read_in cache name h p env
        | _ -> get_var_h env name h)
  | None, None -> fun env -> read_in cache name h env env

(* Przypisanie: jak set_var - tutaj, jeśli jest; u rodzica, jeśli tam; inaczej nowa tutaj *)
let writer cx name : environment -> value -> unit =
  let h = Vars.hash name in
  let cache = new_cache () in
  match cx.layout, slot_of cx name h with
  | _, Some i -> fun env v ->
      if env.slots.(i) != unset then env.slots.(i) <- v
      else (match env.parent with
        (* tu jej nie ma: u rodzica (pole obiektu, globalna) przez zapamiętaną komórkę *)
        | Some p when Vars.is_empty env.vars && p.layout == no_layout ->
            if p == cache.env then cache.cell.data <- v
            else (match Vars.find_cell_h p.vars name h with
              | Some cl -> cache.env <- p; cache.cell <- cl; cl.data <- v
              | None -> set_var_h env name h v)
        | _ -> set_var_h env name h v)
  | Some _, None -> fun env v -> set_var_h env name h v
  | None, None -> fun env v ->
      if env == cache.env then cache.cell.data <- v
      else if env.layout == no_layout then
        match Vars.find_cell_h env.vars name h with
        | Some c -> cache.env <- env; cache.cell <- c; c.data <- v
        | None -> set_var_h env name h v
      else set_var_h env name h v

(* Deklaracja: zawsze w bieżącym środowisku *)
let definer cx name : environment -> value -> unit =
  let h = Vars.hash name in
  let cache = new_cache () in
  match slot_of cx name h with
  | Some i -> fun env v -> env.slots.(i) <- v
  | None -> fun env v ->
      if env == cache.env then cache.cell.data <- v
      else begin
        define_var_h env name h v;
        if env.layout == no_layout then
          Option.iter (fun c -> cache.env <- env; cache.cell <- c) (Vars.find_cell_h env.vars name h)
      end

(* ============ SKOMPILOWANE FUNKCJE ============ *)

(* Funkcja po kompilacji: układ slotów (parametry, varargs, zadeklarowane i przypisane w ciele),
   numery slotów parametrów, ciało i wartości domyślne *)
type cfun = {
  layout : int Vars.t;
  nslots : int;
  param_slots : int array;
  varargs_slot : int;
  body : scode;
  defaults : (string * code) list;
}

(* Każda deklaracja funkcji kompilowana raz; klucz to sama deklaracja (porównanie fizyczne) *)
let memo tbl name key compute =
  let entries = Option.value (Vars.find_opt tbl name) ~default:[] in
  match List.assq_opt key entries with
  | Some v -> v
  | None -> let v = compute () in Vars.replace tbl name ((key, v) :: entries); v

let compile_block_ref : (cx -> stmt list -> scode) ref = ref (fun _ _ _ -> ())
let compile_expr_ref : (cx -> expr -> code) ref = ref (fun _ _ _ -> VNull)

let functions : (function_decl * cfun) list Vars.t = Vars.create 64

let compiled_function (fdecl : function_decl) =
  memo functions fdecl.name fdecl (fun () ->
    let params = fdecl.params @ (if fdecl.is_variadic then ["varargs"] else []) in
    let decl, assigned = targets_block ([], []) fdecl.body in
    let layout = Vars.create 16 in
    List.iter (fun n -> if not (Vars.mem layout n) then Vars.replace layout n layout.Vars.size)
      (params @ decl @ assigned);
    let cx = { layout = Some layout } in
    let slot n = Option.get (Vars.find_opt layout n) in
    { layout; nslots = layout.Vars.size;
      param_slots = Array.of_list (List.map slot fdecl.params);
      varargs_slot = (if fdecl.is_variadic then slot "varargs" else -1);
      body = !compile_block_ref cx fdecl.body;
      defaults = List.map (fun (p, e) -> (p, !compile_expr_ref cx e)) fdecl.defaults })

(* Sloty nowego wywołania: małe tablice literałem (bez wywołania C jak Array.make) *)
let new_slots = function
  | 0 -> [||] | 1 -> [| unset |] | 2 -> [| unset; unset |] | 3 -> [| unset; unset; unset |]
  | 4 -> [| unset; unset; unset; unset |] | 5 -> [| unset; unset; unset; unset; unset |]
  | 6 -> [| unset; unset; unset; unset; unset; unset |]
  | n -> Array.make n unset

(* Wywołanie funkcji użytkownika z gotowymi wartościami argumentów; cf - jej skompilowana postać *)
let apply_compiled name (fdecl : function_decl) cf closure_env arg_values =
  let slots = new_slots cf.nslots in
  (* Lambda: złapane zmienne kopiujemy do środowiska wywołania, a jego rodzicem jest globalne -
     każde wywołanie zaczyna od tych samych kopii, przypisanie do globalnej działa jak w funkcji *)
  let func_env = match closure_env.parent with
    | Some global when Vars.mem closure_env.vars lambda_marker ->
        { vars = Vars.copy closure_env.vars; parent = Some global; slots; layout = cf.layout }
    | _ -> { vars = no_vars; parent = Some closure_env; slots; layout = cf.layout } in
  let num_params = Array.length cf.param_slots in
  let num_args = List.length arg_values in
  if fdecl.is_variadic then begin
    (* Variadic function - must have at least as many args as fixed params *)
    if num_args < num_params then
      raise (RuntimeError (Printf.sprintf "Funkcja %s oczekuje co najmniej %s, podano %d"
                            name (Errors.argumentow num_params) num_args));
    let rest = List.filteri (fun i v -> if i < num_params then (slots.(cf.param_slots.(i)) <- v; false) else true)
        arg_values in
    slots.(cf.varargs_slot) <- VArray (Array.of_list rest)
  end else begin
    (* Parametry z wartością domyślną można pominąć (tylko ostatnie) *)
    let required = num_params - List.length fdecl.defaults in
    if num_args < required || num_args > num_params then
      raise (RuntimeError (Printf.sprintf "Funkcja %s oczekuje %s, podano %d" name
                            (if required = num_params then Errors.argumentow num_params
                             else Errors.range_args required num_params) num_args));
    List.iteri (fun i v -> slots.(cf.param_slots.(i)) <- v) arg_values
  end;
  (* Execute function body; po powrocie pozycja wraca do instrukcji wołającej *)
  let caller_loc = !loc_id in
  let caller_stack = !call_stack in
  call_stack := (fdecl.name, !locs.(caller_loc)) :: caller_stack;
  (* brakujące argumenty: wartości domyślne, liczone już w funkcji (widzą wcześniejsze parametry) *)
  if num_args < num_params then
    List.iteri (fun i p ->
      if i >= num_args then slots.(cf.param_slots.(i)) <- (List.assoc p cf.defaults) func_env)
      fdecl.params;
  let result =
    (try
      cf.body func_env;
      VNull (* No explicit return *)
    with
    | ReturnValue v -> v
    (* break/continue nie wyskakują z funkcji do pętli, która ją wywołała *)
    | BreakLoop -> raise (Fatal "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ poza pętlą")
    | ContinueLoop -> raise (Fatal "AKUKARACZA poza pętlą"))
  in
  loc_id := caller_loc;
  call_stack := caller_stack;
  result

(* Wywołanie z gotowymi wartościami argumentów (też z builtinów, np. sortowania) *)
let apply_function name fdecl closure_env arg_values =
  apply_compiled name fdecl (compiled_function fdecl) closure_env arg_values

(* ============ OBIEKTY ============ *)

(* Wartości początkowe pól, skompilowane raz na deklarację (środowisko klasy nie ma slotów) *)
let field_inits : ((string * expr) list * (string * code) list) list Vars.t = Vars.create 16

let compiled_fields name fields =
  memo field_inits name fields (fun () -> List.map (fun (n, e) -> (n, !compile_expr_ref dynamic e)) fields)

let object_env obj parent = { vars = obj; parent = Some parent; slots = [||]; layout = no_layout }

(* Evaluate object creation *)
let eval_new_object env class_name =
  (* Look up class definition *)
  try
    let class_val = get_var env class_name in
    match class_val with
    | VClass (cdecl, class_env) ->
        (* Create new object with fields *)
        let obj = Vars.create 16 in

        (* First, inherit fields and methods from parent class if exists *)
        (match cdecl.parent_class with
         | Some parent_name ->
             (try
               let parent_val = get_var env parent_name in
               match parent_val with
               | VClass (parent_cdecl, parent_env) ->
                   (* Copy parent fields *)
                   List.iter (fun (field_name, init) -> Vars.replace obj field_name (init parent_env))
                     (compiled_fields parent_cdecl.name parent_cdecl.fields);
                   (* Copy parent methods *)
                   List.iter (fun (method_decl : function_decl) ->
                     Vars.replace obj method_decl.name (VFunction (method_decl, object_env obj parent_env))
                   ) parent_cdecl.methods
               | _ -> raise (RuntimeError (Printf.sprintf "Klasa bazowa %s to nie klasa" parent_name))
             with RuntimeError _ ->
               raise (RuntimeError (Printf.sprintf "Nieznana klasa bazowa: %s" parent_name)))
         | None -> ());

        (* Initialize fields from class definition (may override parent fields) *)
        List.iter (fun (field_name, init) -> Vars.replace obj field_name (init class_env))
          (compiled_fields cdecl.name cdecl.fields);

        (* Add methods to object (may override parent methods) *)
        (* Metody współdzielą tablicę pól z obiektem - widzą bieżące wartości pól *)
        List.iter (fun (method_decl : function_decl) ->
          Vars.replace obj method_decl.name (VFunction (method_decl, object_env obj class_env))
        ) cdecl.methods;

        VObject obj
    | _ ->
        raise (RuntimeError (Printf.sprintf "%s to nie klasa" class_name))
  with RuntimeError _ ->
    raise (RuntimeError (Printf.sprintf "Nieznana klasa: %s" class_name))

(* Evaluate struct instantiation *)
let eval_new_struct env struct_name =
  try
    match get_var env struct_name with
    | VStruct (sdecl, struct_env) ->
        let obj = Vars.create 16 in
        List.iter (fun (field_name, init) -> Vars.replace obj field_name (init struct_env))
          (compiled_fields sdecl.name sdecl.fields);
        VObject obj
    | _ ->
        raise (RuntimeError (Printf.sprintf "%s to nie struktura" struct_name))
  with RuntimeError _ ->
    raise (RuntimeError (Printf.sprintf "Nieznana struktura: %s" struct_name))

(* Evaluate new union instantiation *)
let eval_new_union env union_name =
  try
    match get_var env union_name with
    | VUnion (udecl, union_env) ->
        (* In a union, all fields share the same memory, so we initialize with first field only *)
        let obj = Vars.create 16 in
        (match udecl.fields with
         | first :: _ ->
             (match compiled_fields udecl.name [first] with
              | [(field_name, init)] -> Vars.replace obj field_name (init union_env)
              | _ -> ())
         | [] -> ());
        VObject obj
    | _ ->
        raise (RuntimeError (Printf.sprintf "%s to nie unia" union_name))
  with RuntimeError _ ->
    raise (RuntimeError (Printf.sprintf "Nieznana unia: %s" union_name))

(* ============ WYRAŻENIA ============ *)

let rec compile_expr cx : expr -> code = function
  | IntLiteral n -> let v = VInt n in fun _ -> v
  | FloatLiteral f -> let v = VFloat f in fun _ -> v
  | StringLiteral s -> let v = VString s in fun _ -> v
  | BoolLiteral b -> let v = VBool b in fun _ -> v
  | NullLiteral -> fun _ -> VNull
  | Identifier name -> reader cx name
  | BinaryOp (e1, op, e2) ->
      let a = compile_expr cx e1 and b = compile_expr cx e2 in
      fun env -> let v1 = a env in let v2 = b env in eval_arith_op op v1 v2
  | ComparisonOp (e1, op, e2) ->
      let a = compile_expr cx e1 and b = compile_expr cx e2 in
      fun env -> let v1 = a env in let v2 = b env in eval_comparison_op op v1 v2
  | LogicalOp (e1, op, e2) ->
      (* prawa strona tylko wtedy, gdy lewa nie rozstrzyga: fałsz PIWO I TELEWIZOR ... to fałsz,
         prawda ALBO JUTRO U ADWOKATA ... to prawda *)
      let a = compile_expr cx e1 and b = compile_expr cx e2 in
      (match op with
       | And -> fun env -> VBool (to_bool (a env) && to_bool (b env))
       | Or -> fun env -> VBool (to_bool (a env) || to_bool (b env)))
  | BitwiseOp (e1, op, e2) ->
      let a = compile_expr cx e1 and b = compile_expr cx e2 in
      fun env -> let v1 = a env in let v2 = b env in eval_bitwise_op op v1 v2
  | BitwiseNot e ->
      let c = compile_expr cx e in
      fun env -> VInt (lnot (to_int (c env)))
  | LogicalNot e ->
      let c = compile_expr cx e in
      fun env -> VBool (not (to_bool (c env)))
  | ArrayLiteral es ->
      (* Nowa tablica przy każdym obliczeniu - literał w pętli nie jest współdzielony *)
      let cs = List.map (compile_expr cx) es in
      fun env -> VArray (Array.of_list (List.map (fun c -> c env) cs))
  | ToFixed e ->
      (* Convert integer to fixed-point 16.16 format *)
      let c = compile_expr cx e in
      fun env -> (match c env with
        | VFloat f -> VInt (float_to_int "ZAMIEŃ NA FIXED" (f *. 65536.))
        | v -> VInt (to_int v lsl 16))
  | FromFixed e ->
      (* Convert from fixed-point 16.16 format to integer *)
      let c = compile_expr cx e in
      fun env -> VInt (to_int (c env) lsr 16)
  | ArrayAccess (arr_expr, index_expr) ->
      let ca = compile_expr cx arr_expr and ci = compile_expr cx index_expr in
      fun env ->
        (match ca env with
         | VArray arr ->
             (* t[-1] to ostatni element *)
             let n = Array.length arr in
             let index = to_int (ci env) in
             let index = if index < 0 then index + n else index in
             if index < 0 || index >= n then
               raise (RuntimeError "Indeks tablicy poza zakresem")
             else
               arr.(index)
         | VString s ->
             (* tekst[i] - znak na pozycji, ujemna liczy od końca *)
             let chars = Text_utils.utf8_chars s in
             let n = Array.length chars in
             let index = to_int (ci env) in
             let index = if index < 0 then index + n else index in
             if index < 0 || index >= n then raise (RuntimeError "Indeks tekstu poza zakresem")
             else VString chars.(index)
         | VHashMap tbl ->
             (* s["klucz"] - jak WYJMIJ Z SZAFKI: null, gdy klucza nie ma *)
             (match Hashtbl.find_opt tbl (to_string (ci env)) with Some v -> v | None -> VNull)
         | VObject obj ->
             (* Support object field access: obj["field_name"] *)
             let field_name = match ci env with
               | VString s -> s
               | VInt i -> string_of_int i
               | v -> raise (RuntimeError (Printf.sprintf "Nazwa pola obiektu musi być tekstem, a jest: %s" (string_of_value v)))
             in
             (match Vars.find_opt obj field_name with
              | Some v -> v
              | None -> raise (RuntimeError (Printf.sprintf "Obiekt nie ma pola: %s" field_name)))
         | _ -> raise (RuntimeError "To nie jest tablica, szafka, tekst ani obiekt"))
  | FunctionCall (name, args) -> compile_call cx name args
  | NewObject (class_name, args) ->
      (* najpierw argumenty, potem nowy obiekt (pola), na końcu metoda startowa NA DZIEŃ DOBRY *)
      let cargs = List.map (compile_expr cx) args in
      fun env ->
        let values = List.map (fun c -> c env) cargs in
        let obj = eval_new_object env class_name in
        (match obj with
         | VObject fields ->
             (match Vars.find_opt fields Dots.start_method with
              | Some (VFunction (fdecl, closure_env)) ->
                  ignore (apply_function Dots.start_method fdecl closure_env values)
              | _ when values <> [] ->
                  raise (RuntimeError (Printf.sprintf "Klasa %s nie ma metody %s - nie przyjmuje argumentów (podano %d)"
                                         class_name Dots.start_method (List.length values)))
              | _ -> ())
         | _ -> ());
        obj
  | NewStruct struct_name -> fun env -> eval_new_struct env struct_name
  | NewUnion union_name -> fun env -> eval_new_union env union_name
  | Reference (Identifier name) ->
      (* Funkcja - sama funkcja jako wartość; inna wartość - wskaźnik *)
      let r = reader cx name in
      fun env ->
        (match r env with
         | VFunction _ as f -> f
         | v -> VPointer (ref v)
         | exception RuntimeError _ -> raise (RuntimeError (Printf.sprintf "Nieznana zmienna: %s" name)))
  | Reference e ->
      let c = compile_expr cx e in
      fun env -> VPointer (ref (c env))
  | Dereference e ->
      let c = compile_expr cx e in
      fun env -> (match c env with
        | VPointer r -> !r
        | _ -> raise (RuntimeError "CO TAM JEST: to nie jest wskaźnik"))
  | AddressOf var_name ->
      let r = reader cx var_name in
      fun env -> (match r env with
        | v -> VPointer (ref v)
        | exception RuntimeError _ -> raise (RuntimeError (Printf.sprintf "Nieznana zmienna: %s" var_name)))
  | PointerArithmetic (e1, op, e2) ->
      (* Pointer arithmetic - mainly for array/buffer access *)
      let a = compile_expr cx e1 and b = compile_expr cx e2 in
      fun env ->
        let ptr = a env in
        let offset = b env in
        (match ptr, offset with
         | VPointer r, VInt _ -> VPointer r
         | VInt base, VInt n ->
             (match op with
              | Plus -> VInt (base + n)
              | Minus -> VInt (base - n)
              | _ -> raise (RuntimeError "Tego działania nie da się wykonać na wskaźniku"))
         | _ -> raise (RuntimeError "Nieprawidłowe działanie na wskaźniku"))
  | FunctionRef func_name ->
      let r = reader cx func_name in
      fun env ->
        (match r env with
         | VFunction _ as f -> f
         | _ -> raise (RuntimeError (Printf.sprintf "Nieznana funkcja: %s" func_name))
         | exception RuntimeError _ -> raise (RuntimeError (Printf.sprintf "Nieznana funkcja: %s" func_name)))
  | Parenthesized e -> compile_expr cx e
  | Checked (e, t, what) ->
      let c = compile_expr cx e in
      fun env -> check_type (c env) t what
  | Lambda (params, body) as lam ->
      (* Zmienne lokalne (spoza środowiska globalnego) kopiujemy w chwili utworzenia - tak samo
         robi kompilator do C; globalne lambda widzi na żywo. Deklaracja jedna na miejsce w kodzie
         (skompilowane ciało jest pamiętane po niej). *)
      let fdecl = { name = "anonimowa"; params; is_variadic = false; has_return = true; body; defaults = [] } in
      let names = List.map (fun n -> (n, Vars.hash n)) (expr_names lam) in
      fun env ->
        let rec root e = match e.parent with Some p -> root p | None -> e in
        let global = root env in
        let captured = create_env (Some global) in
        Vars.replace captured.vars lambda_marker VNull;
        let rec capture e (n, h) =
          if e != global then
            match local_opt_h e n h with
            | Some v -> Vars.replace_h captured.vars n h v
            | None -> Option.iter (fun p -> capture p (n, h)) e.parent in
        List.iter (capture env) names;
        VFunction (fdecl, captured)

(* Wywołanie: builtin rozpoznany od razu (builtinu nie da się przesłonić), funkcja użytkownika -
   wartość zmiennej o tej nazwie w chwili wywołania *)
and compile_call cx name args : code =
  let cargs = List.map (compile_expr cx) args in
  let nargs = List.length args in
  match Vars.find_opt builtins name with
  | Some (Some n, _) when n <> nargs ->
      fun _ -> raise (RuntimeError (Errors.wrong_arg_count name n nargs))
  | Some (_, impl) -> fun env -> impl env cargs
  | None ->
      let r = reader cx name in
      (* skompilowana funkcja ostatnio wołana stąd - zwykle ciągle ta sama *)
      let last = ref None in
      fun env ->
        let f = try r env with RuntimeError _ ->
          (* nieznana nazwa: podpowiedź z funkcji i zmiennych programu oraz wbudowanych *)
          raise (RuntimeError (Errors.unknown "funkcja" name
            (visible_names env @ Vars.fold (fun n _ acc -> n :: acc) builtins []))) in
        match f with
        | VFunction (fdecl, closure_env) ->
            let cf = match !last with
              | Some (d, cf) when d == fdecl -> cf
              | _ -> let cf = compiled_function fdecl in last := Some (fdecl, cf); cf in
            apply_compiled name fdecl cf closure_env (List.map (fun c -> c env) cargs)
        | _ -> raise (RuntimeError (Printf.sprintf "%s to nie funkcja" name))

(* ============ INSTRUKCJE ============ *)

and compile_block cx stmts : scode =
  match List.map (compile_stmt cx) stmts with
  | [] -> fun _ -> ()
  | [a] -> a
  | [a; b] -> fun env -> a env; b env
  | cs ->
      let cs = Array.of_list cs in
      fun env -> for i = 0 to Array.length cs - 1 do cs.(i) env done

and compile_stmt cx : stmt -> scode = function
  | VarDecl (name, expr) | ConstDecl (name, expr) ->
      let d = definer cx name and c = compile_expr cx expr in
      fun env -> d env (c env)

  | ArrayDecl (name, exprs) ->
      let d = definer cx name and cs = List.map (compile_expr cx) exprs in
      fun env -> d env (VArray (Array.of_list (List.map (fun c -> c env) cs)))

  | Print expr ->
      let c = compile_expr cx expr in
      fun env -> print_endline (string_of_value (c env))

  | PrintInline expr ->
      let c = compile_expr cx expr in
      (* flush: kolejność z komunikatami błędów na stderr jak w skompilowanym C *)
      fun env -> print_string (string_of_value (c env)); flush stdout

  | Read name ->
      let w = writer cx name in
      fun env ->
        (* koniec wejścia - nic (jak w C) *)
        w env (match !read_input () with
          | line -> (match decimal_of_string line with Some n -> VInt n | None -> VString line)
          | exception End_of_file -> VNull)

  | Assign (name, expr) ->
      let w = writer cx name and c = compile_expr cx expr in
      fun env -> w env (c env)

  | ArrayAssign (ArrayAccess (inner_expr, idx_expr), value_expr) ->
      (* Handle nested array assignment like arr[i][j] = value; najpierw wartość *)
      let cv = compile_expr cx value_expr and cc = compile_expr cx inner_expr
      and ci = compile_expr cx idx_expr in
      fun env ->
        let v = cv env in
        let container = cc env in
        let idx = ci env in
        (match container, idx with
         | VArray arr_vals, VInt i ->
             let n = Array.length arr_vals in
             let j = if i < 0 then i + n else i in
             if j < 0 || j >= n then
               raise (RuntimeError (Printf.sprintf "Indeks poza zakresem: %d" i))
             else
               arr_vals.(j) <- v
         | VHashMap tbl, k -> Hashtbl.replace tbl (to_string k) v   (* jak WŁÓŻ DO SZAFKI *)
         | VString _, _ -> raise (RuntimeError "Tekstu nie da się zmienić w miejscu - tekst[i] jest tylko do odczytu")
         | VObject obj, VString s -> Vars.replace obj s v
         | VObject obj, VInt i -> Vars.replace obj (string_of_int i) v
         | _, VInt _ -> raise (RuntimeError "To nie jest tablica, szafka ani obiekt")
         | _, _ -> raise (RuntimeError "Indeks tablicy musi być liczbą całkowitą"))

  | ArrayAssign (_, value_expr) ->
      let cv = compile_expr cx value_expr in
      fun env -> ignore (cv env); raise (RuntimeError "Nieprawidłowe przypisanie do tablicy")

  | If (cond, then_stmts, else_stmts_opt) ->
      let c = compile_expr cx cond and t = compile_block cx then_stmts
      and e = compile_block cx (Option.value else_stmts_opt ~default:[]) in
      fun env -> if to_bool (c env) then t env else e env

  | For (var, from_e, to_e, step_e, body) ->
      (* Granice liczone raz; zakres włącznie; continue też robi krok *)
      let cf = compile_expr cx from_e and ct = compile_expr cx to_e
      and cs = Option.map (compile_expr cx) step_e and b = compile_block cx body
      and r = reader cx var and w = writer cx var in
      fun env ->
        let start = to_int (cf env) in
        let stop = to_int (ct env) in
        let step = match cs with None -> 1 | Some c -> to_int (c env) in
        if step = 0 then raise (RuntimeError "KRĘCI CEMENT BETONIARA: krok nie może być zerem");
        w env (VInt start);
        let in_range () =
          let i = to_int (r env) in
          if step > 0 then i <= stop else i >= stop
        in
        (try
          while in_range () do
            (try b env with ContinueLoop -> ());
            w env (VInt (to_int (r env) + step))
          done
        with BreakLoop -> ())

  | ForEach (var, coll, body) ->
      (* Kolekcja liczona raz, pętla idzie po kopii: tablica - elementy, szafka - klucze
         (posortowane), tekst - znaki *)
      let cc = compile_expr cx coll and b = compile_block cx body and w = writer cx var in
      fun env ->
        let items = match cc env with
          | VArray a -> Array.to_list a
          | VHashMap tbl -> List.map (fun k -> VString k) (Map_utils.szafka_wszystkie_szufladki tbl)
          | VString s -> List.map (fun c -> VString c) (Array.to_list (Text_utils.utf8_chars s))
          | _ -> raise (RuntimeError "KRĘCI CEMENT BETONIARA ... Z: po tym nie da się przejść (tablica, szafka albo tekst)")
        in
        (try
          List.iter (fun v ->
            w env v;
            try b env with ContinueLoop -> ()) items
        with BreakLoop -> ())

  | While (cond, body) ->
      let c = compile_expr cx cond and b = compile_block cx body in
      fun env ->
        let rec loop () =
          if to_bool (c env) then
            match b env with
            | () -> loop ()
            | exception BreakLoop -> ()
            | exception ContinueLoop -> loop ()
        in
        loop ()

  | FunctionCallStmt (name, args) ->
      let call = compile_call cx name args in
      fun env -> ignore (call env)

  | FunctionCallWithAssign (var, func, args) ->
      let call = compile_call cx func args and w = writer cx var in
      fun env -> w env (call env)

  | Return None -> fun _ -> raise (ReturnValue VNull)
  | Return (Some expr) ->
      let c = compile_expr cx expr in
      fun env -> raise (ReturnValue (c env))

  | Try (try_stmts, catch_var, catch_stmts, finally_stmts) ->
      let body_code = compile_block cx try_stmts
      (* catch działa w nowym środowisku (ze zmienną wyjątku) - bez slotów *)
      and catch_code = compile_block dynamic catch_stmts
      and finally_code = compile_block cx finally_stmts in
      fun env ->
        let entry_stack = !call_stack in
        let catch value =
          call_stack := entry_stack;
          let catch_env = create_env (Some env) in
          define_var catch_env catch_var value;
          catch_code catch_env in
        let body () =
          try body_code env with
          | ThrowException value -> catch value
          | RuntimeError msg -> catch (VString msg) in   (* błąd wykonania też - jako tekst komunikatu *)
        if finally_stmts = [] then body ()
        else begin
          match body () with
          | () -> finally_code env
          | exception (Fatal _ as e) -> raise e   (* jak ferdek_fatal w C - bez sprzątania *)
          | exception e ->
              (* sprzątanie, potem to samo dalej (błąd, wyjątek, return, break); pozycja błędu jak
                 przed sprzątaniem, ścieżka wywołań - od poziomu bloku (jak w C) *)
              let loc = !loc_id in
              call_stack := entry_stack;
              finally_code env;
              loc_id := loc;
              raise e
        end

  | Throw expr ->
      let c = compile_expr cx expr in
      fun env -> raise (ThrowException (c env))

  | Located (file, line, s) ->
      let id = register_loc (file, line) and c = compile_stmt cx s in
      fun env ->
        loc_id := id;
        (match !stmt_hook with Some hook -> hook file line env | None -> ());
        c env

  | Break -> fun _ -> raise BreakLoop

  | Continue -> fun _ -> raise ContinueLoop

let () =
  compile_block_ref := compile_block;
  compile_expr_ref := compile_expr

(* Jednorazowe obliczenie (instrukcja programu głównego, debugger): kompilacja po nazwach *)
let eval_expr env e = compile_expr dynamic e env
let eval_stmt env s = compile_stmt dynamic s env
