(* Wczytanie programu z tekstu: preprocesor, parser z wieloma błędami naraz, importy lokalne.
   Wspólne dla ferdek (CLI, --lsp) i placu zabaw w przeglądarce. *)

(* Import lokalny: jeśli obok pliku leży <nazwa>.ferdek, import dostaje ścieżkę do niego.
   Dzięki temu zagnieżdżone importy liczą się od pliku, który importuje. *)
let resolve_local_imports filename (prog : Ast.program) =
  let dir = Filename.dirname filename in
  let local name =
    let path = Filename.concat dir (name ^ ".ferdek") in
    if Sys.file_exists path then path else name in
  { Ast.declarations = List.map (function
      | Ast.Import name -> Ast.Import (local name)
      | Ast.ImportAs (name, alias) -> Ast.ImportAs (local name, alias)
      | d -> d) prog.declarations }

(* Literówka w wielowyrazowej funkcji wbudowanej (W MORDĘ JEŻA ILE MIEJSCA NA KANAPE(...)) rozpada
   się w lekserze na osobne słowa i kończy błędem składni - podpowiadamy najbliższą nazwę *)
let call_re = Str.regexp "W MORD[EĘ]* JE[ZŻ]*A \\([^(]*[^( ]\\) *("
let builtin_typo line_text =
  match Str.search_forward call_re line_text 0 with
  | exception Not_found -> ""
  | _ ->
      let name = Str.matched_group 1 line_text in
      let fns = List.filter_map (fun (w, _, _, f) -> if f then Some w else None) Keyword_docs.entries in
      if String.contains name ' ' && not (List.mem name fns) then Errors.suggest name fns else ""

(* Jeden przebieg parsera; przy błędzie: linia, komunikat i token, na którym się wyłożył *)
let parse_text filename text =
  let lexbuf = Lexing.from_string text in
  lexbuf.Lexing.lex_curr_p <- { lexbuf.Lexing.lex_curr_p with Lexing.pos_fname = filename };
  (* Linia poprzedniego tokenu: błąd często wychodzi dopiero na początku następnej instrukcji *)
  let prev_line = ref 1 and cur_line = ref 1 in
  let prev_end = ref 1 and cur_end = ref 1 in   (* kolumna tuż za tokenem *)
  let token lb =
    prev_line := !cur_line; prev_end := !cur_end;
    let t = Lexer.token lb in
    cur_line := lb.Lexing.lex_start_p.Lexing.pos_lnum;
    cur_end := lb.Lexing.lex_curr_p.Lexing.pos_cnum - lb.Lexing.lex_curr_p.Lexing.pos_bol + 1; t in
  try Ok (Parser.program token lexbuf)
  with Parser.Error ->
    let p = lexbuf.Lexing.lex_start_p in
    let tok = Lexing.lexeme lexbuf in
    let line = p.Lexing.pos_lnum and col = p.Lexing.pos_cnum - p.Lexing.pos_bol + 1 in
    let error_line = List.nth_opt (String.split_on_char '\n' text) (line - 1) |> Option.value ~default:"" in
    let hint = Syntax_errors.hint text filename ^ builtin_typo error_line in
    (* Token zaczyna nową linię: instrukcja urwała się na końcu poprzedniej - tam pokazujemy *)
    if !prev_line < line && tok <> "" then
      Error ((!prev_line, line, col), (!prev_line, !prev_end),
             Printf.sprintf "Błąd Parsowania! Walduś, coś tu jest pokręcone! W %s, linia %d, na końcu linii (dalej jest '%s').%s"
               filename !prev_line tok hint)
    else
      Error ((!prev_line, line, col), (line, col),
             Printf.sprintf "Błąd Parsowania! Walduś, coś tu jest pokręcone! W %s, linia %d, kolumna %d, przy '%s'.%s"
               filename line col tok hint)

(* Linie otwierają albo zamykają blok (albo kończy program) - wtedy po jej wycięciu posypałyby
   się fałszywe błędy dalej *)
let line_is_structural line =
  let lexbuf = Lexing.from_string line in
  let rec go () = match Lexer.token lexbuf with
    | Parser.EOF -> false
    | t when Formatter.opens t || Formatter.closes t || t = Parser.PROGRAM_END || t = Parser.PROGRAM_START -> true
    | _ -> go ()
    | exception _ -> true in
  go ()

