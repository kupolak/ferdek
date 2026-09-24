(* JSON: ZAPAKUJ DO SŁOIKA (wartość -> tekst) i WYJMIJ ZE SŁOIKA (tekst -> wartość).
   Te same zasady co json_* w runtime C: zapis zwarty, klucze posortowane, liczby z przecinkiem
   jak przy wypisywaniu (%.15g); przy wczytywaniu całkowite w zakresie int, reszta z przecinkiem. *)

open Value

let pack v =
  let b = Buffer.create 64 in
  let str s =
    Buffer.add_char b '"';
    String.iter (fun c -> match c with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\r' -> Buffer.add_string b "\\r"
      | '\t' -> Buffer.add_string b "\\t"
      | '\b' -> Buffer.add_string b "\\b"
      | '\012' -> Buffer.add_string b "\\f"
      | c when Char.code c < 0x20 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
      | c -> Buffer.add_char b c) s;
    Buffer.add_char b '"' in
  let fail what = raise (RuntimeError ("ZAPAKUJ DO SŁOIKA: tego nie zapakujesz: " ^ what)) in
  let rec go = function
    | VNull -> Buffer.add_string b "null"
    | VBool x -> Buffer.add_string b (if x then "true" else "false")
    | VInt n | VByte n | VShort n | VFixed n -> Buffer.add_string b (string_of_int n)
    | VFloat f ->
        if Float.is_nan f || Float.abs f = Float.infinity then fail "liczba bez końca (nan/inf)";
        Buffer.add_string b (string_of_float_ferdek f)
    | VString s -> str s
    | VArray a ->
        Buffer.add_char b '[';
        Array.iteri (fun i x -> if i > 0 then Buffer.add_char b ','; go x) a;
        Buffer.add_char b ']'
    | VHashMap t ->
        Buffer.add_char b '{';
        List.iteri (fun i k ->
          if i > 0 then Buffer.add_char b ',';
          str k; Buffer.add_char b ':'; go (Hashtbl.find t k)) (Map_utils.szafka_wszystkie_szufladki t);
        Buffer.add_char b '}'
    | v -> fail (value_kind v) in
  go v;
  Buffer.contents b

let unpack s =
  let n = String.length s in
  let pos = ref 0 in
  let fail () = raise (RuntimeError (Printf.sprintf "WYJMIJ ZE SŁOIKA: zły JSON (znak %d)" (!pos + 1))) in
  let peek () = if !pos < n then s.[!pos] else '\000' in
  let rec ws () = if !pos < n && (match s.[!pos] with ' ' | '\t' | '\n' | '\r' -> true | _ -> false) then (incr pos; ws ()) in
  let expect c = if peek () = c && !pos < n then incr pos else fail () in
  let word w v = if !pos + String.length w <= n && String.sub s !pos (String.length w) = w
                 then (pos := !pos + String.length w; v) else fail () in
  let hex4 () =
    if !pos + 4 > n then fail ();
    let h = String.sub s !pos 4 in
    if not (String.for_all (fun c -> match c with '0'..'9' | 'a'..'f' | 'A'..'F' -> true | _ -> false) h) then fail ();
    pos := !pos + 4; int_of_string ("0x" ^ h) in
  let utf8 b cp =
    if cp < 0x80 then Buffer.add_char b (Char.chr cp)
    else if cp < 0x800 then (Buffer.add_char b (Char.chr (0xC0 lor (cp lsr 6)));
                             Buffer.add_char b (Char.chr (0x80 lor (cp land 0x3F))))
    else if cp < 0x10000 then (Buffer.add_char b (Char.chr (0xE0 lor (cp lsr 12)));
                               Buffer.add_char b (Char.chr (0x80 lor ((cp lsr 6) land 0x3F)));
                               Buffer.add_char b (Char.chr (0x80 lor (cp land 0x3F))))
    else (Buffer.add_char b (Char.chr (0xF0 lor (cp lsr 18)));
          Buffer.add_char b (Char.chr (0x80 lor ((cp lsr 12) land 0x3F)));
          Buffer.add_char b (Char.chr (0x80 lor ((cp lsr 6) land 0x3F)));
          Buffer.add_char b (Char.chr (0x80 lor (cp land 0x3F)))) in
  let string () =
    expect '"';
    let b = Buffer.create 16 in
    let rec go () =
      if !pos >= n then fail ();
      let c = s.[!pos] in
      incr pos;
      match c with
      | '"' -> ()
      | '\\' ->
          if !pos >= n then fail ();
          let e = s.[!pos] in
          incr pos;
          (match e with
           | '"' -> Buffer.add_char b '"' | '\\' -> Buffer.add_char b '\\' | '/' -> Buffer.add_char b '/'
           | 'b' -> Buffer.add_char b '\b' | 'f' -> Buffer.add_char b '\012' | 'n' -> Buffer.add_char b '\n'
           | 'r' -> Buffer.add_char b '\r' | 't' -> Buffer.add_char b '\t'
           | 'u' ->
               let cp = hex4 () in
               if cp >= 0xD800 && cp <= 0xDBFF then begin
                 (* para zastępcza: 😀 *)
                 if not (!pos + 2 <= n && s.[!pos] = '\\' && s.[!pos + 1] = 'u') then fail ();
                 pos := !pos + 2;
                 let lo = hex4 () in
                 if lo < 0xDC00 || lo > 0xDFFF then fail ();
                 utf8 b (0x10000 + ((cp - 0xD800) lsl 10) + (lo - 0xDC00))
               end else if cp >= 0xDC00 && cp <= 0xDFFF then fail ()
               else utf8 b cp
           | _ -> (decr pos; fail ()));
          go ()
      | c when Char.code c < 0x20 -> decr pos; fail ()
      | c -> Buffer.add_char b c; go () in
    go ();
    Buffer.contents b in
  let number () =
    let start = !pos in
    let digits () = let d = !pos in while !pos < n && s.[!pos] >= '0' && s.[!pos] <= '9' do incr pos done;
                    if !pos = d then fail () in
    if peek () = '-' then incr pos;
    if peek () = '0' then incr pos else digits ();
    let frac = ref false in
    if peek () = '.' then (incr pos; digits (); frac := true);
    if peek () = 'e' || peek () = 'E' then begin
      incr pos; if peek () = '+' || peek () = '-' then incr pos; digits (); frac := true
    end;
    let text = String.sub s start (!pos - start) in
    match (if !frac then None else int_of_string_opt text) with
    | Some i -> VInt i
    | None -> VFloat (float_of_string text) in
  let rec value () =
    ws ();
    let v = match peek () with
      | '{' ->
          incr pos; ws ();
          let t = Hashtbl.create 8 in
          if peek () = '}' then incr pos
          else begin
            let rec members () =
              ws ();
              let k = string () in
              ws (); expect ':';
              Hashtbl.replace t k (value ());
              ws ();
              if peek () = ',' then (incr pos; members ()) else expect '}' in
            members ()
          end;
          VHashMap t
      | '[' ->
          incr pos; ws ();
          let items = ref [] in
          if peek () = ']' then incr pos
          else begin
            let rec elements () =
              items := value () :: !items;
              ws ();
              if peek () = ',' then (incr pos; elements ()) else expect ']' in
            elements ()
          end;
          VArray (Array.of_list (List.rev !items))
      | '"' -> VString (string ())
      | 't' -> word "true" (VBool true)
      | 'f' -> word "false" (VBool false)
      | 'n' -> word "null" VNull
      | '-' | '0'..'9' -> number ()
      | _ -> fail () in
    ws ();
    v in
  let v = value () in
  if !pos < n then fail ();
  v
