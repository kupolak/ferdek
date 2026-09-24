(* Wbudowane funkcje: KANAPA - teksty *)

open Value
open Builtins_common

let register () = add [
  ["USIĄDŹ NA KANAPIE"; "USIADZ NA KANAPIE"], None, (fun env args ->
      let arg_values = List.map (eval_expr env) args in
      let strings = List.map to_string arg_values in
      VString (String.concat "" strings));

  (* ROZCIĄGNIJ KANAPĘ - Padduje string do określonej długości *)
  ["ROZCIĄGNIJ KANAPĘ"], Some 2, (fun env args ->
      (match args with
       | [str_arg; len_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let target_len = to_int (eval_expr env len_arg) in
           VString (Text_utils.kanapa_rozciagnij s target_len)
       | _ -> raise (RuntimeError (Errors.wrong_arg_count "ROZCIĄGNIJ KANAPĘ" 2 (List.length args)))));

  (* POTNIJ KANAPĘ - Substring (początek, koniec) *)
  ["POTNIJ KANAPĘ"], Some 3, (fun env args ->
      (match args with
       | [str_arg; start_arg; end_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let start = to_int (eval_expr env start_arg) in
           let end_pos = to_int (eval_expr env end_arg) in
           (try
             VString (Text_utils.kanapa_potnij s start end_pos)
           with Failure msg ->
             raise (RuntimeError msg))
       | _ -> raise (RuntimeError (Errors.wrong_arg_count "POTNIJ KANAPĘ" 3 (List.length args)))));

  (* PRZESUŃ NA KANAPIE - Split string *)
  ["PRZESUŃ NA KANAPIE"], Some 2, (fun env args ->
      (match args with
       | [str_arg; sep_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let sep = to_string (eval_expr env sep_arg) in
           let parts = Text_utils.kanapa_przesun s sep in
           VArray (Array.of_list (List.map (fun p -> VString p) parts))
       | _ -> raise (RuntimeError "PRZESUŃ NA KANAPIE oczekuje 2 argumentów")));

  (* POSKŁADAJ KANAPĘ - Join - łączy listę stringów *)
  ["POSKŁADAJ KANAPĘ"], Some 2, (fun env args ->
      (match args with
       | [arr_arg; sep_arg] ->
           let arr_val = eval_expr env arr_arg in
           let sep = to_string (eval_expr env sep_arg) in
           (match arr_val with
            | VArray arr ->
                let strings = Array.to_list (Array.map to_string arr) in
                VString (String.concat sep strings)
            | _ -> raise (RuntimeError "POSKŁADAJ KANAPĘ: pierwszy argument musi być tablicą"))
       | _ -> raise (RuntimeError "POSKŁADAJ KANAPĘ oczekuje 2 argumentów")));

  (* WYTRZEP KANAPĘ - Usuwa białe znaki z początku i końca (trim) *)
  ["WYTRZEP KANAPĘ"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           let s = to_string (eval_expr env arg) in
           VString (String.trim s)
       | _ -> raise (RuntimeError "WYTRZEP KANAPĘ oczekuje 1 argumentu")));

  (* ZAMIEŃ NA KANAPIE - Replace *)
  ["ZAMIEŃ NA KANAPIE"], Some 3, (fun env args ->
      (match args with
       | [str_arg; old_arg; new_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let old_str = to_string (eval_expr env old_arg) in
           let new_str = to_string (eval_expr env new_arg) in
           VString (Text_utils.kanapa_zamien s old_str new_str)
       | _ -> raise (RuntimeError "ZAMIEŃ NA KANAPIE oczekuje 3 argumentów")));

  (* ZNAK Z KANAPY(s, i) - znak (bajt) na pozycji i, jak w POTNIJ KANAPĘ *)
  ["ZNAK Z KANAPY"], Some 2, (fun env args ->
      (match args with
       | [str_arg; idx_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let i = to_int (eval_expr env idx_arg) in
           let chars = Text_utils.utf8_chars s in
           if i < 0 || i >= Array.length chars then raise (RuntimeError "ZNAK Z KANAPY: indeks poza zakresem");
           VString chars.(i)
       | _ -> raise (RuntimeError "ZNAK Z KANAPY oczekuje 2 argumentów")));

  ["KANAPA DO GÓRY"], Some 1, (fun env args ->
      (match args with
       | [arg] -> VString (Text_utils.kanapa_do_gory (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "KANAPA DO GÓRY oczekuje 1 argumentu")));

  ["KANAPA W DÓŁ"], Some 1, (fun env args ->
      (match args with
       | [arg] -> VString (Text_utils.kanapa_w_dol (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "KANAPA W DÓŁ oczekuje 1 argumentu")));

  (* ILE MIEJSCA NA KANAPIE - Zwraca długość stringu *)
  ["ILE MIEJSCA NA KANAPIE"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           VInt (Text_utils.utf8_length (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "ILE MIEJSCA NA KANAPIE oczekuje 1 argumentu")));

  ["POWTÓRZ NA KANAPIE"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [t; n] ->
          let n = to_int n in
          if n < 0 then raise (RuntimeError "POWTÓRZ NA KANAPIE: ujemna liczba powtórzeń");
          let t = to_string t in
          if String.length t * n > 100_000_000 then raise (RuntimeError "POWTÓRZ NA KANAPIE: za długi tekst");
          VString (String.concat "" (List.init n (fun _ -> t)))
      | _ -> VNull);

  ["CZY SIEDZI NA KANAPIE"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [t; f] -> VBool (Text_utils.kanapa_gdzie (to_string t) (to_string f) >= 0)
      | _ -> VNull);

  ["GDZIE SIEDZI NA KANAPIE"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [t; f] -> VInt (Text_utils.kanapa_gdzie (to_string t) (to_string f))
      | _ -> VNull);

  ["ZACZYNA SIĘ OD"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [t; p] -> VBool (String.starts_with ~prefix:(to_string p) (to_string t))
      | _ -> VNull);

  ["KOŃCZY SIĘ NA"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [t; k] -> VBool (String.ends_with ~suffix:(to_string k) (to_string t))
      | _ -> VNull);

  ["ODWRÓĆ KANAPĘ"], Some 1, (fun env args ->
      match List.map (eval_expr env) args with
      | [t] ->
          let c = Text_utils.utf8_chars (to_string t) in
          VString (String.concat "" (List.rev (Array.to_list c)))
      | _ -> VNull);

  ["ROZCIĄGNIJ Z LEWEJ"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [t; n] ->
          let t = to_string t and n = to_int n in
          let len = Text_utils.utf8_length t in
          VString (if len >= n then t else String.make (n - len) ' ' ^ t)
      | _ -> VNull);
  ]
