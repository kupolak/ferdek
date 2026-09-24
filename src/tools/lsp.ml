(* ferdek --lsp: serwer Language Server Protocol na stdin/stdout.
   Umie: idź do definicji, znajdź użycia, zmień nazwę. Nazwy globalne modułu (i nazwy z importu
   w programie) szuka też w innych plikach .ferdek katalogu roboczego, które ten moduł importują.
   Zasięgi liczymy z tokenów leksera (bez AST, bo AST nie ma pozycji):
   globalny, klasa (pola i metody), funkcja (parametry i lokalne, jak w kompilatorze -
   cała funkcja, niezależnie od miejsca deklaracji) i lambda. *)

open Parser

type scope = {
  id : int;
  parent : scope option;
  decls : (string, int) Hashtbl.t;   (* nazwa -> indeks tokenu z deklaracją *)
  is_method : bool;                  (* metoda: przypisanie nie sięga do globalnych *)
  is_class : bool;                   (* ciało klasy: deklaracje to pola (obiekt["pole"]) *)
}

type tok = {
  t : Parser.token;
  line : int;          (* od 1 *)
  col : int;           (* bajt w linii *)
  len : int;           (* bajty *)
  mutable scope : scope;
}

let new_scope =
  let n = ref 0 in
  fun ?(is_method = false) ?(is_class = false) parent ->
    incr n; { id = !n; parent; decls = Hashtbl.create 8; is_method; is_class }

let tokens text =
  (* Dyrektywy preprocesora lekser by odrzucił - jak w formaterze zamieniamy je na puste linie *)
  let text = String.split_on_char '\n' text
             |> List.map (fun l -> if String.length (String.trim l) > 0 && (String.trim l).[0] = '#' then "" else l)
             |> String.concat "\n" in
  let lexbuf = Lexing.from_string text in
  let global = new_scope None in
  let rec go acc =
    match Lexer.token lexbuf with
    | EOF | exception _ -> List.rev acc   (* do pierwszego błędu leksera - reszty i tak nie da się czytać *)
    | t ->
        let s = lexbuf.Lexing.lex_start_p and e = lexbuf.Lexing.lex_curr_p in
        go ({ t; line = s.pos_lnum; col = s.pos_cnum - s.pos_bol; len = e.pos_cnum - s.pos_cnum; scope = global } :: acc)
  in
  global, Array.of_list (go [])

let rec resolve scope name =
  match Hashtbl.find_opt scope.decls name with
  | Some i -> Some (scope, i)
  | None -> Option.bind scope.parent (fun p -> resolve p name)

let declare scope name i = if not (Hashtbl.mem scope.decls name) then Hashtbl.replace scope.decls name i

(* Przypisuje tokenom zasięgi i zbiera deklaracje *)
let analyze text =
  let global, toks = tokens text in
  let n = Array.length toks in
  let ident i = if i < n then (match toks.(i).t with IDENTIFIER s -> Some s | _ -> None) else None in
  let blocks = ref [global] in      (* klasy i funkcje; zamyka je DO WIDZENIA PANU *)
  (* lambdy z wyrażeniem: zasięg i liczba otwartych nawiasów od początku lambdy. Ciało kończy się
     na "," albo ")" na jej poziomie (argument wywołania) albo na końcu linii *)
  let lambdas = ref [] in
  let classes = ref [] in           (* id zasięgów klas *)
  let record = ref false and enum = ref false and params = ref false in
  let block () = List.hd !blocks in
  for i = 0 to n - 1 do
    if i > 0 && toks.(i).line <> toks.(i - 1).line then lambdas := [];
    (match toks.(i).t with
     | COMMA | RPAREN ->
         while (match !lambdas with (_, d) :: _ -> !d = 0 | [] -> false) do lambdas := List.tl !lambdas done;
         if toks.(i).t = RPAREN then (match !lambdas with (_, d) :: _ -> decr d | [] -> ())
     | LPAREN -> List.iter (fun (_, d) -> incr d) !lambdas
     | _ -> ());
    let cur = match !lambdas with (s, _) :: _ -> s | [] -> block () in
    toks.(i).scope <- cur;
    (match toks.(i).t with
     | IDENTIFIER _ | COMMA | ELLIPSIS when !params -> ()
     | _ -> params := false);
    match toks.(i).t, ident (i + 1) with
    | (FUNC_DECL | CLASS), Some name when not !record ->
        declare (block ()) name (i + 1);
        let is_method = toks.(i).t = FUNC_DECL && List.mem (block ()).id !classes in
        let inner = new_scope ~is_method ~is_class:(toks.(i).t = CLASS) (Some (block ())) in
        if toks.(i).t = CLASS then classes := inner.id :: !classes;
        toks.(i + 1).scope <- block ();
        blocks := inner :: !blocks
    | FUNC_END, _ -> if List.length !blocks > 1 then blocks := List.tl !blocks
    | FUNC_PARAMS, _ -> params := true
    | IDENTIFIER name, _ when !params -> declare (block ()) name i
    | (VAR_DECL | CONST | ARRAY_DECL | FOR | CATCH), Some name when not !record -> declare (block ()) name (i + 1)
    | (STRUCT | UNION), Some name -> declare (block ()) name (i + 1); record := true
    | (END_STRUCT | END_UNION), _ -> record := false
    | ENUM, Some name -> declare (block ()) name (i + 1); enum := true
    | END_ENUM, _ -> enum := false
    | IDENTIFIER name, _ when !enum -> declare (block ()) name i
    | LAMBDA, _ ->
        let j = ref (i + 1) in
        while !j < n && toks.(!j).t <> RPAREN do incr j done;
        (* Z ciałem z instrukcjami (NO DOBRZE ... DO WIDZENIA PANU) lambda jest blokiem jak funkcja *)
        let block_body = !j + 1 < n && toks.(!j + 1).t = FUNC_RETURNS in
        let s = new_scope (Some cur) in
        for k = i + 1 to min !j (n - 1) do
          toks.(k).scope <- s;
          (match toks.(k).t with IDENTIFIER p -> declare s p k | _ -> ())
        done;
        if block_body then blocks := s :: !blocks else lambdas := (s, ref 0) :: !lambdas
    | _ -> ()
  done;
  (* Przypisanie do nieznanej nazwy tworzy zmienną w bieżącej funkcji (albo globalną).
     W metodzie przypisanie nie sięga do globalnych - tak robi interpreter. *)
  Array.iteri (fun i tk ->
    match tk.t, ident (i + 1) with
    | (ASSIGN_START | FUNC_CALL_ASSIGN | READ), Some name ->
        let s = toks.(i + 1).scope in
        let visible = match resolve s name with
          | Some (d, _) -> not (s.is_method && d.parent = None)
          | None -> false in
        if not visible then declare s name (i + 1)
    | _ -> ()) toks;
  toks

