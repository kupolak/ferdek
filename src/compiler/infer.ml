(* Analiza liczb w kompilatorze: które zmienne, parametry i wyniki mogą być w C zwykłym
   long long / double zamiast FerdekValue *)

open Ast

(* Zmienne, które zawsze trzymają liczbę całkowitą, są w C zwykłym long long, a działania na nich
   zwykłymi działaniami C (bez op_add i sprawdzania typów). Funkcja wywoływana tylko wprost (nigdy
   jako wartość) dostaje parametry i wynik long long, gdy wszystkie wywołania podają liczby, a każda
   ścieżka zwraca liczbę. Reszta zostaje FerdekValue - wynik jest ten sam, tylko szybciej. *)

type tenv = { ivar : string -> bool; fvar : string -> bool; ifun : string -> (bool list * bool) option }

(* Wbudowane, które zawsze dają liczbę całkowitą / z przecinkiem (albo kończą się błędem).
   Wbudowana ma pierwszeństwo przed funkcją użytkownika - nazwy nie da się przesłonić. *)
let int_builtins = ["ILE NA WERSALCE"; "ILE MIEJSCA NA KANAPIE"; "ZRÓB DŁUGI"; "ILE W SZAFCE";
                    "PODŁOGA ZE SKRZYNKI"; "SUFIT ZE SKRZYNKI"]
let float_builtins = ["SINUS ZE SKRZYNKI"; "COSINUS ZE SKRZYNKI"; "PIERWIASTEK ZE SKRZYNKI"; "TANGENS ZE SKRZYNKI";
                      "LOGARYTM ZE SKRZYNKI"]

type num = Int | Float | Other

(* Typ liczbowy wyrażenia: działanie na liczbie całkowitej i z przecinkiem daje liczbę z przecinkiem *)
let rec num_type env = function
  | IntLiteral _ | BitwiseOp _ | BitwiseNot _ -> Int   (* bitowe zawsze dają make_int(to_int ...) *)
  | FloatLiteral _ -> Float
  | Identifier n -> if env.ivar n then Int else if env.fvar n then Float else Other
  | Parenthesized e -> num_type env e
  (* sprawdzony typ: w działającym programie jest dokładnie taki - kompilator może na tym polegać *)
  | Checked (_, TInt, _) -> Int
  | Checked (_, TFloat, _) -> Float
  | BinaryOp (a, _, b) ->
      (match num_type env a, num_type env b with
       | Int, Int -> Int
       | (Int | Float), (Int | Float) -> Float
       | _ -> Other)
  | FunctionCall (f, _) when List.mem f int_builtins -> Int
  | FunctionCall (f, _) when List.mem f float_builtins -> Float
  | FunctionCall (f, _) -> (match env.ifun f with Some (_, true) -> Int | _ -> Other)
  | _ -> Other

let is_int env e = num_type env e = Int
let is_float env e = num_type env e = Float

let rec all_exprs e = e :: List.concat_map all_exprs (subexprs e)

let block_exprs stmts = List.concat_map all_exprs (List.concat_map stmt_exprs stmts)

(* Lambdy (parametry, ciało) z wyrażeń, także zagnieżdżone *)
let rec lambdas_of es =
  List.concat_map (function
    | Lambda (ps, b) -> (ps, b) :: lambdas_of (block_exprs b)
    | _ -> []) (List.concat_map all_exprs es)

(* Przypisania w bloku (bez lambd): nazwa i wyrażenie; None - coś, co nie musi być liczbą *)
let rec assigns acc = function
  | VarDecl (n, e) | ConstDecl (n, e) | Assign (n, e) -> (n, Some e) :: acc
  | FunctionCallWithAssign (n, f, args) -> (n, Some (FunctionCall (f, args))) :: acc
  | For (v, _, _, _, b) -> List.fold_left assigns ((v, Some (IntLiteral 0)) :: acc) b
  | Read n | ArrayDecl (n, _) -> (n, None) :: acc
  | ForEach (v, _, b) -> List.fold_left assigns ((v, None) :: acc) b
  | Try (a, v, b, f) -> List.fold_left assigns ((v, None) :: acc) (a @ b @ f)
  | If (_, a, b) -> List.fold_left assigns acc (a @ Option.value b ~default:[])
  | While (_, b) -> List.fold_left assigns acc b
  | Located (_, _, s) -> assigns acc s
  | _ -> acc

(* Każda ścieżka kończy się I JA INFORMUJĘ ŻE WYCHODZĘ z wartością (albo rzuceniem wyjątku) *)
let rec returns_value stmts = match List.rev stmts with
  | s :: _ -> ends_with_return s
  | [] -> false
and ends_with_return = function
  | Return (Some _) | Throw _ -> true
  | Located (_, _, s) -> ends_with_return s
  | If (_, a, Some b) -> returns_value a && returns_value b
  | _ -> false

