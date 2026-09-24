(* TO JE NA AMEN: stałej nie wolno zmienić. Sprawdzamy przed uruchomieniem (oba tryby, --check,
   edytor): przypisanie, wczytanie, pętla, ponowna deklaracja. Lokalna deklaracja w funkcji
   przesłania stałą globalną; zawartość tablicy w stałej wolno zmieniać - stałe jest przypisanie. *)

open Ast

(* Instrukcje, które ustawiają nazwę (poza zagnieżdżonymi lambdami), z numerem linii *)
let rec setters line acc = function
  | Located (_, l, s) -> setters l acc s
  | VarDecl (n, _) | ArrayDecl (n, _) | Assign (n, _) | Read n | FunctionCallWithAssign (n, _, _) -> (n, line, false) :: acc
  | ConstDecl (n, _) -> (n, line, true) :: acc
  | For (v, _, _, _, b) | ForEach (v, _, b) -> List.fold_left (setters line) ((v, line, false) :: acc) b
  | Try (a, v, b) -> List.fold_left (setters line) ((v, line, false) :: acc) (a @ b)
  | If (_, a, b) -> List.fold_left (setters line) acc (a @ Option.value b ~default:[])
  | While (_, b) -> List.fold_left (setters line) acc b
  | _ -> acc

let message name = Printf.sprintf "Stała '%s' to TO JE NA AMEN - nie wolno jej zmieniać" name

(* errors: (linia, kolumna, komunikat) *)
let check (prog : program) =
  let errors = ref [] in
  let report line name = errors := (line, 1, message name) :: !errors in
  let top = List.concat_map (function Statement s -> [s] | _ -> []) prog.declarations in
  let top_setters = List.rev (List.fold_left (setters 0) [] top) in
  let globals = List.filter_map (fun (n, _, c) -> if c then Some n else None) top_setters in
  (* stała: pierwsze ustawienie to jej deklaracja; każde kolejne to błąd *)
  let check_block ~locals ~own_consts sets =
    let seen = Hashtbl.create 8 in
    List.iter (fun (n, line, is_const) ->
      if List.mem n own_consts then begin
        if Hashtbl.mem seen n || not is_const then report line n;
        Hashtbl.replace seen n ()
      end else if List.mem n globals && not (List.mem n locals) then report line n) sets in
  check_block ~locals:[] ~own_consts:globals top_setters;
  (* ciała: funkcje, lambdy (przypisanie sięga do globalnych jak w funkcji), metody (nie sięga) *)
  let body ~params ~members stmts =
    let sets = List.rev (List.fold_left (setters 0) [] stmts) in
    let own_consts = List.filter_map (fun (n, _, c) -> if c then Some n else None) sets in
    let declared = params @ block_decls stmts in
    (* w metodzie przypisanie do czegoś, co nie jest polem, tworzy lokalną *)
    let locals = if members = [] then declared else declared @ List.map (fun (n, _, _) -> n) sets in
    check_block ~locals ~own_consts sets in
  let rec lambdas_in_expr e acc = match e with
    | Lambda (ps, b) -> List.fold_left lambdas_in_stmt ((ps, b) :: acc) b
    | _ -> List.fold_left (fun acc x -> lambdas_in_expr x acc) acc (Compiler.subexprs e)
  and lambdas_in_stmt acc s = List.fold_left (fun acc e -> lambdas_in_expr e acc) acc (Compiler.stmt_exprs s) in
  let lambdas stmts = List.fold_left lambdas_in_stmt [] stmts in
  let fn ?(members = []) (f : function_decl) =
    body ~params:(f.params @ (if f.is_variadic then ["varargs"] else [])) ~members f.body;
    List.iter (fun (ps, b) -> body ~params:ps ~members:[] b) (lambdas f.body) in
  List.iter (fun (ps, b) -> body ~params:ps ~members:[] b) (lambdas top);
  List.iter (function
    | FunctionDecl f -> fn f
    | ClassDecl c -> List.iter (fn ~members:(List.map fst c.fields @ List.map (fun (m : function_decl) -> m.name) c.methods)) c.methods
    | _ -> ()) prog.declarations;
  List.rev !errors