(* ---- pozycje LSP: linia od 0, znak w jednostkach UTF-16 ---- *)

let utf16_of_bytes line_text byte_col =
  let n = ref 0 in
  for k = 0 to min byte_col (String.length line_text) - 1 do
    let c = Char.code line_text.[k] in
    if c < 0x80 || c >= 0xC0 then incr n;
    if c >= 0xF0 then incr n   (* poza BMP: para zastępcza *)
  done;
  !n

let range lines tk =
  let text = if tk.line - 1 < Array.length lines then lines.(tk.line - 1) else "" in
  let pos b = `Assoc ["line", `Int (tk.line - 1); "character", `Int (utf16_of_bytes text b)] in
  `Assoc ["start", pos tk.col; "end", pos (tk.col + tk.len)]

(* Token pod kursorem; na styku dwóch tokenów wygrywa ten, który się tu zaczyna *)
let token_at toks lines line ch =
  if line >= Array.length lines then None else
  let text = lines.(line) in
  let span tk = utf16_of_bytes text tk.col, utf16_of_bytes text (tk.col + tk.len) in
  let on_line = Array.to_list toks |> List.filter (fun tk -> tk.line = line + 1) in
  match List.find_opt (fun tk -> let a, b = span tk in a <= ch && ch < b) on_line with
  | Some tk -> Some tk
  | None -> List.find_opt (fun tk -> snd (span tk) = ch) on_line

(* Nazwa pod kursorem i jej wiązanie (zasięg deklaracji + nazwa) *)
let binding_at toks lines line ch =
  match token_at toks lines line ch with
  | Some ({ t = IDENTIFIER name; _ } as tk) ->
      Option.map (fun (s, decl) -> (name, s.id, decl)) (resolve tk.scope name)
  | _ -> None

let root_scope toks =
  let rec up s = match s.parent with Some p -> up p | None -> s in
  if Array.length toks = 0 then None else Some (up toks.(0).scope)

let lexeme lines tk =
  let text = if tk.line - 1 < Array.length lines then lines.(tk.line - 1) else "" in
  if tk.col >= String.length text then "" else String.sub text tk.col (min tk.len (String.length text - tk.col))

(* ---- opisy: słowa kluczowe i wbudowane (z keyword_docs.ml) oraz nazwy z programu ---- *)

let doc_of_word w = List.find_opt (fun (word, _, _, _) -> word = w) Keyword_docs.entries

let keyword_doc lines tk =
  match tk.t with
  | IDENTIFIER n -> doc_of_word n
  | t -> (match doc_of_word (lexeme lines tk) with
          | Some d -> Some d
          (* pisownia bez polskich znaków: opis przy polskiej *)
          | None -> Option.bind (List.assoc_opt t Syntax_errors.keywords) doc_of_word)

(* Parametry funkcji zadeklarowanej w tokenie i (nagłówek zaraz po nazwie) *)
let function_params toks i =
  let n = Array.length toks in
  let ps = ref [] and in_params = ref false and j = ref (i + 1) in
  (try
    while !j < n do
      (match toks.(!j).t with
       | FUNC_RETURNS -> ()
       | FUNC_PARAMS -> in_params := true
       | IDENTIFIER p when !in_params -> ps := p :: !ps
       | ELLIPSIS when !in_params -> ps := "..." :: !ps
       | COMMA when !in_params -> ()
       | _ -> raise Exit);
      incr j
    done
  with Exit -> ());
  List.rev !ps

(* Czym jest nazwa zadeklarowana w tokenie i *)
let describe toks i name =
  let kind = match if i > 0 then Some toks.(i - 1).t else None with
    | Some FUNC_DECL -> Printf.sprintf "funkcja %s(%s)" name (String.concat ", " (function_params toks i))
    | Some CLASS -> "klasa " ^ name
    | Some STRUCT -> "mebel (struktura) " ^ name
    | Some UNION -> "unia " ^ name
    | Some ENUM -> "lista " ^ name
    | Some ARRAY_DECL -> "tablica " ^ name
    | Some CONST -> "stała " ^ name
    | Some FOR -> "zmienna pętli " ^ name
    | Some CATCH -> "złapany wyjątek " ^ name
    | Some (FUNC_PARAMS | COMMA | LPAREN) -> "parametr " ^ name
    | _ -> "zmienna " ^ name in
  Printf.sprintf "%s (linia %d)" kind toks.(i).line

