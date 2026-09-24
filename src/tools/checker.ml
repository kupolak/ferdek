(* ferdek --check: szuka błędów przed uruchomieniem programu.
   Nieznane zmienne i funkcje oraz zła liczba argumentów - z plikiem i linią.
   Celowo pobłażliwy: zmienne programu głównego są widoczne wszędzie (jak w interpreterze,
   gdzie funkcja widzi globalne istniejące w chwili wywołania). *)

open Ast

type scope = {
  vars: (string, unit) Hashtbl.t;
  funcs: (string, function_decl) Hashtbl.t;     (* funkcje użytkownika *)
  types: (string, unit) Hashtbl.t;              (* klasy, struktury, unie, enumy *)
}

let check ?(load_module = fun _ -> None) (prog : program) : string list =
  let builtin_arity = Hashtbl.create 128 in
  List.iter (fun (n, a) -> Hashtbl.replace builtin_arity n a) (Interpreter.builtin_arities ());
  let issues = ref [] in
  let loc = ref ("", 0) in
  let report msg =
    let file, line = !loc in
    let where = if line = 0 then "" else if file = "" then Printf.sprintf "linia %d: " line
      else Printf.sprintf "%s, linia %d: " file line in
    issues := (where ^ msg) :: !issues
  in
  let decls =
    try Compiler.expand_imports load_module prog.declarations
    with Compiler.Compile_error msg -> report msg; prog.declarations
  in
  let add tbl names = List.iter (fun n -> Hashtbl.replace tbl n ()) names in
  let names_of stmts = let d, a = targets_block ([], []) stmts in d @ a in
  let global = { vars = Hashtbl.create 64; funcs = Hashtbl.create 16; types = Hashtbl.create 16 } in
  let classes = Hashtbl.create 8 in
  List.iter (function
    | Statement s -> add global.vars (names_of [s])
    | FunctionDecl f -> Hashtbl.replace global.funcs f.name f
    | EnumDecl e -> add global.types [e.name]; add global.vars (List.map fst e.values)
    | ClassDecl c -> add global.types [c.name]; Hashtbl.replace classes c.name c
    | StructDecl s -> add global.types [s.name]
    | UnionDecl u -> add global.types [u.name]
    | Import _ | ImportAs _ -> ()) decls;

  let with_locals names =
    let vars = Hashtbl.copy global.vars in
    add vars names;
    { global with vars }
  in
  let is_var sc n = Hashtbl.mem sc.vars n in

  let check_arity name expected given =
    match expected with
    | Some n when n <> given ->
        report (Printf.sprintf "%s oczekuje %s, podano %d" name (Errors.argumentow n) given)
    | _ -> ()
  in
  let names sc = Hashtbl.fold (fun n _ acc -> n :: acc) sc.vars (Hashtbl.fold (fun n _ acc -> n :: acc) sc.funcs []) in
  let builtin_names = Hashtbl.fold (fun n _ acc -> n :: acc) builtin_arity [] in
  let rec expr sc = function
    | Identifier n ->
        if not (is_var sc n || Hashtbl.mem sc.funcs n || Hashtbl.mem sc.types n) then
          report (Errors.unknown "zmienna" n (names sc))
    | FunctionCall (name, args) ->
        List.iter (expr sc) args;
        let given = List.length args in
        (match Hashtbl.find_opt builtin_arity name, Hashtbl.find_opt sc.funcs name with
         | Some arity, _ -> check_arity name arity given
         | None, _ when is_var sc name -> ()   (* funkcja trzymana w zmiennej *)
         | None, Some f ->
             let n = List.length f.params in
             if f.is_variadic then
               (if given < n then
                  report (Printf.sprintf "%s oczekuje co najmniej %s, podano %d" name (Errors.argumentow n) given))
             else if f.defaults <> [] then begin
               let lo = n - List.length f.defaults in
               if given < lo || given > n then
                 report (Printf.sprintf "%s oczekuje %s, podano %d" name (Errors.range_args lo n) given)
             end else check_arity name (Some n) given
         | None, None -> report (Errors.unknown "funkcja" name (names sc @ builtin_names)))
    | NewObject (c, args) ->
        List.iter (expr sc) args;
        if not (Hashtbl.mem sc.types c) then report ("Nieznana klasa: " ^ c)
    | NewStruct t | NewUnion t ->
        if not (Hashtbl.mem sc.types t) then report ("Nieznany typ: " ^ t)
    | AddressOf n -> expr sc (Identifier n)
    | FunctionRef n ->
        if not (Hashtbl.mem sc.funcs n || is_var sc n) then report ("Nieznana funkcja: " ^ n)
    | BinaryOp (a, _, b) | ComparisonOp (a, _, b) | LogicalOp (a, _, b) | BitwiseOp (a, _, b)
    | ArrayAccess (a, b) | PointerArithmetic (a, _, b) -> expr sc a; expr sc b
    | BitwiseNot e | LogicalNot e | ToFixed e | FromFixed e | Reference e | Dereference e
    | Parenthesized e -> expr sc e
    | Checked (e, t, what) ->
        expr sc e;
        let known = match e with
          | IntLiteral _ -> Some TInt | FloatLiteral _ -> Some TFloat | StringLiteral _ -> Some TString
          | BoolLiteral _ -> Some TBool | ArrayLiteral _ -> Some TArray | Lambda _ -> Some TFunction
          | _ -> None in
        (match known with
         | Some k when k <> t ->
             let noun = function
               | TInt -> "liczbę całkowitą" | TFloat -> "liczbę z przecinkiem" | TString -> "tekst"
               | TBool -> "prawdę/fałsz" | TArray -> "tablicę" | TMap -> "szafkę" | TFunction -> "funkcję" in
             report (Printf.sprintf "%s: %s, a dostaje %s" what (string_of_typ t) (noun k))
         | _ -> ())
    | ArrayLiteral es -> List.iter (expr sc) es
    | Lambda (ps, body) ->
        let vars = Hashtbl.copy sc.vars in
        add vars (ps @ names_of body);
        block { sc with vars } body
    | IntLiteral _ | FloatLiteral _ | StringLiteral _ | BoolLiteral _ | NullLiteral -> ()
  and stmt sc = function
    | Located (file, line, s) -> loc := (file, line); stmt sc s
    | VarDecl (_, e) | ConstDecl (_, e) | Assign (_, e) | Print e | PrintInline e | Throw e -> expr sc e
    | ArrayDecl (_, es) -> List.iter (expr sc) es
    | ArrayAssign (a, v) -> expr sc a; expr sc v
    | If (c, a, b) -> expr sc c; block sc a; Option.iter (block sc) b
    | While (c, b) -> expr sc c; block sc b
    | ForEach (_, c, b) -> expr sc c; block sc b
    | For (_, a, b, k, body) -> expr sc a; expr sc b; Option.iter (expr sc) k; block sc body
    | FunctionCallStmt (n, args) | FunctionCallWithAssign (_, n, args) -> expr sc (FunctionCall (n, args))
    | Return e -> Option.iter (expr sc) e
    | Try (a, _, b, f) -> block sc a; block sc b; block sc f
    | Read _ | Break | Continue -> ()
  and block sc stmts = List.iter (stmt sc) stmts in

  let check_function extra (f : function_decl) =
    let sc = with_locals (extra @ f.params @ (if f.is_variadic then ["varargs"] else []) @ names_of f.body) in
    List.iter (fun (_, d) -> expr sc d) f.defaults;
    block sc f.body
  in
  (* Metoda widzi pola i metody swojej klasy oraz przodków *)
  let rec class_members (c : class_decl) =
    let own = List.map fst c.fields @ List.map (fun (m : function_decl) -> m.name) c.methods in
    match c.parent_class with
    | Some p when Hashtbl.mem classes p -> own @ class_members (Hashtbl.find classes p)
    | Some p -> report ("Nieznana klasa bazowa: " ^ p); own
    | None -> own
  in
  List.iter (fun d ->
    (match d with Statement _ -> () | _ -> loc := ("", 0));
    match d with
    | Statement s -> stmt global s
    | FunctionDecl f -> check_function [] f
    | ClassDecl c ->
        List.iter (fun (_, e) -> expr global e) c.fields;
        List.iter (check_function (class_members c)) c.methods
    | StructDecl { fields; _ } | UnionDecl { fields; _ } -> List.iter (fun (_, e) -> expr global e) fields
    | EnumDecl _ | Import _ | ImportAs _ -> ()) decls;
  List.rev !issues
