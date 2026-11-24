(* Kolorowanie składni (plac zabaw): fragmenty tekstu z rodzajem, liczone prawdziwym lekserem -
   słowa wielowyrazowe, pisownia bez polskich znaków i l.nazwa wychodzą tak jak w interpreterze *)

open Parser

type kind = Keyword | Builtin | String | Number | Comment | Directive | Constant

let kind_code = function
  | Keyword -> 0 | Builtin -> 1 | String -> 2 | Number -> 3 | Comment -> 4 | Directive -> 5 | Constant -> 6

(* (początek, koniec, rodzaj) w bajtach, rosnąco. Nazwy zmiennych i funkcji programu zostają bez
   koloru. Po błędzie leksera reszta tekstu też - i tak jest w niej coś nie tak. *)
let spans ~is_builtin text =
  let n = String.length text in
  let out = ref [] in
  let add a b k = if b > a then out := (a, b, k) :: !out in
  (* Dyrektywy preprocesora (#...) lekser by odrzucił: zamieniamy na spacje tej samej długości *)
  let masked = Bytes.of_string text in
  let line_start = ref 0 in
  for i = 0 to n do
    if i = n || text.[i] = '\n' then begin
      let s = ref !line_start in
      while !s < i && (text.[!s] = ' ' || text.[!s] = '\t') do incr s done;
      if !s < i && text.[!s] = '#' then begin
        add !s i Directive;
        Bytes.fill masked !line_start (i - !line_start) ' '
      end;
      line_start := i + 1
    end
  done;
  let masked = Bytes.to_string masked in
  let comment = "RYM CYM CYM" in
  let clen = String.length comment in
  (* Początek tokenu: pierwszy znak po [from], który nie jest odstępem ani komentarzem
     (lex_start_p po tekście w cudzysłowie wskazuje ostatni kawałek, więc liczymy sami) *)
  let rec skip i =
    if i >= n then i
    else match masked.[i] with
      | ' ' | '\t' | '\r' | '\n' -> skip (i + 1)
      | _ when i + clen <= n && String.sub masked i clen = comment ->
          let e = match String.index_from_opt masked i '\n' with Some e -> e | None -> n in
          add i e Comment;
          skip e
      | _ -> i in
  let lexbuf = Lexing.from_string masked in
  let rec go prev =
    match Lexer.token lexbuf with
    | exception _ -> ()
    | EOF -> ignore (skip prev)
    | t ->
        let start = skip prev and stop = lexbuf.Lexing.lex_curr_p.pos_cnum in
        (match t with
         | IDENTIFIER name -> if is_builtin name then add start stop Builtin
         | STRING _ | INTERP_HEAD _ ->
             (* przed cudzysłowem może stać POWIEM PANU TAK *)
             let q = String.index_from masked start '"' in
             add start q Keyword; add q stop String
         | INTERP_PART _ | INTERP_END _ -> add start stop String
         | INTEGER _ | FLOAT _ -> add start stop Number
         | TRUE | FALSE | NULL -> add start stop Constant
         | _ -> add start stop Keyword);
        go stop in
  go 0;
  List.sort compare !out
