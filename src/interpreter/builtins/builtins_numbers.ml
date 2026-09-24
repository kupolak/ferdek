(* Wbudowane funkcje: liczby - typy liczbowe, losowanie, matematyka *)

open Value
open Eval
open Builtins_common

let register () = add [
  (* ZRÓB BAJCIK(expr) - Cast to byte (0-255) *)
  ["ZRÓB BAJCIK"; "ZROB BAJCIK"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           VByte (value land 0xFF)  (* Mask to 0-255 *)
       | _ -> raise (RuntimeError "ZRÓB BAJCIK oczekuje 1 argumentu")));

  (* ZRÓB KRÓTKI(expr) - Cast to short (16-bit) *)
  ["ZRÓB KRÓTKI"; "ZROB KROTKI"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           (* Sign-extend from 16-bit *)
           let masked = value land 0xFFFF in
           let short_val = if masked > 0x7FFF then masked - 0x10000 else masked in
           VShort short_val
       | _ -> raise (RuntimeError "ZRÓB KRÓTKI oczekuje 1 argumentu")));

  (* ZRÓB DŁUGI(expr) - Cast to int (32-bit, default) *)
  ["ZRÓB DŁUGI"; "ZROB DLUGI"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           (* Jawne obcięcie liczby z przecinkiem *)
           (match eval_expr env arg with
            | VFloat f -> VInt (float_to_int "ZRÓB DŁUGI" f)
            | v -> VInt (to_int v))
       | _ -> raise (RuntimeError "ZRÓB DŁUGI oczekuje 1 argumentu")));

  (* ZRÓB UŁAMEK(expr) - Cast to fixed-point (same as ZAMIEŃ NA FIXED) *)
  ["ZRÓB UŁAMEK"; "ZROB ULAMEK"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let value = to_int (eval_expr env arg) in
           VFixed (value lsl 16)  (* Convert to 16.16 fixed-point *)
       | _ -> raise (RuntimeError "ZRÓB UŁAMEK oczekuje 1 argumentu"))

  (* CO TO ZA TYP(var) - Return type name *)
  (* KARTA LUBI DYM(min, max) - losowa liczba; KARTA LUBI DYM(ziarno) - ustawia ziarno.
     Własny LCG zamiast Random: ten sam ciąg co w skompilowanym C *));

  ["KARTA LUBI DYM"], None, (fun env args ->
      (match List.map (eval_expr env) args with
       | [seed] -> rng_state := to_int seed land 0x7FFFFFFF; VNull
       | [lo; hi] ->
           let lo = to_int lo and hi = to_int hi in
           if lo > hi then raise (RuntimeError "KARTA LUBI DYM: min większe niż max");
           VInt (lo + rng_next () mod (hi - lo + 1))
       | _ -> raise (RuntimeError "KARTA LUBI DYM oczekuje 1 argumentu (ziarno) albo 2 (min, max)")));

  ["CO TO ZA TYP"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let value = eval_expr env arg in
           let type_name = match value with
             | VByte _ -> "BAJCIK"
             | VShort _ -> "KRÓTKI"
             | VInt _ -> "DŁUGI"
             | VFixed _ -> "UŁAMEK"
             | VFloat _ -> "PRZECINEK"
             | VString _ -> "TEKST"
             | VBool _ -> "PRAWDA/FAŁSZ"
             | VNull -> "NIC"
             | VArray _ -> "TABLICA"
             | VHashMap _ -> "SZAFKA"
             | VFunction _ -> "FUNKCJA"
             | VClass _ -> "KLASA"
             | VStruct _ -> "MEBEL"
             | VUnion _ -> "UNIA"
             | VEnum _ -> "LISTA"
             | VObject _ -> "OBIEKT"
             | VPointer _ -> "WSKAŹNIK"
             | VFileHandle _ -> "KIBEL"
           in
           VString type_name
       | _ -> raise (RuntimeError "CO TO ZA TYP oczekuje 1 argumentu")));

  (* SKRZYNKA: pierwiastek, sinus, cosinus (w radianach) - wynik z przecinkiem *)
  ["PIERWIASTEK ZE SKRZYNKI"], Some 1, (fun env args ->
      let x = to_float (eval_expr env (List.hd args)) in
      if x < 0.0 then raise (RuntimeError "PIERWIASTEK ZE SKRZYNKI: pierwiastek z liczby ujemnej");
      VFloat (sqrt x));

  ["SINUS ZE SKRZYNKI"], Some 1, (fun env args -> VFloat (sin (to_float (eval_expr env (List.hd args)))));

  ["COSINUS ZE SKRZYNKI"], Some 1, (fun env args -> VFloat (cos (to_float (eval_expr env (List.hd args)))));

  (* PO PIERWSZE PRIMO(x, miejsca) - liczba jako tekst z ustaloną liczbą miejsc po przecinku *)
  ["PO PIERWSZE PRIMO"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [x; places] ->
          let n = to_int places in
          if n < 0 || n > 30 then raise (RuntimeError "PO PIERWSZE PRIMO: liczba miejsc musi być od 0 do 30");
          VString (Printf.sprintf "%.*f" n (to_float x))
      | _ -> VNull);
  ]