let rec returns_in stmts = List.concat_map (function
  | Return e -> [e]
  | If (_, a, b) -> returns_in (a @ Option.value b ~default:[])
  | While (_, b) | For (_, _, _, _, b) | ForEach (_, _, b) -> returns_in b
  | Try (a, _, b, f) -> returns_in (a @ b @ f)
  | Located (_, _, s) -> returns_in [s]
  | _ -> []) stmts

let all_params (f : function_decl) = f.params @ (if f.is_variadic then ["varargs"] else [])

(* Zmienne funkcji tak jak w compile_body: parametry, zadeklarowane i przypisane nie-globalne *)
let function_scope globals (f : function_decl) =
  let decl, assigned = targets_block ([], []) f.body in
  let loops = loop_vars f.body in
  all_params f @ decl @ List.filter (fun n -> List.mem n loops || not (Hashtbl.mem globals n)) assigned

(* Punkt stały po całym programie: zaczynamy od "wszystko jest liczbą" i odrzucamy, co się nie zgadza.
   Wejście: globals, classes, records, is_builtin; wynik trafia do sigs, int_* i float_* *)
let infer_ints ~globals ~classes ~records ~is_builtin ~sigs ~int_globals ~int_locals ~float_globals ~float_locals decls =
  let funcs = List.filter_map (function FunctionDecl f -> Some f | _ -> None) decls in
  let top = List.filter_map (function Statement s -> Some s | _ -> None) decls in
  let classes = Hashtbl.fold (fun _ c acc -> c :: acc) classes [] in
  let methods = List.concat_map (fun (c : class_decl) -> c.methods) classes in
  let field_exprs = List.concat_map (fun (c : class_decl) -> List.map snd c.fields) classes
                    @ Hashtbl.fold (fun _ fs acc -> List.map snd fs @ acc) records [] in
  let bodies = top :: List.map (fun (f : function_decl) -> f.body) (funcs @ methods) in
  let lambdas = lambdas_of (List.concat_map block_exprs bodies @ field_exprs) in
  let everywhere = List.concat_map block_exprs (bodies @ List.map snd lambdas)
                   @ List.concat_map all_exprs field_exprs in
  (* Funkcję wolno wyspecjalizować, gdy nikt jej nie używa jako wartości i nic jej nie przesłania *)
  let shadow = Hashtbl.copy globals in
  let add n = Hashtbl.replace shadow n () in
  List.iter (fun (f : function_decl) -> List.iter add (all_params f)) (funcs @ methods);
  List.iter (fun (ps, _) -> List.iter add ps) lambdas;
  List.iter (fun b -> let d, a = targets_block ([], []) b in List.iter add (d @ a)) (bodies @ List.map snd lambdas);
  List.iter (fun (c : class_decl) ->
    List.iter (fun (n, _) -> add n) c.fields;
    List.iter (fun (m : function_decl) -> add m.name) c.methods) classes;
  let as_value = Hashtbl.create 16 in
  List.iter (function
    | Identifier n | FunctionRef n | AddressOf n -> Hashtbl.replace as_value n ()
    | _ -> ()) everywhere;
  let eligible (f : function_decl) =
    not f.is_variadic && f.defaults = [] && not (is_builtin f.name)
    && not (Hashtbl.mem as_value f.name) && not (Hashtbl.mem shadow f.name) in
  (* Stan: kandydaci na long long *)
  let g = Hashtbl.copy globals in
  (* Lambda może przypisać do globalnej - takiej nie ruszamy *)
  List.iter (fun (_, b) -> let d, a = targets_block ([], []) b in List.iter (Hashtbl.remove g) (d @ a)) lambdas;
  let locals = Hashtbl.create 16 and params = Hashtbl.create 16 and rets = Hashtbl.create 16 in
  List.iter (fun (f : function_decl) ->
    Hashtbl.replace locals f.name
      (ref (List.filter (fun n -> not (List.mem n (all_params f))) (function_scope globals f)));
    if eligible f then begin
      Hashtbl.replace params f.name (Array.make (List.length f.params) true);
      Hashtbl.replace rets f.name (ref (returns_value f.body))
    end) funcs;
  let ifun n = match Hashtbl.find_opt params n with
    | Some ps -> Some (Array.to_list ps, !(Hashtbl.find rets n))
    | None -> None in
  let no_f = fun _ -> false in
  let env_main = { ivar = Hashtbl.mem g; fvar = no_f; ifun } in
  let env_other = { ivar = (fun _ -> false); fvar = no_f; ifun } in   (* metody, lambdy, pola: ostrożnie *)
  let env_f (f : function_decl) =
    let sc = function_scope globals f and li = Hashtbl.find locals f.name in
    let ps = Hashtbl.find_opt params f.name in
    { ifun; fvar = no_f; ivar = fun n ->
        if List.mem n sc then
          List.mem n !li
          || (match ps with
              | Some ps -> List.exists Fun.id (List.mapi (fun i p -> p = n && ps.(i)) f.params)
              | None -> false)
        else Hashtbl.mem g n } in
  let changed = ref true in
  let ok env = function Some e -> is_int env e | None -> false in
  while !changed do
    changed := false;
    let drop_g n = if Hashtbl.mem g n then (Hashtbl.remove g n; changed := true) in
    List.iter (fun (n, rhs) -> if not (ok env_main rhs) then drop_g n) (List.fold_left assigns [] top);
    List.iter (fun (f : function_decl) ->
      let env = env_f f and sc = function_scope globals f and li = Hashtbl.find locals f.name in
      List.iter (fun (n, rhs) ->
        if not (ok env rhs) then begin
          if not (List.mem n sc) then drop_g n
          else if List.mem n !li then (li := List.filter (( <> ) n) !li; changed := true)
          else match Hashtbl.find_opt params f.name with
            | Some ps -> List.iteri (fun i p -> if p = n && ps.(i) then (ps.(i) <- false; changed := true)) f.params
            | None -> ()
        end) (List.fold_left assigns [] f.body);
      match Hashtbl.find_opt rets f.name with
      | Some r when !r && List.exists (fun e -> not (ok env e)) (returns_in f.body) -> r := false; changed := true
      | _ -> ()) funcs;
    (* Wywołania: parametr zostaje liczbą, gdy każde wywołanie podaje w tym miejscu liczbę *)
    let calls env es = List.iter (function
      | FunctionCall (n, args) ->
          (match Hashtbl.find_opt params n with
           | Some ps ->
               let given = Array.of_list args in
               Array.iteri (fun i p ->
                 if p && (Array.length given <> Array.length ps || not (is_int env given.(i))) then
                   (ps.(i) <- false; changed := true)) ps
           | None -> ())
      | _ -> ()) es in
    calls env_main (block_exprs top);
    List.iter (fun (f : function_decl) -> calls (env_f f) (block_exprs f.body)) funcs;
    List.iter (fun (m : function_decl) -> calls env_other (block_exprs m.body)) methods;
    List.iter (fun (_, b) -> calls env_other (block_exprs b)) lambdas;
    calls env_other (List.concat_map all_exprs field_exprs)
  done;
  Hashtbl.iter (fun n () -> Hashtbl.replace int_globals n ()) g;
  (* Liczby z przecinkiem - druga runda, gdy liczby całkowite są już ustalone. Tylko zmienne
     (globalne i lokalne funkcji), bez parametrów i wyników. *)
  let fg = Hashtbl.copy globals in
  Hashtbl.iter (fun n () -> Hashtbl.remove fg n) g;
  List.iter (fun (_, b) -> let d, a = targets_block ([], []) b in List.iter (Hashtbl.remove fg) (d @ a)) lambdas;
  let flocals = Hashtbl.create 16 in
  List.iter (fun (f : function_decl) ->
    let ints = !(Hashtbl.find locals f.name) in
    Hashtbl.replace flocals f.name
      (ref (List.filter (fun n -> not (List.mem n (all_params f)) && not (List.mem n ints)) (function_scope globals f)))) funcs;
  let fenv_main = { env_main with fvar = Hashtbl.mem fg } in
  let fenv_f (f : function_decl) =
    let e = env_f f and sc = function_scope globals f and fl = Hashtbl.find flocals f.name in
    { e with fvar = fun n -> if List.mem n sc then List.mem n !fl else Hashtbl.mem fg n } in
  let changed = ref true in
  let fok env = function Some e -> is_float env e | None -> false in
  while !changed do
    changed := false;
    let drop n = if Hashtbl.mem fg n then (Hashtbl.remove fg n; changed := true) in
    List.iter (fun (n, rhs) -> if not (fok fenv_main rhs) then drop n) (List.fold_left assigns [] top);
    List.iter (fun (f : function_decl) ->
      let env = fenv_f f and sc = function_scope globals f and fl = Hashtbl.find flocals f.name in
      List.iter (fun (n, rhs) ->
        if not (fok env rhs) then begin
          if not (List.mem n sc) then drop n
          else if List.mem n !fl then (fl := List.filter (( <> ) n) !fl; changed := true)
        end) (List.fold_left assigns [] f.body)) funcs
  done;
  Hashtbl.iter (fun n () -> Hashtbl.replace float_globals n ()) fg;
  List.iter (fun (f : function_decl) -> Hashtbl.replace float_locals f.name !(Hashtbl.find flocals f.name)) funcs;
  List.iter (fun (f : function_decl) ->
    let ps = match Hashtbl.find_opt params f.name with
      | Some ps -> List.filteri (fun i _ -> ps.(i)) f.params | None -> [] in
    Hashtbl.replace int_locals f.name (!(Hashtbl.find locals f.name) @ ps);
    match ifun f.name with
    | Some (ps, r) when r || List.exists Fun.id ps -> Hashtbl.replace sigs f.name (ps, r)
    | _ -> ()) funcs

