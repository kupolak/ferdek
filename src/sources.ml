(* Teksty wczytanych plików (program i moduły) - do pokazania linii z błędem.
   Interpreter czyta je stąd, a kompilator wbudowuje w program C, żeby oba tryby
   pokazywały ten sam fragment. *)

let texts : (string, string array) Hashtbl.t = Hashtbl.create 8

(* Bez końcowych spacji, tabulatorów i \r - tak samo w obu trybach *)
let rstrip s =
  let n = ref (String.length s) in
  while !n > 0 && (match s.[!n - 1] with ' ' | '\t' | '\r' -> true | _ -> false) do decr n done;
  String.sub s 0 !n

let register file text =
  if file <> "" then Hashtbl.replace texts file (Array.of_list (List.map rstrip (String.split_on_char '\n' text)))

let line file n =
  match Hashtbl.find_opt texts file with
  | Some a when n >= 1 && n <= Array.length a -> Some a.(n - 1)
  | _ -> None

let all () = Hashtbl.fold (fun f a acc -> (f, a) :: acc) texts [] |> List.sort compare

(* Linia z ^ pod kolumną (bajtową, od 1) - dla błędów składni *)
let caret file n col =
  match line file n with
  | None -> ""
  | Some l ->
      let upto = String.sub l 0 (max 0 (min (col - 1) (String.length l))) in
      (* tabulatory zostają tabulatorami, reszta to spacje - jeden znak na znak UTF-8 *)
      let pad = Buffer.create 16 in
      String.iter (fun c -> if c = '\t' then Buffer.add_char pad '\t'
                    else if Char.code c land 0xC0 <> 0x80 then Buffer.add_char pad ' ') upto;
      Printf.sprintf "\n%5d | %s\n      | %s^" n l (Buffer.contents pad)

let max_frames = 8

(* Linia z błędem i ścieżka wywołań (od najgłębszej), każda pozycja w osobnej linii.
   Ten sam tekst drukuje print_context w runtime C (compiler.ml). *)
let context (file, n) frames =
  let b = Buffer.create 256 in
  (match line file n with Some l -> Printf.bprintf b "%5d | %s\n" n l | None -> ());
  (* Powtórzenia z rekurencji zwijamy: "(12 razy)" *)
  let rec groups = function
    | [] -> []
    | x :: rest ->
        (match groups rest with
         | (y, k) :: tl when y = x -> (x, k + 1) :: tl
         | g -> (x, 1) :: g) in
  (* jak pierścień w C: pamiętamy 256 najgłębszych ramek, starsze tylko liczymy *)
  let window = 256 in
  let older = max 0 (List.length frames - window) in
  let gs = groups (List.filteri (fun i _ -> i < window) frames) in
  List.iteri (fun i ((name, (f, l)), k) ->
    if i < max_frames then begin
      (* ten sam plik co błąd - wystarczy numer linii *)
      if f = "" || f = file then Printf.bprintf b "  w funkcji %s, wywołanej w linii %d" name l
      else Printf.bprintf b "  w funkcji %s, wywołanej w %s, linia %d" name f l;
      if k > 1 then Printf.bprintf b " (%d razy)" k;
      Buffer.add_char b '\n'
    end) gs;
  let hidden = older + List.fold_left (fun acc (_, k) -> acc + k) 0 (List.filteri (fun i _ -> i >= max_frames) gs) in
  if hidden > 0 then Printf.bprintf b "  ... i jeszcze %d\n" hidden;
  Buffer.contents b