let is_function_decl toks i = i > 0 && toks.(i - 1).t = FUNC_DECL
let is_class_decl toks i = i > 0 && toks.(i - 1).t = CLASS

(* ---- importy: O KOGO MOJE PIĘKNE OCZY WIDZĄ ścieżka [JAKO alias] ---- *)

let imports toks =
  let n = Array.length toks in
  let out = ref [] in
  Array.iteri (fun i tk ->
    if tk.t = IMPORT then begin
      let parts = ref [] and j = ref (i + 1) in
      let rec path () =
        if !j < n then match toks.(!j).t with
          | IDENTIFIER p -> parts := p :: !parts; incr j;
              if !j < n && toks.(!j).t = SLASH then (incr j; path ())
          | _ -> () in
      path ();
      let alias = if !j + 1 < n && toks.(!j).t = IMPORT_AS
                  then (match toks.(!j + 1).t with IDENTIFIER a -> Some a | _ -> None) else None in
      if !parts <> [] then out := (String.concat "/" (List.rev !parts), alias) :: !out
    end) toks;
  List.rev !out

let read_file f = try Some (In_channel.with_open_bin f In_channel.input_all) with Sys_error _ -> None

(* Plik modułu: najpierw obok programu, potem to, co znajdzie ferdek (stdlib) *)
let module_file ~find_module dir path =
  let local = Filename.concat dir (path ^ ".ferdek") in
  if Sys.file_exists local then Some local else find_module path

(* Nazwa z importu: l.nazwa (import JAKO l) albo nazwa z modułu zaimportowanego zwyczajnie.
   Wynik: plik modułu, jego tekst, tokeny i indeks deklaracji. Gdy moduł sam jej nie deklaruje,
   szukamy w modułach, które on importuje (import wkleja moduł w całości) - bez pętli. *)
let module_decl ~find_module dir toks name =
  let seen = Hashtbl.create 8 in
  let rec search dir toks name =
    let candidates = match String.index_opt name '.' with
      | Some k ->
          let alias = String.sub name 0 k and rest = String.sub name (k + 1) (String.length name - k - 1) in
          List.filter_map (fun (p, a) -> if a = Some alias then Some (p, rest) else None) (imports toks)
      | None -> List.filter_map (fun (p, a) -> if a = None then Some (p, name) else None) (imports toks) in
    List.find_map (fun (p, n) ->
      Option.bind (module_file ~find_module dir p) (fun f ->
        let key = (try Unix.realpath f with Unix.Unix_error _ -> f) ^ "\000" ^ n in
        if Hashtbl.mem seen key then None else begin
          Hashtbl.add seen key ();
          Option.bind (read_file f) (fun text ->
            let mtoks = analyze text in
            match Option.bind (root_scope mtoks) (fun g -> Hashtbl.find_opt g.decls n) with
            | Some i -> Some (f, text, mtoks, i)
            | None -> search (Filename.dirname f) mtoks n)
        end)) candidates in
  search dir toks name

(* Nazwy z modułów zaimportowanych z aliasem, do uzupełniania: (alias.nazwa, tokeny, indeks) *)
let module_names ~find_module dir toks =
  List.concat_map (fun (p, alias) ->
    match alias, module_file ~find_module dir p with
    | Some a, Some f ->
        (match read_file f with
         | None -> []
         | Some text ->
             let mtoks = analyze text in
             match root_scope mtoks with
             | None -> []
             | Some g -> Hashtbl.fold (fun n i acc -> (a ^ "." ^ n, mtoks, i) :: acc) g.decls [])
    | _ -> []) (imports toks)

(* ---- wiele plików: globalne nazwy modułu w plikach, które go importują ---- *)

let canonical f = try Unix.realpath f with Unix.Unix_error _ -> f

(* Pliki .ferdek w katalogu roboczym (rekursywnie, bez katalogów ukrytych i _build) *)
let workspace_files root =
  let rec walk dir acc =
    match Sys.readdir dir with
    | exception Sys_error _ -> acc
    | names ->
        Array.fold_left (fun acc n ->
          let p = Filename.concat dir n in
          if n = "" || n.[0] = '.' || n = "_build" || n = "node_modules" then acc
          else if Sys.is_directory p then walk p acc
          else if Filename.check_suffix n ".ferdek" then p :: acc
          else acc) acc names in
  walk root []

(* Symbol globalny pod kursorem: (plik z deklaracją, nazwa w tym pliku). None dla nazw lokalnych
   (w funkcji, klasie, lambdzie) - te zostają w swoim pliku *)
let global_symbol ~find_module file toks lines line ch =
  match token_at toks lines line ch with
  | Some ({ t = IDENTIFIER name; _ } as tk) ->
      (match resolve tk.scope name with
       | Some (s, _) -> if s.parent = None then Some (canonical file, name) else None
       | None ->
           Option.map (fun (f, _, mtoks, i) ->
             (canonical f, match mtoks.(i).t with IDENTIFIER n -> n | _ -> name))
             (module_decl ~find_module (Filename.dirname file) toks name))
  | _ -> None

(* Czy import pliku f daje nazwę n z pliku m: f to m albo f sam jej nie deklaruje i dostaje ją
   ze swoich zwykłych importów (dowolnie głęboko, bez pętli) *)
