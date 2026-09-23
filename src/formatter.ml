(* ferdek --fmt: porządkuje wcięcia (4 spacje na poziom bloku). Zmienia wyłącznie białe
   znaki na początku i końcu linii: komentarze, dyrektywy # i wnętrza wieloliniowych
   tekstów zostają, więc program znaczy dokładnie to samo (sprawdza to --fmt-check). *)

open Parser

let opens = function
  | IF | WHILE | FOR | FUNC_DECL | CLASS | STRUCT | UNION | ENUM | TRY -> true
  | _ -> false

let closes = function
  | END_IF | END_WHILE | FUNC_END | END_STRUCT | END_UNION | END_ENUM -> true
  | _ -> false

(* Linia na poziomie otwierającego bloku, bez zmiany głębokości: else, catch, nagłówek funkcji *)
let at_opener_level = function
  | ELSE | ELSE_IF | CATCH | FUNC_RETURNS | FUNC_PARAMS -> true
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
      List.iter (fun (tok, first, last) ->
        if first <= n then per_line.(first) <- tok :: per_line.(first);
        (match tok with
         | STRING _ -> for l = first + 1 to min last n do raw.(l) <- true done
         | _ -> ())) toks;
      let depth = ref 0 in
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
          let first_back = match toks with t :: _ -> closes t || at_opener_level t | [] -> false in
          let level = if is_directive line then 0 else max 0 (!depth - (if first_back then 1 else 0)) in
          Buffer.add_string out (String.make (4 * level) ' ');
          Buffer.add_string out trimmed;
          Buffer.add_char out '\n';
          List.iter (fun t -> if opens t then incr depth else if closes t then depth := max 0 (!depth - 1)) toks
        end
      done;
      (* Bez pustych linii na końcu; dokładnie jeden znak końca linii *)
      let s = Buffer.contents out in
      let len = ref (String.length s) in
      while !len > 0 && (s.[!len - 1] = '\n' || s.[!len - 1] = ' ') do decr len done;
      String.sub s 0 !len ^ "\n"
