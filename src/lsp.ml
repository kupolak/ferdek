(* ferdek --lsp: serwer Language Server Protocol na stdin/stdout.
   Umie: idź do definicji, znajdź użycia, zmień nazwę - w obrębie jednego pliku.
   Zasięgi liczymy z tokenów leksera (bez AST, bo AST nie ma pozycji):
   globalny, klasa (pola i metody), funkcja (parametry i lokalne, jak w kompilatorze -
   cała funkcja, niezależnie od miejsca deklaracji) i lambda. *)

open Parser

type scope = {
  id : int;
  parent : scope option;
  decls : (string, int) Hashtbl.t;   (* nazwa -> indeks tokenu z deklaracją *)
  is_method : bool;                  (* metoda: przypisanie nie sięga do globalnych *)
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
  fun ?(is_method = false) parent -> incr n; { id = !n; parent; decls = Hashtbl.create 8; is_method }

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
  let lambdas = ref [] in           (* ponytail: parametr lambdy widać do końca linii, bez śledzenia wyrażenia *)
  let classes = ref [] in           (* id zasięgów klas *)
  let record = ref false and enum = ref false and params = ref false in
  let block () = List.hd !blocks in
  for i = 0 to n - 1 do
    if i > 0 && toks.(i).line <> toks.(i - 1).line then lambdas := [];
    let cur = match !lambdas with s :: _ -> s | [] -> block () in
    toks.(i).scope <- cur;
    (match toks.(i).t with
     | IDENTIFIER _ | COMMA | ELLIPSIS when !params -> ()
     | _ -> params := false);
    match toks.(i).t, ident (i + 1) with
    | (FUNC_DECL | CLASS), Some name when not !record ->
        declare (block ()) name (i + 1);
        let is_method = toks.(i).t = FUNC_DECL && List.mem (block ()).id !classes in
        let inner = new_scope ~is_method (Some (block ())) in
        if toks.(i).t = CLASS then classes := inner.id :: !classes;
        toks.(i + 1).scope <- block ();
        blocks := inner :: !blocks
    | FUNC_END, _ -> if List.length !blocks > 1 then blocks := List.tl !blocks
    | FUNC_PARAMS, _ -> params := true
    | IDENTIFIER name, _ when !params -> declare (block ()) name i
    | (VAR_DECL | ARRAY_DECL | FOR | CATCH), Some name when not !record -> declare (block ()) name (i + 1)
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
        if block_body then blocks := s :: !blocks else lambdas := s :: !lambdas
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

(* Nazwa pod kursorem i jej wiązanie (zasięg deklaracji + nazwa) *)
let binding_at toks lines line ch =
  let hit = Array.to_list toks |> List.find_opt (fun tk ->
    match tk.t with
    | IDENTIFIER _ when tk.line = line + 1 ->
        let text = lines.(line) in
        let a = utf16_of_bytes text tk.col and b = utf16_of_bytes text (tk.col + tk.len) in
        a <= ch && ch <= b
    | _ -> false) in
  match hit with
  | Some ({ t = IDENTIFIER name; _ } as tk) ->
      Option.map (fun (s, decl) -> (name, s.id, decl)) (resolve tk.scope name)
  | _ -> None

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

let run () =
  set_binary_mode_in stdin true;
  set_binary_mode_out stdout true;
  let docs : (string, string) Hashtbl.t = Hashtbl.create 8 in
  let open Yojson.Safe.Util in
  let rec loop shutdown =
    match read_message () with
    | None -> if shutdown then 0 else 1
    | Some raw ->
        let msg = try Yojson.Safe.from_string raw with _ -> `Null in
        let id = msg |> member "id" in
        let meth = try msg |> member "method" |> to_string with _ -> "" in
        let params = msg |> member "params" in
        let doc_uri () = params |> member "textDocument" |> member "uri" |> to_string in
        (* Dokument, pozycja, tokeny - wspólne dla definicji, użyć i zmiany nazwy *)
        let at_cursor () =
          let uri = doc_uri () in
          let text = Option.value (Hashtbl.find_opt docs uri) ~default:"" in
          let lines = Array.of_list (String.split_on_char '\n' text) in
          let pos = params |> member "position" in
          let line = pos |> member "line" |> to_int and ch = pos |> member "character" |> to_int in
          let toks = analyze text in
          let b = if line < Array.length lines then binding_at toks lines line ch else None in
          uri, lines, toks, b in
        let loc uri lines tk = `Assoc ["uri", `String uri; "range", range lines tk] in
        (try match meth with
          | "initialize" ->
              reply id (`Assoc [
                "capabilities", `Assoc [
                  "textDocumentSync", `Int 1;   (* pełny tekst przy każdej zmianie *)
                  "definitionProvider", `Bool true;
                  "referencesProvider", `Bool true;
                  "renameProvider", `Bool true];
                "serverInfo", `Assoc ["name", `String "ferdek"; "version", `String "2.0"]])
          | "shutdown" -> reply id `Null
          | "exit" -> exit (if shutdown then 0 else 1)
          | "textDocument/didOpen" ->
              let d = params |> member "textDocument" in
              Hashtbl.replace docs (d |> member "uri" |> to_string) (d |> member "text" |> to_string)
          | "textDocument/didChange" ->
              (match params |> member "contentChanges" |> to_list |> List.rev with
               | last :: _ -> Hashtbl.replace docs (doc_uri ()) (last |> member "text" |> to_string)
               | [] -> ())
          | "textDocument/didClose" -> Hashtbl.remove docs (doc_uri ())
          | "textDocument/definition" ->
              let uri, lines, toks, b = at_cursor () in
              reply id (match b with Some (_, _, decl) -> loc uri lines toks.(decl) | None -> `Null)
          | "textDocument/references" ->
              let uri, lines, toks, b = at_cursor () in
              reply id (match b with
                | Some b -> `List (List.map (loc uri lines) (occurrences toks b))
                | None -> `List [])
          | "textDocument/rename" ->
              let uri, lines, toks, b = at_cursor () in
              let new_name = params |> member "newName" |> to_string in
              (match b with
               | None -> fail id (-32602) "Tu nie ma nazwy zdefiniowanej w tym pliku (wbudowanej nie zmienisz)"
               | Some _ when not (valid_name new_name) ->
                   fail id (-32602) (Printf.sprintf "'%s' to nie jest dobra nazwa" new_name)
               | Some b ->
                   let edits = List.map (fun tk ->
                     `Assoc ["range", range lines tk; "newText", `String new_name]) (occurrences toks b) in
                   reply id (`Assoc ["changes", `Assoc [uri, `List edits]]))
          | _ when id <> `Null -> fail id (-32601) ("Nie znam metody: " ^ meth)
          | _ -> ()   (* powiadomienia, których nie obsługujemy *)
        with e when id <> `Null -> fail id (-32603) (Printexc.to_string e));
        loop (shutdown || meth = "shutdown")
  in
  loop false
