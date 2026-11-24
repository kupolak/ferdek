(* ferdek --fmt: porządkuje wcięcia (4 spacje na poziom bloku). Zmienia wyłącznie białe
   znaki na początku i końcu linii: komentarze, dyrektywy # i wnętrza wieloliniowych
   tekstów zostają, więc program znaczy dokładnie to samo (sprawdza to --fmt-check). *)

open Parser

let opens = function
  | IF | WHILE | FOR | FUNC_DECL | CLASS | STRUCT | UNION | ENUM | TRY | SWITCH -> true
  | _ -> false

let closes = function
  | END_IF | END_WHILE | FUNC_END | END_STRUCT | END_UNION | END_ENUM | END_SWITCH -> true
  | _ -> false

(* CO TO JE: przypadki o poziom głębiej, ich treść o dwa - blok liczy się podwójnie *)
let weight = function SWITCH | END_SWITCH -> 2 | _ -> 1

(* Linia na poziomie otwierającego bloku, bez zmiany głębokości: else, catch, nagłówek funkcji *)
let at_opener_level = function
  | ELSE | ELSE_IF | CATCH | FINALLY | FUNC_RETURNS | FUNC_PARAMS | CASE | DEFAULT -> true
  | _ -> false

(* Tokeny z numerami linii początku i końca; None, gdy lekser się wyłoży (wtedy nie formatujemy) *)
let tokens_by_line text =
  let lexbuf = Lexing.from_string text in
  let rec go acc =
    match Lexer.token lexbuf with
    | EOF -> Some (List.rev acc)
    | tok -> go ((tok, lexbuf.Lexing.lex_start_p.pos_lnum, lexbuf.Lexing.lex_curr_p.pos_lnum) :: acc)
    | exception Lexer.LexError _ -> None
  in
  go []

let is_directive line = String.length (String.trim line) > 0 && (String.trim line).[0] = '#'

let format source =
  let lines = Array.of_list (String.split_on_char '\n' source) in
  let n = Array.length lines in
  (* Dyrektywy preprocesora lekser by odrzucił - na czas analizy zamieniamy je na puste linie *)
  let lexable = String.concat "\n" (Array.to_list (Array.map (fun l -> if is_directive l then "" else l) lines)) in
  match tokens_by_line lexable with
  | None -> source
  | Some toks ->
      let per_line = Array.make (n + 2) [] in
      let raw = Array.make (n + 2) false in   (* linia wewnątrz wieloliniowego tekstu *)
      let heads = ref [] in   (* linie, w których zaczęły się otwarte teksty POWIEM PANU TAK *)
      List.iter (fun (tok, first, last) ->
        if first <= n then per_line.(first) <- tok :: per_line.(first);
        let keep a = for l = a + 1 to min last n do raw.(l) <- true done in
        (match tok with
         | STRING _ -> keep first
         | INTERP_HEAD _ -> heads := first :: !heads
         (* cały tekst z wstawkami zostaje jak jest, razem z wyrażeniami w {} *)
         | INTERP_END _ -> (match !heads with h :: t -> heads := t; keep h | [] -> ())
         | _ -> ())) toks;
      let depth = ref 0 in
      (* Poprzedni token w całym pliku: NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ po ")" to ciało lambdy -
         otwiera blok; po nazwie funkcji to tylko część nagłówka *)
      let prev = ref Parser.EOF in
      let lambda_body t p = t = Parser.FUNC_RETURNS && p = Parser.RPAREN in
      let blank_run = ref 0 in
      let out = Buffer.create (String.length source) in
      for i = 1 to n do
        let line = lines.(i - 1) in
        let trimmed = String.trim line in
        if raw.(i) then (Buffer.add_string out line; Buffer.add_char out '\n'; blank_run := 0)
        else if trimmed = "" then begin
          incr blank_run;
          if !blank_run = 1 then Buffer.add_char out '\n'   (* najwyżej jedna pusta linia z rzędu *)
        end else begin
          blank_run := 0;
          let toks = List.rev per_line.(i) in
          let back = match toks with
            | t :: _ when closes t -> weight t
            | t :: _ when at_opener_level t && not (lambda_body t !prev) -> 1
            | _ -> 0 in
          let level = if is_directive line then 0 else max 0 (!depth - back) in
          Buffer.add_string out (String.make (4 * level) ' ');
          Buffer.add_string out trimmed;
          Buffer.add_char out '\n';
          (* NO JAK NIE JAK TAK w środku linii to wyrażenie warunkowe (..., A PROSZĘ BARDZO a A DUPA TAM b),
             nie blok. ponytail: wyrażenie zaczynające linię kontynuacji policzy się jak blok *)
          List.iteri (fun k t ->
            if (opens t && not (t = Parser.IF && k > 0)) || lambda_body t !prev then depth := !depth + weight t
            else if closes t then depth := max 0 (!depth - weight t);
            prev := t) toks
        end
      done;
      (* Bez pustych linii na końcu; dokładnie jeden znak końca linii *)
      let s = Buffer.contents out in
      let len = ref (String.length s) in
      while !len > 0 && (s.[!len - 1] = '\n' || s.[!len - 1] = ' ') do decr len done;
      String.sub s 0 !len ^ "\n"
