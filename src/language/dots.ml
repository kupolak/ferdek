(* Kropka po zmiennej: kot.wiek to pole obiektu (albo klucz szafki), kot.miaucz(2) to metoda.
   Lekser oddaje "kot.wiek" jako jedną nazwę; tu, zaraz po parsowaniu, zamieniamy ją na kot["wiek"],
   a wywołanie na .wywołaj("kot.miaucz", kot["miaucz"], argumenty) - interpreter, kompilator
   i --check dostają zwykłe drzewo, bez osobnej obsługi.
   Nazwy z modułu zaimportowanego JAKO m (m.dodaj, m.PI) zostają - to nazwy globalne. *)

open Ast

(* Wbudowana funkcja "wywołaj wartość"; nazwy z kropką na początku nie da się wpisać w programie *)
let call = ".wywołaj"

(* Metoda startowa klasy: DZIAD ZDZIADZIAŁY JEDEN Kot("Mruczek") woła ją z argumentami na nowym
   obiekcie. Lekser oddaje te trzy słowa jako jedną nazwę. *)
let start_method = "NA DZIEŃ DOBRY"

(* Aliasy modułów widziane dotąd w tym procesie - dla REPL-a i debuggera, gdzie import jest
   w innym kawałku tekstu niż użycie *)
let seen : (string, unit) Hashtbl.t = Hashtbl.create 8

(* "a.b.c" -> a["b"]["c"]; None dla zwykłej nazwy i dla nazwy z modułu (m.dodaj) *)
let access is_alias name =
  let fields base rest = List.fold_left (fun e f -> ArrayAccess (e, StringLiteral f)) (Identifier base) rest in
  match String.split_on_char '.' name with
  | m :: g :: rest when is_alias m -> if rest = [] then None else Some (fields (m ^ "." ^ g) rest)
  | head :: (_ :: _ as rest) -> Some (fields head rest)
  | _ -> None

let rec expr al e =
  match e with
  | Identifier n | FunctionRef n -> Option.value (access al n) ~default:e
  | FunctionCall (n, args) ->
      let args = List.map (expr al) args in
      (match access al n with
       | Some f -> FunctionCall (call, StringLiteral n :: f :: args)
       | None -> FunctionCall (n, args))
  | Lambda (ps, body) -> Lambda (ps, List.map (stmt al) body)
  | e -> map_subexprs (expr al) e

and stmt al s =
  let e = expr al and block = List.map (stmt al) in
  match s with
  | Assign (n, v) -> (match access al n with Some a -> ArrayAssign (a, e v) | None -> Assign (n, e v))
  | FunctionCallStmt (n, args) ->
      (match e (FunctionCall (n, args)) with FunctionCall (n, args) -> FunctionCallStmt (n, args) | _ -> s)
  | FunctionCallWithAssign (v, n, args) ->
      (match access al v, e (FunctionCall (n, args)) with
       | Some a, c -> ArrayAssign (a, c)
       | None, FunctionCall (n, args) -> FunctionCallWithAssign (v, n, args)
       | None, _ -> s)
  | If (c, a, b) -> If (e c, block a, Option.map block b)
  | While (c, b) -> While (e c, block b)
  | For (v, a, b, k, body) -> For (v, e a, e b, Option.map e k, block body)
  | ForEach (v, c, b) -> ForEach (v, e c, block b)
  | Try (a, v, b, fin) -> Try (block a, v, block b, block fin)
  | Located (f, l, s) -> Located (f, l, stmt al s)
  | s -> map_stmt_exprs e s   (* instrukcje bez zagnieżdżonych instrukcji *)

(* session: licz też aliasy z wcześniejszych kawałków (REPL, wyrażenie w debuggerze) *)
let apply ?(session = false) (prog : program) =
  let own = List.filter_map (function ImportAs (_, a) -> Some a | _ -> None) prog.declarations in
  let al m = List.mem m own || (session && Hashtbl.mem seen m) in
  List.iter (fun a -> Hashtbl.replace seen a ()) own;
  let fields = List.map (fun (n, v) -> (n, expr al v)) in
  let fn (f : function_decl) =
    { f with body = List.map (stmt al) f.body; defaults = fields f.defaults } in
  { declarations = List.map (function
      | Statement s -> Statement (stmt al s)
      | FunctionDecl f -> FunctionDecl (fn f)
      | ClassDecl c -> ClassDecl { c with fields = fields c.fields; methods = List.map fn c.methods }
      | StructDecl s -> StructDecl { s with fields = fields s.fields }
      | UnionDecl u -> UnionDecl { u with fields = fields u.fields }
      | d -> d) prog.declarations }
