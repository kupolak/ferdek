(* String library functions helpers *)

(* Pad string to target length *)
let kanapa_rozciagnij s target_len =
  let current_len = String.length s in
  if current_len >= target_len then
    s
  else
    let padding = String.make (target_len - current_len) ' ' in
    s ^ padding

(* Substring with bounds checking *)
let kanapa_potnij s start end_pos =
  if start < 0 || start >= String.length s then
    raise (Failure "POTNIJ KANAPĘ: start index out of bounds")
  else if end_pos < start || end_pos > String.length s then
    raise (Failure "POTNIJ KANAPĘ: end index out of bounds")
  else
    String.sub s start (end_pos - start)

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
