(* Wbudowane funkcje: KALENDARZ - daty RRRR-MM-DD *)

open Value
open Builtins_common

(* ---- KALENDARZ: daty jako teksty RRRR-MM-DD, dni liczone od 1970-01-01 (jak kalendarz_* w C) ---- *)
let days_from_civil y m d =
  let y = if m <= 2 then y - 1 else y in
  let era = (if y >= 0 then y else y - 399) / 400 in
  let yoe = y - era * 400 in
  let doy = (153 * (if m > 2 then m - 3 else m + 9) + 2) / 5 + d - 1 in
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy in
  era * 146097 + doe - 719468

let civil_from_days z =
  let z = z + 719468 in
  let era = (if z >= 0 then z else z - 146096) / 146097 in
  let doe = z - era * 146097 in
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365 in
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100) in
  let mp = (5 * doy + 2) / 153 in
  let d = doy - (153 * mp + 2) / 5 + 1 in
  let m = if mp < 10 then mp + 3 else mp - 9 in
  ((yoe + era * 400) + (if m <= 2 then 1 else 0), m, d)

let days_in_month y m =
  match m with
  | 2 -> if (y mod 4 = 0 && y mod 100 <> 0) || y mod 400 = 0 then 29 else 28
  | 4 | 6 | 9 | 11 -> 30
  | _ -> 31

let parse_date what v =
  let s = to_string v in
  let bad () = raise (RuntimeError (Printf.sprintf "%s: zła data \"%s\" (ma być RRRR-MM-DD)" what s)) in
  let digit i = s.[i] >= '0' && s.[i] <= '9' in
  if String.length s <> 10 || s.[4] <> '-' || s.[7] <> '-'
     || not (List.for_all digit [0; 1; 2; 3; 5; 6; 8; 9]) then bad ();
  let y = int_of_string (String.sub s 0 4) and m = int_of_string (String.sub s 5 2)
  and d = int_of_string (String.sub s 8 2) in
  if y < 1 || m < 1 || m > 12 || d < 1 || d > days_in_month y m then bad ();
  days_from_civil y m d

let format_date what z =
  let y, m, d = civil_from_days z in
  if y < 1 || y > 9999 then raise (RuntimeError (what ^ ": wynik poza latami 1-9999"));
  Printf.sprintf "%04d-%02d-%02d" y m d

let weekdays = [| "poniedziałek"; "wtorek"; "środa"; "czwartek"; "piątek"; "sobota"; "niedziela" |]

let register () = add [
  ["JAKI DZIŚ DZIEŃ"], Some 0, (fun _ _ ->
      let t = Unix.localtime (Unix.time ()) in
      VString (Printf.sprintf "%04d-%02d-%02d" (t.tm_year + 1900) (t.tm_mon + 1) t.tm_mday));

  ["KTÓRA GODZINA"], Some 0, (fun _ _ ->
      let t = Unix.localtime (Unix.time ()) in
      VString (Printf.sprintf "%02d:%02d:%02d" t.tm_hour t.tm_min t.tm_sec));

  ["DZIEŃ TYGODNIA"], Some 1, (fun env args ->
      let z = parse_date "DZIEŃ TYGODNIA" (eval_expr env (List.hd args)) in
      VString weekdays.(((z mod 7) + 7 + 3) mod 7));

  ["DODAJ DNI"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [d; n] -> VString (format_date "DODAJ DNI" (parse_date "DODAJ DNI" d + to_int n))
      | _ -> VNull);

  ["ILE DNI MIĘDZY"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [a; b] -> VInt (parse_date "ILE DNI MIĘDZY" b - parse_date "ILE DNI MIĘDZY" a)
      | _ -> VNull);
  ]
