(* Wzorce w tekstach (CZY KANAPA PASUJE, ZNAJDŹ NA KANAPIE, ...). Mały, przewidywalny podzbiór
   wyrażeń regularnych, liczony na znakach (ż to jeden znak), taki sam jak w runtime C (pattern.c):
     .  dowolny znak          [abc] [a-z] [^...]  klasa znaków
     \d cyfra  \w litera/cyfra/_ (też polskie litery)  \s odstęp  \D \W \S - zaprzeczenia
     * + ?  powtórzenia (zachłanne)      ^ na początku, $ na końcu wzoru - kotwice
     \x  znak x dosłownie (np. \. \* \[)
   Bez grup i alternatywy. Dopasowanie: najbardziej na lewo, zachłanne z nawrotami (jak Python re). *)

type item = Single of int | Range of int * int | Digit of bool | Word of bool | Space of bool

type atom = Any | Char of int | Class of bool * item list   (* bool: zaprzeczona [^...] *)

type quant = One | Star | Plus | Opt

type t = { nodes : (atom * quant) array; start_anchor : bool; end_anchor : bool }

exception Bad of string

(* Kod znaku UTF-8 zaczynającego się na bajcie i (ta sama długość co Text_utils.char_len);
   nieprawidłowy bajt - jego wartość *)
let code_at s i len =
  let b k = Char.code s.[i + k] in
  match len with
  | 2 -> ((b 0 land 0x1F) lsl 6) lor (b 1 land 0x3F)
  | 3 -> ((b 0 land 0x0F) lsl 12) lor ((b 1 land 0x3F) lsl 6) lor (b 2 land 0x3F)
  | 4 -> ((b 0 land 0x07) lsl 18) lor ((b 1 land 0x3F) lsl 12) lor ((b 2 land 0x3F) lsl 6) lor (b 3 land 0x3F)
  | _ -> b 0

(* Tekst jako tablica kodów znaków i pozycji bajtów (pozycja k = początek znaku k; ostatnia = długość) *)
let decode s =
  let n = String.length s in
  let codes = ref [] and offs = ref [] in
  let i = ref 0 in
  while !i < n do
    let len = Text_utils.char_len s !i in
    codes := code_at s !i len :: !codes;
    offs := !i :: !offs;
    i := !i + len
  done;
  Array.of_list (List.rev !codes), Array.of_list (List.rev (n :: !offs))

let is_digit c = c >= 48 && c <= 57
let is_word c = is_digit c || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c = 95 || c >= 128
let is_space c = c = 32 || c = 9 || c = 10 || c = 13

let item_matches c = function
  | Single x -> c = x
  | Range (lo, hi) -> c >= lo && c <= hi
  | Digit neg -> is_digit c <> neg
  | Word neg -> is_word c <> neg
  | Space neg -> is_space c <> neg

let atom_matches c = function
  | Any -> true
  | Char x -> c = x
  | Class (neg, items) -> List.exists (item_matches c) items <> neg

let compile pat =
  let p, _ = decode pat in
  let n = Array.length p in
  let escape c = match Char.unsafe_chr (if c < 256 then c else 0) with
    | 'd' -> Some (Digit false) | 'D' -> Some (Digit true)
    | 'w' -> Some (Word false) | 'W' -> Some (Word true)
    | 's' -> Some (Space false) | 'S' -> Some (Space true)
    | _ -> None in
  let start_anchor = n > 0 && p.(0) = Char.code '^' in
  let end_anchor = n > (if start_anchor then 1 else 0) && p.(n - 1) = Char.code '$'
                   && not (n >= 2 && p.(n - 2) = Char.code '\\') in
  let last = if end_anchor then n - 1 else n in
  let nodes = ref [] in
  let i = ref (if start_anchor then 1 else 0) in
  while !i < last do
    let c = p.(!i) in
    let atom =
      if c = Char.code '.' then (incr i; Any)
      else if c = Char.code '\\' then begin
        if !i + 1 >= last then raise (Bad "\\ na końcu wzoru");
        let e = p.(!i + 1) in
        i := !i + 2;
        match escape e with Some it -> Class (false, [it]) | None -> Char e
      end
      else if c = Char.code '[' then begin
        incr i;
        let neg = !i < last && p.(!i) = Char.code '^' in
        if neg then incr i;
        let items = ref [] and first = ref true in
        while !i < last && (p.(!i) <> Char.code ']' || !first) do
          first := false;
          let lo, esc =
            if p.(!i) = Char.code '\\' then begin
              if !i + 1 >= last then raise (Bad "niezamknięty [");
              let e = p.(!i + 1) in i := !i + 2;
              match escape e with Some it -> (-1, Some it) | None -> (e, None)
            end else (let x = p.(!i) in incr i; (x, None)) in
          match esc with
          | Some it -> items := it :: !items
          | None ->
              if !i + 1 < last && p.(!i) = Char.code '-' && p.(!i + 1) <> Char.code ']' then begin
                incr i;   (* za "-" *)
                let hi =
                  if p.(!i) = Char.code '\\' && !i + 1 < last then (i := !i + 2; p.(!i - 1))
                  else (incr i; p.(!i - 1)) in
                if hi < lo then raise (Bad "zły zakres w [ ]");
                items := Range (lo, hi) :: !items
              end else items := Single lo :: !items
        done;
        if !i >= last then raise (Bad "niezamknięty [");
        incr i;
        Class (neg, List.rev !items)
      end
      else if c = Char.code '*' || c = Char.code '+' || c = Char.code '?' then
        raise (Bad "* + ? bez niczego przed")
      else (incr i; Char c) in
    let quant =
      if !i < last && p.(!i) = Char.code '*' then (incr i; Star)
      else if !i < last && p.(!i) = Char.code '+' then (incr i; Plus)
      else if !i < last && p.(!i) = Char.code '?' then (incr i; Opt)
      else One in
    nodes := (atom, quant) :: !nodes
  done;
  { nodes = Array.of_list (List.rev !nodes); start_anchor; end_anchor }

(* Koniec dopasowania zaczętego na znaku start albo None *)
let match_at re codes start =
  let len = Array.length codes and nn = Array.length re.nodes in
  let rec go ni ti =
    if ni = nn then (if re.end_anchor && ti <> len then None else Some ti)
    else
      let atom, q = re.nodes.(ni) in
      let ok k = k < len && atom_matches codes.(k) atom in
      match q with
      | One -> if ok ti then go (ni + 1) (ti + 1) else None
      | Opt -> (match (if ok ti then go (ni + 1) (ti + 1) else None) with
                | Some e -> Some e
                | None -> go (ni + 1) ti)
      | Star | Plus ->
          let m = ref ti in
          while ok !m do incr m done;
          let min = if q = Plus then ti + 1 else ti in
          let rec back k = if k < min then None else match go (ni + 1) k with
            | Some e -> Some e
            | None -> back (k - 1) in
          back !m in
  go 0 start

(* Pierwsze dopasowanie od znaku from: (początek, koniec) w znakach *)
let search re codes from =
  let len = Array.length codes in
  let rec go s =
    if s > len || (re.start_anchor && s > 0) then None
    else match match_at re codes s with
      | Some e -> Some (s, e)
      | None -> go (s + 1) in
  go from

(* Wszystkie dopasowania bez nakładania; po pustym przesuwamy się o jeden znak *)
let all re codes =
  let len = Array.length codes in
  let rec go from acc =
    if from > len then List.rev acc
    else match search re codes from with
      | None -> List.rev acc
      | Some (s, e) -> go (if e = s then s + 1 else e) ((s, e) :: acc) in
  go 0 []

let slice s offs a b = String.sub s offs.(a) (offs.(b) - offs.(a))

let compile_for what pat =
  try compile pat with Bad msg -> raise (Value.RuntimeError (Printf.sprintf "%s: zły wzór - %s" what msg))

let matches what text pat = let codes, _ = decode text in search (compile_for what pat) codes 0 <> None

let find what text pat =
  let codes, offs = decode text in
  Option.map (fun (a, b) -> slice text offs a b) (search (compile_for what pat) codes 0)

let find_all what text pat =
  let codes, offs = decode text in
  List.map (fun (a, b) -> slice text offs a b) (all (compile_for what pat) codes)

let replace what text pat by =
  let codes, offs = decode text in
  let buf = Buffer.create (String.length text) in
  let pos = List.fold_left (fun pos (a, b) ->
    Buffer.add_string buf (slice text offs pos a);
    Buffer.add_string buf by;
    if a = b then begin
      (* puste dopasowanie: znak za nim przepisujemy i idziemy dalej *)
      if a < Array.length codes then Buffer.add_string buf (slice text offs a (a + 1));
      a + 1
    end else b) 0 (all (compile_for what pat) codes) in
  if pos < Array.length codes then Buffer.add_string buf (slice text offs pos (Array.length codes));
  Buffer.contents buf
