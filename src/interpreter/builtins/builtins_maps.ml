(* Wbudowane funkcje: SZAFKA - mapy *)

open Value
open Builtins_common

let register () = add [
  (* OTWÓRZ SZAFKĘ(klucz1, wartość1, ...) - nowa mapa, opcjonalnie od razu z parami *)
  ["OTWÓRZ SZAFKĘ"], None, (fun env args ->
      if List.length args mod 2 <> 0 then
        raise (RuntimeError "OTWÓRZ SZAFKĘ: potrzebne pary klucz, wartość (parzysta liczba argumentów)");
      let tbl = Hashtbl.create 16 in
      let rec fill = function
        | k :: v :: rest ->
            let key = to_string (eval_expr env k) in
            Hashtbl.replace tbl key (eval_expr env v); fill rest
        | _ -> () in
      fill args;
      VHashMap tbl);

  (* WŁÓŻ DO SZAFKI(dict, key, value) - adds key-value pair *)
  ["WŁÓŻ DO SZAFKI"], Some 3, (fun env args ->
      (match args with
       | [dict_arg; key_arg; value_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           let value = eval_expr env value_arg in
           (match dict_val with
            | VHashMap tbl ->
                Hashtbl.replace tbl key value;
                VNull
            | _ -> raise (RuntimeError "WŁÓŻ DO SZAFKI: pierwszy argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "WŁÓŻ DO SZAFKI oczekuje 3 argumentów")));

  (* WYJMIJ Z SZAFKI(dict, key) - gets value by key *)
  ["WYJMIJ Z SZAFKI"], Some 2, (fun env args ->
      (match args with
       | [dict_arg; key_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           (match dict_val with
            | VHashMap tbl ->
                (match Hashtbl.find_opt tbl key with
                 | Some v -> v
                 | None -> VNull)
            | _ -> raise (RuntimeError "WYJMIJ Z SZAFKI: pierwszy argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "WYJMIJ Z SZAFKI oczekuje 2 argumentów")));

  (* WYRZUĆ ZE SZAFKI(dict, key) - removes key-value pair *)
  ["WYRZUĆ ZE SZAFKI"], Some 2, (fun env args ->
      (match args with
       | [dict_arg; key_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           (match dict_val with
            | VHashMap tbl ->
                Hashtbl.remove tbl key;
                VNull
            | _ -> raise (RuntimeError "WYRZUĆ ZE SZAFKI: pierwszy argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "WYRZUĆ ZE SZAFKI oczekuje 2 argumentów")));

  (* CZY W SZAFCE(dict, key) - checks if key exists *)
  ["CZY W SZAFCE"], Some 2, (fun env args ->
      (match args with
       | [dict_arg; key_arg] ->
           let dict_val = eval_expr env dict_arg in
           let key = to_string (eval_expr env key_arg) in
           (match dict_val with
            | VHashMap tbl ->
                VBool (Map_utils.szafka_czy_w_szafce tbl key)
            | _ -> raise (RuntimeError "CZY W SZAFCE: pierwszy argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "CZY W SZAFCE oczekuje 2 argumentów")));

  (* WSZYSTKIE SZUFLADKI(dict) - returns list of all keys *)
  ["WSZYSTKIE SZUFLADKI"], Some 1, (fun env args ->
      (match args with
       | [dict_arg] ->
           let dict_val = eval_expr env dict_arg in
           (match dict_val with
            | VHashMap tbl ->
                let keys = Map_utils.szafka_wszystkie_szufladki tbl in
                VArray (Array.of_list (List.map (fun k -> VString k) keys))
            (* tablica i tekst: numery pozycji - dla pętli KRĘCI CEMENT BETONIARA k, w Z kolekcja *)
            | VArray a -> VArray (Array.init (Array.length a) (fun i -> VInt i))
            | VString s -> VArray (Array.init (Text_utils.utf8_length s) (fun i -> VInt i))
            | _ -> raise (RuntimeError "WSZYSTKIE SZUFLADKI: argument musi być szafką (mapą), tablicą albo tekstem"))
       | _ -> raise (RuntimeError "WSZYSTKIE SZUFLADKI oczekuje 1 argumentu")));

  (* ILE W SZAFCE(dict) - returns number of elements *)
  ["ILE W SZAFCE"], Some 1, (fun env args ->
      (match args with
       | [dict_arg] ->
           let dict_val = eval_expr env dict_arg in
           (match dict_val with
            | VHashMap tbl ->
                VInt (Map_utils.szafka_ile_w_szafce tbl)
            | _ -> raise (RuntimeError "ILE W SZAFCE: argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "ILE W SZAFCE oczekuje 1 argumentu")));

  ["WSZYSTKIE RZECZY"], Some 1, (fun env args ->
      match List.map (eval_expr env) args with
      | [VHashMap tbl] ->
          VArray (Array.of_list (List.map (Hashtbl.find tbl) (Map_utils.szafka_wszystkie_szufladki tbl)))
      | _ -> raise (RuntimeError "WSZYSTKIE RZECZY: argument musi być szafką (mapą)"));

  ["DOŁÓŻ SZAFKĘ"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [VHashMap a; VHashMap b] ->
          let out = Hashtbl.copy a in
          Hashtbl.iter (Hashtbl.replace out) b;
          VHashMap out
      | _ -> raise (RuntimeError "DOŁÓŻ SZAFKĘ: oba argumenty muszą być szafkami (mapami)"));
  ]
