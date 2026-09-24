(* O KOGO MOJE PIĘKNE OCZY WIDZĄ moduł JAKO m: nazwy globalne modułu dostają przedrostek "m.".
   Przemianowanie na AST, zanim moduł trafi do interpretera albo kompilatora - oba dostają to samo.
   Nazwy lokalne (parametry, zmienne funkcji, pola i metody w metodach, lambdy) zostają. *)

open Ast

(* Nazwy, które moduł tworzy na górnym poziomie *)
let module_globals decls =
  List.concat_map (function
    | Statement s -> let d, a = targets_stmt ([], []) s in d @ a
    | FunctionDecl f -> [f.name]
    | ClassDecl c -> [c.name]
    | StructDecl s -> [s.name]
    | UnionDecl u -> [u.name]
    | EnumDecl e -> e.name :: List.map fst e.values
    | Import _ | ImportAs _ -> []) decls

let qualify alias (prog : program) =
  let decls = prog.declarations in
  let globals = Hashtbl.create 32 in
  List.iter (fun n -> Hashtbl.replace globals n ()) (module_globals decls);
  let q n = if Hashtbl.mem globals n then alias ^ "." ^ n else n in
  (* sh = nazwy lokalne, które przesłaniają globalne *)
  let rec e sh x =
    let r n = if List.mem n sh then n else q n in
    let e = e sh in
    match x with
    | Identifier n -> Identifier (r n)
    | FunctionRef n -> FunctionRef (r n)
    | AddressOf n -> AddressOf (r n)
    | FunctionCall (n, args) -> FunctionCall (r n, List.map e args)
    | NewObject (c, args) -> NewObject (q c, List.map e args)
    | NewStruct c -> NewStruct (q c)
    | NewUnion c -> NewUnion (q c)
    | ArrayLiteral es -> ArrayLiteral (List.map e es)
    | BinaryOp (a, o, b) -> BinaryOp (e a, o, e b)
    | ComparisonOp (a, o, b) -> ComparisonOp (e a, o, e b)
    | LogicalOp (a, o, b) -> LogicalOp (e a, o, e b)
    | BitwiseOp (a, o, b) -> BitwiseOp (e a, o, e b)
    | ArrayAccess (a, b) -> ArrayAccess (e a, e b)
    | PointerArithmetic (a, o, b) -> PointerArithmetic (e a, o, e b)
    | BitwiseNot a -> BitwiseNot (e a)
    | LogicalNot a -> LogicalNot (e a)
    | ToFixed a -> ToFixed (e a)
    | FromFixed a -> FromFixed (e a)
    | Reference a -> Reference (e a)
    | Dereference a -> Dereference (e a)
    | Parenthesized a -> Parenthesized (e a)
    | Lambda (ps, body) -> let sh = ps @ block_decls body @ sh in Lambda (ps, List.map (s sh) body)
    | IntLiteral _ | FloatLiteral _ | StringLiteral _ | BoolLiteral _ | NullLiteral -> x
  and s sh x =
    let r n = if List.mem n sh then n else q n in
    let e = e sh and bl = List.map (s sh) in
    match x with
    | VarDecl (n, v) -> VarDecl (r n, e v)
    | ConstDecl (n, v) -> ConstDecl (r n, e v)
    | ArrayDecl (n, es) -> ArrayDecl (r n, List.map e es)
    | Print v -> Print (e v)
    | PrintInline v -> PrintInline (e v)
    | Throw v -> Throw (e v)
    | Read n -> Read (r n)
    | Assign (n, v) -> Assign (r n, e v)
    | ArrayAssign (a, v) -> ArrayAssign (e a, e v)
    | If (c, a, b) -> If (e c, bl a, Option.map bl b)
    | While (c, b) -> While (e c, bl b)
    | For (v, a, b, k, body) -> For (r v, e a, e b, Option.map e k, bl body)
    | ForEach (v, c, b) -> ForEach (r v, e c, bl b)
    | FunctionCallStmt (n, args) -> FunctionCallStmt (r n, List.map e args)
    | FunctionCallWithAssign (v, n, args) -> FunctionCallWithAssign (r v, r n, List.map e args)
    | Return v -> Return (Option.map e v)
    | Try (a, v, b) -> Try (bl a, r v, bl b)
    | Located (f, l, st) -> Located (f, l, s sh st)
    | Break | Continue -> x
  in
  let params (f : function_decl) = f.params @ (if f.is_variadic then ["varargs"] else []) in
  let func extra (f : function_decl) =
    let sh = extra @ params f @ block_decls f.body in
    { f with body = List.map (s sh) f.body; defaults = List.map (fun (p, d) -> (p, e sh d)) f.defaults } in
  let class_members (c : class_decl) =
    let own (c : class_decl) = List.map fst c.fields @ List.map (fun (m : function_decl) -> m.name) c.methods in
    own c @ List.concat_map (function
      | ClassDecl p when Some p.name = c.parent_class -> own p
      | _ -> []) decls in
  let decls = List.map (function
    | Statement st -> Statement (s [] st)
    | FunctionDecl f -> FunctionDecl { (func [] f) with name = q f.name }
    | ClassDecl c ->
        (* Metoda: przypisanie do czegoś, co nie jest polem, tworzy lokalną - nie rusza globalnych.
           ponytail: odczyt takiej nazwy przed przypisaniem i tak widzi globalną - rzadkie *)
        let method_ (m : function_decl) =
          let d, a = targets_block ([], []) m.body in
          { (func (class_members c @ d @ a) m) with name = m.name } in
        ClassDecl { name = q c.name; parent_class = Option.map q c.parent_class;
                           fields = List.map (fun (n, v) -> (n, e [] v)) c.fields;
                           methods = List.map method_ c.methods }
    | StructDecl r -> StructDecl { name = q r.name; fields = List.map (fun (n, v) -> (n, e [] v)) r.fields }
    | UnionDecl u -> UnionDecl { name = q u.name; fields = List.map (fun (n, v) -> (n, e [] v)) u.fields }
    | EnumDecl en -> EnumDecl { name = q en.name; values = List.map (fun (n, v) -> (q n, v)) en.values }
    | (Import _ | ImportAs _) as d -> d) decls in
  { declarations = decls }