let provides ~find_module f n m =
  let seen = Hashtbl.create 8 in
  let rec go f =
    let cf = canonical f in
    if cf = m then true
    else if Hashtbl.mem seen cf then false
    else begin
      Hashtbl.add seen cf ();
      match read_file f with
      | None -> false
      | Some text ->
          let toks = analyze text in
          let declares = match root_scope toks with Some g -> Hashtbl.mem g.decls n | None -> false in
          not declares && List.exists (fun (p, a) ->
            a = None && match module_file ~find_module (Filename.dirname f) p with
              | Some f' -> go f'
              | None -> false) (imports toks)
    end in
  go f

(* Wystąpienia symbolu (m, n) w pliku: token i ile bajtów z przodu pominąć (alias "l.") *)
let uses_in ~find_module file toks (m, n) =
  let own =
    if canonical file <> m then []
    else Array.to_list toks |> List.filter_map (fun tk -> match tk.t with
      | IDENTIFIER x when x = n ->
          (match resolve tk.scope x with Some (s, _) when s.parent = None -> Some (tk, 0) | _ -> None)
      | _ -> None) in
  let imported = List.concat_map (fun (p, alias) ->
    match module_file ~find_module (Filename.dirname file) p with
    | Some f when provides ~find_module f n m ->
        let want, skip = match alias with Some a -> a ^ "." ^ n, String.length a + 1 | None -> n, 0 in
        Array.to_list toks |> List.filter_map (fun tk -> match tk.t with
          | IDENTIFIER x when x = want && resolve tk.scope x = None -> Some (tk, skip)
          | _ -> None)
    | _ -> []) (imports toks) in
  own @ imported

let contains s sub =
  let n = String.length sub and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = sub || go (i + 1)) in
  go 0

(* Wszystkie wystąpienia w plikach: (plik, linie, [(token, pominięte bajty)]) *)
let uses_everywhere ~find_module ~text_of files sym =
  let _, n = sym in
  List.filter_map (fun f ->
    match text_of f with
    | Some text when contains text n ->   (* szybki odsiew przed lekserem *)
        let toks = analyze text in
        (match uses_in ~find_module f toks sym with
         | [] -> None
         | us -> Some (f, Array.of_list (String.split_on_char '\n' text), us))
    | _ -> None) (List.sort_uniq compare files)

(* ---- URI <-> ścieżka ---- *)

let path_of_uri uri =
  let s = if String.length uri > 7 && String.sub uri 0 7 = "file://" then String.sub uri 7 (String.length uri - 7) else uri in
  let b = Buffer.create (String.length s) in
  let i = ref 0 in
  while !i < String.length s do
    (if s.[!i] = '%' && !i + 2 < String.length s then
       (match int_of_string_opt ("0x" ^ String.sub s (!i + 1) 2) with
        | Some c -> Buffer.add_char b (Char.chr c); i := !i + 2
        | None -> Buffer.add_char b '%')
     else Buffer.add_char b s.[!i]);
    incr i
  done;
  Buffer.contents b

let uri_of_path p =
  let p = if Filename.is_relative p then Filename.concat (Sys.getcwd ()) p else p in
  let b = Buffer.create (String.length p + 8) in
  Buffer.add_string b "file://";
  String.iter (fun c -> match c with
    | 'A'..'Z' | 'a'..'z' | '0'..'9' | '/' | '.' | '_' | '-' | '~' -> Buffer.add_char b c
    | c -> Buffer.add_string b (Printf.sprintf "%%%02X" (Char.code c))) p;
  Buffer.contents b

(* znak UTF-16 -> bajt w linii *)
let bytes_of_utf16 text ch =
  let n = String.length text in
  let rec go k u = if k >= n || u >= ch then k else
    let c = Char.code text.[k] in
    let len = if c < 0x80 then 1 else if c < 0xE0 then 2 else if c < 0xF0 then 3 else 4 in
    go (k + len) (u + if len = 4 then 2 else 1) in
  go 0 0

let occurrences toks (name, sid, _) =
  Array.to_list toks |> List.filter (fun tk ->
    match tk.t with
    | IDENTIFIER n when n = name ->
        (match resolve tk.scope n with Some (s, _) -> s.id = sid | None -> false)
    | _ -> false)

(* Nowa nazwa musi być dokładnie jedną nazwą dla leksera, a nie słowem kluczowym *)
let valid_name s =
  s <> "" && not (String.contains s ' ') &&
  (let lb = Lexing.from_string s in
   match Lexer.token lb with
   | IDENTIFIER n -> n = s && (match Lexer.token lb with EOF -> true | _ -> false)
   | _ | exception _ -> false)

(* ---- kolorowanie (semantic tokens): lekser jak na placu zabaw + nazwy z analizy zasięgów ---- *)

let token_types = ["keyword"; "function"; "string"; "number"; "comment"; "macro";
                   "class"; "struct"; "enum"; "parameter"; "variable"]
let token_modifiers = ["defaultLibrary"; "declaration"]

let type_index name =
  let rec go i = function x :: r -> if x = name then i else go (i + 1) r | [] -> 0 in
  go 0 token_types

(* Rodzaj nazwy po tokenie przed jej deklaracją *)
let ident_kind toks d =
  match if d > 0 then Some toks.(d - 1).t else None with
  | Some FUNC_DECL -> "function"
  | Some CLASS -> "class"
  | Some (STRUCT | UNION) -> "struct"
  | Some ENUM -> "enum"
  | Some (FUNC_PARAMS | COMMA | LPAREN) when toks.(d).scope.parent <> None -> "parameter"
  | _ -> "variable"

