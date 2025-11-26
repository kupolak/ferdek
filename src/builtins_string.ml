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

(* Split string by separator *)
let kanapa_przesun s sep =
  let rec split str acc =
    try
      let idx = String.index str (String.get sep 0) in
      if String.length sep <= String.length str - idx &&
         String.sub str idx (String.length sep) = sep then
        let part = String.sub str 0 idx in
        let rest = String.sub str (idx + String.length sep)
                                  (String.length str - idx - String.length sep) in
        split rest (part :: acc)
      else
        let rest = String.sub str (idx + 1) (String.length str - idx - 1) in
        split rest acc
    with Not_found -> (str :: acc)
  in
  if sep = "" then [s]
  else List.rev (split s [])

(* Replace all occurrences *)
let kanapa_zamien s old_str new_str =
  let rec replace_all str =
    try
      let idx = String.index str (String.get old_str 0) in
      let before = String.sub str 0 idx in
      let after = String.sub str (idx + String.length old_str)
                                (String.length str - idx - String.length old_str) in
      if String.length old_str <= String.length str - idx &&
         String.sub str idx (String.length old_str) = old_str then
        before ^ new_str ^ replace_all after
      else
        before ^ String.make 1 (String.get str idx) ^ replace_all after
    with Not_found -> str
  in
  replace_all s
