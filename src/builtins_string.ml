(* String library functions helpers *)

(* Tekst jako tablica znaków UTF-8 (każdy znak to 1-4 bajty). Polskie litery liczą się jako
   jeden znak; nieprawidłowe bajty - każdy osobno. Tak samo liczy runtime C. *)
let utf8_chars s =
  let n = String.length s in
  let rec go i acc =
    if i >= n then Array.of_list (List.rev acc)
    else
      let c = Char.code s.[i] in
      let len = if c < 0x80 then 1 else if c land 0xE0 = 0xC0 then 2
                else if c land 0xF0 = 0xE0 then 3 else if c land 0xF8 = 0xF0 then 4 else 1 in
      let len = if i + len > n then 1 else len in
      go (i + len) (String.sub s i len :: acc)
  in
  go 0 []

let utf8_length s = Array.length (utf8_chars s)

(* Pad string to target length (w znakach) *)
let kanapa_rozciagnij s target_len =
  let current_len = utf8_length s in
  if current_len >= target_len then
    s
  else
    let padding = String.make (target_len - current_len) ' ' in
    s ^ padding

(* Substring with bounds checking (indeksy w znakach) *)
let kanapa_potnij s start end_pos =
  let chars = utf8_chars s in
  let len = Array.length chars in
  if start < 0 || start >= len then
    raise (Failure "POTNIJ KANAPĘ: początek poza zakresem")
  else if end_pos < start || end_pos > len then
    raise (Failure "POTNIJ KANAPĘ: koniec poza zakresem")
  else
    String.concat "" (Array.to_list (Array.sub chars start (end_pos - start)))

(* Polskie litery w UTF-8: (mała, wielka) *)
let polskie = ["ą", "Ą"; "ć", "Ć"; "ę", "Ę"; "ł", "Ł"; "ń", "Ń"; "ó", "Ó"; "ś", "Ś"; "ź", "Ź"; "ż", "Ż"]

let zamien_wszystkie pary s =
  List.fold_left (fun acc (z, na) -> Str.global_substitute (Str.regexp_string z) (fun _ -> na) acc) s pary

(* Wielkie / małe litery - ASCII i polskie znaki *)
let kanapa_do_gory s = zamien_wszystkie polskie (String.uppercase_ascii s)
let kanapa_w_dol s = zamien_wszystkie (List.map (fun (m, w) -> (w, m)) polskie) (String.lowercase_ascii s)

(* Split string by separator; separator na początku/końcu daje puste elementy *)
let kanapa_przesun s sep =
  if sep = "" then [s]
  else Str.split_delim (Str.regexp_string sep) s

(* Replace all occurrences; pusty "stary" tekst = bez zmian *)
let kanapa_zamien s old_str new_str =
  if old_str = "" then s
  else Str.global_substitute (Str.regexp_string old_str) (fun _ -> new_str) s

(* Pozycja (w znakach) pierwszego wystąpienia fragmentu albo -1; pusty fragment jest na pozycji 0 *)
let kanapa_gdzie s f =
  let n = String.length s and k = String.length f in
  let rec find i = if i + k > n then -1 else if String.sub s i k = f then i else find (i + 1) in
  match find 0 with
  | -1 -> -1
  | byte -> utf8_length (String.sub s 0 byte)