(* Pierwszy token linii zaczyna instrukcję *)
let starts_statement line =
  match Lexer.token (Lexing.from_string line) with
  | Parser.VAR_DECL | ARRAY_DECL | PRINT | PRINT_INLINE | PRINT_NEWLINE | READ | ASSIGN_START
  | IF | ELSE | ELSE_IF | END_IF | WHILE | END_WHILE | FOR | FUNC_CALL | FUNC_CALL_ASSIGN | RETURN
  | TRY | CATCH | THROW | BREAK | CONTINUE | FUNC_DECL | FUNC_END | CLASS | STRUCT | END_STRUCT
  | UNION | END_UNION | ENUM | END_ENUM | IMPORT | PROGRAM_START | PROGRAM_END
  | SWITCH | CASE | DEFAULT | END_SWITCH | CONST | FINALLY -> true
  | _ -> false
  | exception _ -> true

(* Po błędzie wycinamy (zastępujemy pustą) linię z błędem i parsujemy dalej, żeby pokazać
   kilka błędów naraz. ponytail: naprawa na poziomie linii, bez odzyskiwania w gramatyce *)
let max_syntax_errors = 10

let parse_collecting filename text =
  let rec go text errors seen =
    match parse_text filename text with
    | Ok prog when errors = [] -> Ok prog
    | Ok _ -> Error (List.rev errors)
    | Error ((_, line, col), _, _) when List.mem (line, col) seen ->
        Error (List.rev errors)   (* ten sam token znowu - wycięcie nie pomogło *)
    | Error ((first, line, col), (rline, rcol), msg) ->
        let seen = (line, col) :: seen in
        let errors = (rline, rcol, msg) :: errors in
        let lines = Array.of_list (String.split_on_char '\n' text) in
        (* Wycinamy całą zepsutą instrukcję: od linii, w której się zaczęła, do linii błędu.
           Gdy błąd wyszedł dopiero na początku następnej linii, ta linia zostaje. *)
        let last = if first < line then line - 1 else line in
        let rec back l = if l <= 1 || starts_statement lines.(l - 1) then l else back (l - 1) in
        let span = if last > Array.length lines then []
                   else let start = back first in List.init (last - start + 1) (fun i -> start + i) in
        if List.length errors >= max_syntax_errors
           || not (List.exists (fun l -> String.trim lines.(l - 1) <> "") span)
           || List.exists (fun l -> line_is_structural lines.(l - 1)) span
        then Error (List.rev errors)
        else begin
          List.iter (fun l -> lines.(l - 1) <- "") span;
          go (String.concat "\n" (Array.to_list lines)) errors seen
        end in
  go text [] []

(* Błąd wczytania programu: linia (0 = nieznana), kolumna, komunikat *)
let lex_error_pos = Str.regexp "linii \\([0-9]+\\), kolumna \\([0-9]+\\)"

(* Tekst (już po preprocesorze albo przed) -> program albo lista błędów z pozycjami *)
let parse_source ?(preprocessed = false) filename text =
  if not preprocessed then Sources.register filename text;
  try
    let text = if preprocessed then text else Preprocessor.preprocess_string text in
    match parse_collecting filename text with
    | Ok prog ->
        (match Consts.check prog with
         | [] -> Ok (resolve_local_imports filename (Typy.apply prog))
         | errs ->
             let lines = Array.of_list (String.split_on_char '\n' text) in
             (* znaczek pod początkiem instrukcji, nie pod wcięciem *)
             let col l = if l < 1 || l > Array.length lines then 1 else
               let t = lines.(l - 1) in
               let k = ref 0 in
               while !k < String.length t && (t.[!k] = ' ' || t.[!k] = '\t') do incr k done;
               !k + 1 in
             Error (List.sort compare errs |> List.map (fun (l, _, m) ->
               (l, col l, if l = 0 then Printf.sprintf "A to nie tak! W %s: %s." filename m
                          else Printf.sprintf "A to nie tak! W %s, linia %d: %s." filename l m))))
    | Error errs -> Error errs
  with
  | Lexer.LexError msg ->
      let line, col =
        try ignore (Str.search_forward lex_error_pos msg 0);
            int_of_string (Str.matched_group 1 msg), int_of_string (Str.matched_group 2 msg)
        with Not_found -> 0, 1 in
      Error [line, col, Printf.sprintf "Błąd Leksera! Ktoś tu namieszał w słowach! W %s: %s (Paździoch ukradł słowa)." filename msg]
  | Failure msg ->
      Error [0, 1, Printf.sprintf "Błąd Preprocesora w %s: %s" filename msg]

