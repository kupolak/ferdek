(* Wspólne komunikaty błędów *)

(* "1 argumentu", "2 argumentów" - dopełniacz po "oczekuje" *)
let argumentow n = Printf.sprintf "%d %s" n (if n = 1 then "argumentu" else "argumentów")

let wrong_arg_count func_name expected got =
  Printf.sprintf "%s oczekuje %s, podano %d" func_name (argumentow expected) got

(* ---- "Może chodziło o ...?" przy nieznanej nazwie ---- *)

(* Znaki UTF-8 (ą to jeden znak, nie dwa bajty) *)
let utf8_chars s =
  let n = String.length s in
  let rec go i acc =
    if i >= n then List.rev acc
    else
      let c = Char.code s.[i] in
      let len = if c < 0x80 then 1 else if c < 0xE0 then 2 else if c < 0xF0 then 3 else 4 in
      let len = min len (n - i) in
      go (i + len) (String.sub s i len :: acc) in
  Array.of_list (go 0 [])

let distance a b =
  let a = utf8_chars a and b = utf8_chars b in
  let la = Array.length a and lb = Array.length b in
  let d = Array.make_matrix (la + 1) (lb + 1) 0 in
  for i = 0 to la do d.(i).(0) <- i done;
  for j = 0 to lb do d.(0).(j) <- j done;
  for i = 1 to la do
    for j = 1 to lb do
      let cost = if a.(i - 1) = b.(j - 1) then 0 else 1 in
      d.(i).(j) <- min (min (d.(i - 1).(j) + 1) (d.(i).(j - 1) + 1)) (d.(i - 1).(j - 1) + cost)
    done
  done;
  d.(la).(lb)

(* Najbliższa nazwa (literówka, zamienione litery, wielkość liter) *)
let closest name candidates =
  let low = String.lowercase_ascii in
  let len = Array.length (utf8_chars name) in
  let limit = if len <= 2 then 0 else if len <= 3 then 1 else if len <= 6 then 2 else 3 in   (* krótkie: tylko wielkość liter *)
  let best = List.sort_uniq compare candidates
    |> List.filter (fun c -> c <> name)
    |> List.fold_left (fun best c ->
         let d = distance (low name) (low c) in
         match best with
         | Some (bd, _) when bd <= d -> best
         | _ when d <= limit -> Some (d, c)
         | _ -> best) None in
  Option.map snd best

(* Dopisek do zdania: " Może chodziło o 'x'?" albo "" *)
let suggest name candidates =
  match closest name candidates with Some c -> Printf.sprintf " Może chodziło o '%s'?" c | None -> ""

(* "Nieznana zmienna: licnzik. Może chodziło o 'licznik'?" *)
let unknown what name candidates =
  Printf.sprintf "Nieznana %s: %s%s" what name
    (match closest name candidates with Some c -> Printf.sprintf ". Może chodziło o '%s'?" c | None -> "")
