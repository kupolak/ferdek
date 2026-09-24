(* Zmienna zadeklarowana z typem (CYCU PRZYNIEŚ NO x TO JE LICZBA SYNEK ...) ma go na zawsze:
   każde późniejsze ustawienie - przypisanie, wczytanie, pętla, wynik funkcji - dostaje to samo
   sprawdzenie (Checked). Zasięg jak przy stałych (Consts): lokalna deklaracja w funkcji przesłania
   globalną, w metodzie przypisanie do nie-pola tworzy lokalną. *)

open Ast

(* Zmienne z typem zadeklarowane w bloku (bez lambd); parametry z typem to Assign (p, Checked (p..))
   na początku ciała - wstawione przez parser *)
let rec typed_decls acc = function
  | Located (_, _, s) -> typed_decls acc s
  | VarDecl (n, Checked (_, t, _)) | ConstDecl (n, Checked (_, t, _)) -> (n, t) :: acc
  | Assign (n, Checked (Identifier m, t, what)) when n = m && String.length what > 9 && String.sub what 0 9 = "Parametr " -> (n, t) :: acc
  | If (_, a, b) -> List.fold_left typed_decls acc (a @ Option.value b ~default:[])
  | While (_, b) | For (_, _, _, _, b) | ForEach (_, _, b) -> List.fold_left typed_decls acc b
  | Try (a, _, b, f) -> List.fold_left typed_decls acc (a @ b @ f)
  | _ -> acc

let what n = "Zmienna " ^ n

(* types: nazwa -> typ widoczne w tym bloku *)
let rec rewrite types stmt =
  let ty n = List.assoc_opt n types in
  let check n e = match ty n with
    | Some t -> (match e with Checked (_, t', _) when t' = t -> e | _ -> Checked (e, t, what n))
    | None -> e in
  let after n = match ty n with
    | Some t -> [Assign (n, Checked (Identifier n, t, what n))]
    | None -> [] in
  let bl = List.map (rewrite types) in
  match stmt with
  | Located (f, l, s) -> Located (f, l, rewrite types s)
  | VarDecl (n, e) -> VarDecl (n, check n e)
  | ConstDecl (n, e) -> ConstDecl (n, check n e)
  | Assign (n, e) -> Assign (n, check n e)
  | FunctionCallWithAssign (n, f, args) when ty n <> None -> Assign (n, check n (FunctionCall (f, args)))
  | Read n when ty n <> None -> If (BoolLiteral true, Read n :: after n, None)
  | For (v, a, b, k, body) ->
      For (v, a, b, k, (if ty v = Some TInt then [] else after v) @ bl body)
  | ForEach (v, c, body) -> ForEach (v, c, after v @ bl body)
  | Try (a, v, b, f) -> Try (bl a, v, after v @ bl b, bl f)
  | If (c, a, b) -> If (c, bl a, Option.map bl b)
  | While (c, b) -> While (c, bl b)
  | s -> s

let apply (prog : program) =
  let top = List.concat_map (function Statement s -> [s] | _ -> []) prog.declarations in
  let globals = List.fold_left typed_decls [] top in
  (* Lambdy w wyrażeniach: w ich ciele obowiązują typy z otoczenia (bez przesłoniętych przez parametry
     i deklaracje lambdy) plus jej własne - przypisanie w lambdzie sięga do globalnych jak w funkcji *)
  let rec lambdas types e =
    match e with
    | Lambda (ps, b) ->
        let local = ps @ block_decls b in
        let inner = List.fold_left typed_decls [] b
                    @ List.filter (fun (n, _) -> not (List.mem n local)) types in
        Lambda (ps, List.map (fun s -> map_stmt_exprs (lambdas inner) (rewrite inner s)) b)
    | e -> map_subexprs (lambdas types) e in
  let rewrite types s = map_stmt_exprs (lambdas types) (rewrite types s) in
  let body ~params ~members stmts =
    let own = List.fold_left typed_decls [] stmts in
    let local = params @ block_decls stmts in
    (* w metodzie przypisanie do nie-pola tworzy lokalną - globalne typy tam nie sięgają *)
    let visible = if members <> [] then [] else List.filter (fun (n, _) -> not (List.mem n local)) globals in
    List.map (rewrite (own @ visible)) stmts in
  let fn ?(members = []) (f : function_decl) =
    { f with body = body ~params:(f.params @ (if f.is_variadic then ["varargs"] else [])) ~members f.body } in
  { declarations = List.map (function
      | Statement s -> Statement (rewrite globals s)
      | FunctionDecl f -> FunctionDecl (fn f)
      | ClassDecl c ->
          let members = List.map fst c.fields @ List.map (fun (m : function_decl) -> m.name) c.methods in
          ClassDecl { c with methods = List.map (fn ~members) c.methods }
      | d -> d) prog.declarations }
