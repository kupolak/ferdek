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

(* Split string by separator; separator na początku/końcu daje puste elementy *)
let kanapa_przesun s sep =
  if sep = "" then [s]
  else Str.split_delim (Str.regexp_string sep) s

(* Replace all occurrences; pusty "stary" tekst = bez zmian *)
let kanapa_zamien s old_str new_str =
  if old_str = "" then s
  else Str.global_substitute (Str.regexp_string old_str) (fun _ -> new_str) s