(* Dane w formacie LSP: dla każdego tokenu (różnica linii, różnica kolumny, długość, typ, modyfikatory);
   kolumny i długości w UTF-16, token nie przechodzi przez koniec linii *)
let semantic_tokens text =
  let lines = Array.of_list (String.split_on_char '\n' text) in
  let starts = Array.make (Array.length lines) 0 in
  Array.iteri (fun i l -> if i + 1 < Array.length lines then starts.(i + 1) <- starts.(i) + String.length l + 1) lines;
  let line_of byte =
    let rec go lo hi = if lo >= hi then lo else
      let mid = (lo + hi + 1) / 2 in if starts.(mid) <= byte then go mid hi else go lo (mid - 1) in
    go 0 (Array.length lines - 1) in
  let items = ref [] in
  (* fragment w bajtach [a, b), dzielony na linie *)
  let add_bytes a b typ mods =
    let rec go a =
      if a < b then begin
        let l = line_of a in
        let line_end = starts.(l) + String.length lines.(l) in
        let e = min b line_end in
        let u x = utf16_of_bytes lines.(l) (x - starts.(l)) in
        if e > a then items := (l, u a, u e - u a, typ, mods) :: !items;
        go (line_end + 1)
      end in
    go a in
  let is_builtin n = Value.Vars.mem Value.builtins n in
  List.iter (fun (a, b, k) ->
    let typ, mods = match k with
      | Highlight.Keyword | Highlight.Constant -> "keyword", 0
      | Highlight.Builtin -> "function", 1
      | Highlight.String -> "string", 0
      | Highlight.Number -> "number", 0
      | Highlight.Comment -> "comment", 0
      | Highlight.Directive -> "macro", 0 in
    add_bytes a b (type_index typ) mods) (Highlight.spans ~is_builtin text);
  let toks = analyze text in
  Array.iteri (fun i tk -> match tk.t with
    | IDENTIFIER n when not (is_builtin n) ->
        (match resolve tk.scope n with
         | Some (_, d) ->
             let a = starts.(tk.line - 1) + tk.col in
             add_bytes a (a + tk.len) (type_index (ident_kind toks d)) (if d = i then 2 else 0)
         | None -> ())
    | _ -> ()) toks;
  let sorted = List.sort_uniq (fun (l1, c1, _, _, _) (l2, c2, _, _, _) -> compare (l1, c1) (l2, c2)) !items in
  let _, _, data = List.fold_left (fun (pl, pc, acc) (l, c, len, typ, mods) ->
    let dc = if l = pl then c - pc else c in
    (l, c, List.rev_append [l - pl; dc; len; typ; mods] acc)) (0, 0, []) sorted in
  List.rev data

(* ---- JSON-RPC ---- *)

let send json =
  let body = Yojson.Safe.to_string json in
  Printf.printf "Content-Length: %d\r\n\r\n%s%!" (String.length body) body

let reply id result = send (`Assoc ["jsonrpc", `String "2.0"; "id", id; "result", result])
let fail id code msg =
  send (`Assoc ["jsonrpc", `String "2.0"; "id", id;
                "error", `Assoc ["code", `Int code; "message", `String msg]])

let read_message () =
  let rec headers len =
    match input_line stdin with
    | exception End_of_file -> None
    | l ->
        let l = String.trim l in
        if l = "" then (match len with Some n -> Some n | None -> headers None)
        else match String.split_on_char ':' l with
          | [k; v] when String.lowercase_ascii (String.trim k) = "content-length" ->
              headers (int_of_string_opt (String.trim v))
          | _ -> headers len
  in
  Option.bind (headers None) (fun n ->
    match really_input_string stdin n with
    | s -> Some s
    | exception End_of_file -> None)

let pos line ch = `Assoc ["line", `Int line; "character", `Int ch]

let notify meth params = send (`Assoc ["jsonrpc", `String "2.0"; "method", `String meth; "params", params])

(* Zmienne lokalne (w funkcjach i lambdach), których nikt nie odczytuje - ostrzeżenie.
   Na najwyższym poziomie nie ostrzegamy: moduł może je wystawiać dla importujących. *)
let unused toks =
  let n = Array.length toks in
  let prev i = if i > 0 then Some toks.(i - 1).t else None in
  let write i = match prev i with
    | Some (ASSIGN_START | FUNC_CALL_ASSIGN | READ) -> not (i + 1 < n && toks.(i + 1).t = LBRACKET)
    | _ -> false in
  Array.to_list (Array.mapi (fun i tk -> (i, tk)) toks) |> List.filter_map (fun (i, tk) ->
    match tk.t, prev i with
    | IDENTIFIER name, Some (VAR_DECL | CONST | ARRAY_DECL) ->
        (match resolve tk.scope name with
         | Some (s, d) when d = i && s.parent <> None && not s.is_class ->
             let reads = occurrences toks (name, s.id, d)
                         |> List.filter (fun t -> t != tk && not (write (let rec idx k = if toks.(k) == t then k else idx (k + 1) in idx 0))) in
             if reads = [] then Some (tk, Printf.sprintf "Zmienna %s nie jest nigdzie odczytywana" name) else None
         | _ -> None)
    | _ -> None)

(* Błędy składni i problemy z --check, od razu po otwarciu i każdej zmianie *)
let publish ~diagnose uri text =
  let lines = Array.of_list (String.split_on_char '\n' text) in
  let found = try diagnose (path_of_uri uri) text with _ -> [] in
  let warnings = try unused (analyze text) with _ -> [] in
  let warn_diags = List.map (fun (tk, msg) ->
    `Assoc ["range", range lines tk; "severity", `Int 2; "source", `String "ferdek"; "message", `String msg]) warnings in
  let diags = List.map (fun (line, col, msg) ->
    let l = max 0 (line - 1) in
    let lt = if l < Array.length lines then lines.(l) else "" in
    let c = utf16_of_bytes lt (max 0 (col - 1)) in
    let e = max (c + 1) (utf16_of_bytes lt (String.length lt)) in
    `Assoc ["range", `Assoc ["start", pos l c; "end", pos l e]; "severity", `Int 1;
            "source", `String "ferdek"; "message", `String msg]) found in
  notify "textDocument/publishDiagnostics" (`Assoc ["uri", `String uri; "diagnostics", `List (diags @ warn_diags)])

(* Podpowiedź argumentów: najbliższy niezamknięty nawias przed kursorem, nazwa przed nim i liczba
   przecinków. Wbudowane - sygnatura z opisów słów, funkcje programu i modułów - z nagłówka. *)
let signature_help ~find_module dir toks lines line ch =
  let text l = if l < Array.length lines then lines.(l) else "" in
  let before tk =
    tk.line - 1 < line || (tk.line - 1 = line && utf16_of_bytes (text line) (tk.col + tk.len) <= ch) in
  let stack = ref [] in
  Array.iteri (fun i tk ->
    if before tk then match tk.t with
      | LPAREN ->
          let name = if i > 0 then (match toks.(i - 1).t with IDENTIFIER n -> Some (n, i - 1) | _ -> None) else None in
          stack := (name, ref 0) :: !stack
      | RPAREN -> (match !stack with _ :: r -> stack := r | [] -> ())
      | COMMA -> (match !stack with (_, k) :: _ -> incr k | [] -> ())
      | _ -> ()) toks;
  let signature label params doc active =
    `Assoc ["signatures", `List [`Assoc ([
              "label", `String label;
              "parameters", `List (List.map (fun p -> `Assoc ["label", `String p]) params)]
              @ (match doc with Some d -> ["documentation", `String d] | None -> []))];
            "activeSignature", `Int 0;
            (* po "..." każdy kolejny argument to ta sama pozycja *)
            "activeParameter", `Int (if params <> [] && List.nth params (List.length params - 1) = "..."
                                     then min active (List.length params - 1) else active)] in
  match !stack with
  | (Some (name, i), k) :: _ ->
      (match doc_of_word name with
       | Some (_, insert, doc, true) ->
           let params = match String.index_opt insert '(' with
             | Some a when String.length insert > a + 2 ->
                 String.split_on_char ',' (String.sub insert (a + 1) (String.length insert - a - 2))
                 |> List.map String.trim
             | _ -> [] in
           signature insert params (Some doc) !k
       | _ ->
           let from toks d = let ps = function_params toks d in
             signature (Printf.sprintf "%s(%s)" name (String.concat ", " ps)) ps None !k in
           match resolve toks.(i).scope name with
           | Some (_, d) when is_function_decl toks d -> from toks d
           | Some _ -> `Null
           | None ->
               match module_decl ~find_module dir toks name with
               | Some (_, _, mtoks, d) when is_function_decl mtoks d -> from mtoks d
               | _ -> `Null)
  | _ -> `Null

(* Uzupełnianie: słowa kluczowe, wbudowane, nazwy z pliku i z modułów JAKO.
   Słowa wielowyrazowe podmieniają to, co już napisano ("W MO" -> "W MORDĘ JEŻA"). *)
let completion ~find_module dir toks lines line ch =
  let text = if line < Array.length lines then lines.(line) else "" in
  let cur = bytes_of_utf16 text ch in
  let before = String.sub text 0 (min cur (String.length text)) in
  let is_word c = match c with 'A'..'Z' | 'a'..'z' | '0'..'9' | '_' | '.' -> true | c -> Char.code c >= 0x80 in
  let boundary k = k = 0 || not (is_word before.[k - 1]) in
  (* najdłuższy koniec "before" (od granicy słowa), który jest początkiem słowa w *)
  let typed w =
    let rec go k =
      if k > String.length before then None
      else
        let len = String.length before - k in
        if len > 0 && len <= String.length w && boundary k && String.sub w 0 len = String.sub before k len
        then Some k else go (k + 1) in
    go 0 in
  let word_start = let k = ref (String.length before) in
    while !k > 0 && is_word before.[!k - 1] do decr k done; !k in
  let edit start new_text =
    `Assoc ["range", `Assoc ["start", pos line (utf16_of_bytes text start); "end", pos line ch];
            "newText", `String new_text] in
  let item ?(snippet = false) ?doc ~kind ~detail label insert start =
    `Assoc ([ "label", `String label; "kind", `Int kind; "detail", `String detail;
              "textEdit", edit start insert ]
            @ (if snippet then ["insertTextFormat", `Int 2] else [])
            @ (match doc with Some d -> ["documentation", `String d] | None -> [])) in
  let keywords = List.filter_map (fun (word, insert, doc, is_fn) ->
    let start = match typed word with Some k -> Some k | None -> if word_start = cur then Some cur else None in
    Option.map (fun start ->
      if is_fn then item ~snippet:true ~doc ~kind:3 ~detail:insert word (word ^ "($0)") start
      else item ~doc ~kind:14 ~detail:"słowo kluczowe" word word start) start) Keyword_docs.entries in
  let seen = Hashtbl.create 32 in
  let name_item toks i name =
    if Hashtbl.mem seen name then None else begin
      Hashtbl.add seen name ();
      let kind = if is_function_decl toks i then 3 else if is_class_decl toks i then 7 else 6 in
      Some (item ~kind ~detail:(describe toks i name) name name word_start)
    end in
  let own = List.filter_map (fun (i, tk) -> match tk.t with
    | IDENTIFIER n -> (match resolve tk.scope n with
        | Some (_, d) when d = i -> name_item toks i n
        | _ -> None)
    | _ -> None) (List.mapi (fun i tk -> (i, tk)) (Array.to_list toks)) in
  let from_modules = List.filter_map (fun (n, mtoks, i) -> name_item mtoks i n)
      (module_names ~find_module dir toks) in
  `List (keywords @ own @ from_modules)

let run ~diagnose ~find_module () =
  set_binary_mode_in stdin true;
  set_binary_mode_out stdout true;
  let docs : (string, string) Hashtbl.t = Hashtbl.create 8 in
  let root = ref None in   (* katalog roboczy z initialize; bez niego szukamy tylko w otwartych plikach *)
  let open Yojson.Safe.Util in
  (* Tekst pliku: z edytora, jeśli otwarty (może być niezapisany), inaczej z dysku *)
  let text_of f =
    let cf = canonical f in
    match Hashtbl.fold (fun uri t acc ->
      if acc = None && canonical (path_of_uri uri) = cf then Some t else acc) docs None with
    | Some t -> Some t
    | None -> read_file f in
  (* Pliki do przeszukania: katalog roboczy, otwarte dokumenty, plik bieżący i plik deklaracji *)
  let search_files file (m, _) =
    (match !root with Some r -> workspace_files r | None -> [])
    @ Hashtbl.fold (fun uri _ acc -> path_of_uri uri :: acc) docs [] @ [file; m] in
  let in_root f = match !root with
    | Some r -> let r = canonical r ^ "/" in String.length f > String.length r && String.sub f 0 (String.length r) = r
    | None -> Hashtbl.fold (fun uri _ acc -> acc || canonical (path_of_uri uri) = f) docs false in
  (* plik bieżący pod swoim URI z edytora (może nie istnieć na dysku) *)
  let uri_for uri f = if canonical f = canonical (path_of_uri uri) then uri else uri_of_path f in
  (* token przesunięty o pominięte bajty (alias "l." przed nazwą) *)
  let shifted (tk, skip) = { tk with col = tk.col + skip; len = tk.len - skip } in
  let rec loop shutdown =
    match read_message () with
    | None -> if shutdown then 0 else 1
    | Some raw ->
        let msg = try Yojson.Safe.from_string raw with _ -> `Null in
        let id = msg |> member "id" in
        let meth = try msg |> member "method" |> to_string with _ -> "" in
        let params = msg |> member "params" in
        let doc_uri () = params |> member "textDocument" |> member "uri" |> to_string in
        (* Dokument, pozycja, tokeny - wspólne dla definicji, użyć, zmiany nazwy, podpowiedzi *)
        let at_cursor () =
          let uri = doc_uri () in
          let text = Option.value (Hashtbl.find_opt docs uri) ~default:"" in
          let lines = Array.of_list (String.split_on_char '\n' text) in
          let p = params |> member "position" in
          let line = p |> member "line" |> to_int and ch = p |> member "character" |> to_int in
          let toks = analyze text in
          uri, lines, toks, line, ch in
        let dir_of uri = Filename.dirname (path_of_uri uri) in
        let loc uri lines tk = `Assoc ["uri", `String uri; "range", range lines tk] in
        let markdown s = `Assoc ["contents", `Assoc ["kind", `String "markdown"; "value", `String s]] in
        (try match meth with
          | "initialize" ->
              (match params |> member "rootUri" with
               | `String u -> root := Some (path_of_uri u)
               | _ -> (match params |> member "rootPath" with `String p -> root := Some p | _ -> ()));
              reply id (`Assoc [
                "capabilities", `Assoc [
                  "textDocumentSync", `Int 1;   (* pełny tekst przy każdej zmianie *)
                  "definitionProvider", `Bool true;
                  "referencesProvider", `Bool true;
                  "renameProvider", `Bool true;
                  "hoverProvider", `Bool true;
                  "documentFormattingProvider", `Bool true;
                  "signatureHelpProvider", `Assoc ["triggerCharacters", `List [`String "("; `String ","]];
                  "semanticTokensProvider", `Assoc [
                    "legend", `Assoc ["tokenTypes", `List (List.map (fun s -> `String s) token_types);
                                      "tokenModifiers", `List (List.map (fun s -> `String s) token_modifiers)];
                    "full", `Bool true];
                  "completionProvider", `Assoc []];
                "serverInfo", `Assoc ["name", `String "ferdek"; "version", `String "1.0"]])
          | "shutdown" -> reply id `Null
          | "exit" -> exit (if shutdown then 0 else 1)
          | "textDocument/didOpen" ->
              let d = params |> member "textDocument" in
              let uri = d |> member "uri" |> to_string and text = d |> member "text" |> to_string in
              Hashtbl.replace docs uri text;
              publish ~diagnose uri text
          | "textDocument/didChange" ->
              (match params |> member "contentChanges" |> to_list |> List.rev with
               | last :: _ ->
                   let uri = doc_uri () and text = last |> member "text" |> to_string in
                   Hashtbl.replace docs uri text;
                   publish ~diagnose uri text
               | [] -> ())
          | "textDocument/didClose" ->
              let uri = doc_uri () in
              Hashtbl.remove docs uri;
              notify "textDocument/publishDiagnostics" (`Assoc ["uri", `String uri; "diagnostics", `List []])
          | "textDocument/definition" ->
              let uri, lines, toks, line, ch = at_cursor () in
              reply id (match binding_at toks lines line ch, token_at toks lines line ch with
                | Some (_, _, decl), _ -> loc uri lines toks.(decl)
                | None, Some { t = IDENTIFIER name; _ } ->
                    (match module_decl ~find_module (dir_of uri) toks name with
                     | Some (f, text, mtoks, i) ->
                         loc (uri_of_path f) (Array.of_list (String.split_on_char '\n' text)) mtoks.(i)
                     | None -> `Null)
                | _ -> `Null)
          | "textDocument/hover" ->
              let uri, lines, toks, line, ch = at_cursor () in
              reply id (match token_at toks lines line ch with
                | None -> `Null
                | Some tk ->
                    match binding_at toks lines line ch with
                    | Some (name, _, decl) -> markdown (describe toks decl name)
                    | None ->
                        match keyword_doc lines tk with
                        | Some (_, insert, doc, _) -> markdown (Printf.sprintf "**%s**\n\n%s" insert doc)
                        | None ->
                            match tk.t with
                            | IDENTIFIER name ->
                                (match module_decl ~find_module (dir_of uri) toks name with
                                 | Some (f, _, mtoks, i) ->
                                     markdown (describe mtoks i name ^ " - z modułu " ^ Filename.basename f)
                                 | None -> `Null)
                            | _ -> `Null)
          | "textDocument/semanticTokens/full" ->
              let text = Option.value (Hashtbl.find_opt docs (doc_uri ())) ~default:"" in
              reply id (`Assoc ["data", `List (List.map (fun n -> `Int n) (semantic_tokens text))])
          | "textDocument/signatureHelp" ->
              let uri, lines, toks, line, ch = at_cursor () in
              reply id (signature_help ~find_module (dir_of uri) toks lines line ch)
          | "textDocument/formatting" ->
              (* jak ferdek --fmt; jedna zmiana na cały dokument, brak zmian - pusta lista *)
              let uri = doc_uri () in
              let text = Option.value (Hashtbl.find_opt docs uri) ~default:"" in
              let formatted = Formatter.format text in
              reply id (if formatted = text then `List [] else
                let lines = Array.of_list (String.split_on_char '\n' text) in
                let last = Array.length lines - 1 in
                `List [`Assoc ["range", `Assoc ["start", pos 0 0;
                                                "end", pos last (utf16_of_bytes lines.(last) (String.length lines.(last)))];
                               "newText", `String formatted]])
          | "textDocument/completion" ->
              let uri, lines, toks, line, ch = at_cursor () in
              reply id (completion ~find_module (dir_of uri) toks lines line ch)
          | "textDocument/references" ->
              let uri, lines, toks, line, ch = at_cursor () in
              let file = path_of_uri uri in
              reply id (match global_symbol ~find_module file toks lines line ch with
                | Some sym ->
                    `List (List.concat_map (fun (f, flines, us) ->
                      List.map (fun u -> loc (uri_for uri f) flines (shifted u)) us)
                      (uses_everywhere ~find_module ~text_of (search_files file sym) sym))
                | None ->
                    match binding_at toks lines line ch with
                    | Some b -> `List (List.map (loc uri lines) (occurrences toks b))
                    | None -> `List [])
          | "textDocument/rename" ->
              let uri, lines, toks, line, ch = at_cursor () in
              let file = path_of_uri uri in
              let new_name = params |> member "newName" |> to_string in
              (match binding_at toks lines line ch, global_symbol ~find_module file toks lines line ch with
               | None, None -> fail id (-32602) "Tu nie ma nazwy zdefiniowanej w programie (wbudowanej nie zmienisz)"
               | _ when not (valid_name new_name) ->
                   fail id (-32602) (Printf.sprintf "'%s' to nie jest dobra nazwa" new_name)
               | _, Some (m, _) when not (in_root m) ->
                   fail id (-32602) (Printf.sprintf "%s jest poza katalogiem roboczym - tam nazwy nie zmieniam" m)
               | _, Some sym ->
                   let changes = List.map (fun (f, flines, us) ->
                     uri_for uri f, `List (List.map (fun u ->
                       `Assoc ["range", range flines (shifted u); "newText", `String new_name]) us))
                     (uses_everywhere ~find_module ~text_of (search_files file sym) sym) in
                   reply id (`Assoc ["changes", `Assoc changes])
               | Some b, None ->
                   let edits = List.map (fun tk ->
                     `Assoc ["range", range lines tk; "newText", `String new_name]) (occurrences toks b) in
                   reply id (`Assoc ["changes", `Assoc [uri, `List edits]]))
          | _ when id <> `Null -> fail id (-32601) ("Nie znam metody: " ^ meth)
          | _ -> ()   (* powiadomienia, których nie obsługujemy *)
        with e when id <> `Null -> fail id (-32603) (Printexc.to_string e));
        loop (shutdown || meth = "shutdown")
  in
  loop false
