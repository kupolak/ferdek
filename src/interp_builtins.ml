(* Wbudowane funkcje interpretera - rejestruje je Interpreter przy starcie *)

open Ast
open Value
open Eval

(* ============ BUILTINS ============ *)

(* Funkcja przekazana builtinowi (np. do sortowania) jako OCamlowa funkcja na wartościach *)
let function_arg builtin = function
  | VFunction (fdecl, closure_env) -> apply_function fdecl.name fdecl closure_env
  | _ -> raise (RuntimeError (builtin ^ ": drugi argument musi być funkcją"))

(* Wbudowane funkcje: nazwy (z wariantami), liczba argumentów (None = dowolna), implementacja.
   Liczbę argumentów sprawdza eval_function_call; z tej tabeli czyta też ferdek --check. *)
let register () =
  List.iter (fun (names, arity, impl) ->
    List.iter (fun n -> Hashtbl.replace builtins n (arity, impl)) names) [

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
           VString (Builtins_string.kanapa_rozciagnij s target_len)
       | _ -> raise (RuntimeError (Errors.wrong_arg_count "ROZCIĄGNIJ KANAPĘ" 2 (List.length args)))));

  (* POTNIJ KANAPĘ - Substring (początek, koniec) *)
  ["POTNIJ KANAPĘ"], Some 3, (fun env args ->
      (match args with
       | [str_arg; start_arg; end_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let start = to_int (eval_expr env start_arg) in
           let end_pos = to_int (eval_expr env end_arg) in
           (try
             VString (Builtins_string.kanapa_potnij s start end_pos)
           with Failure msg ->
             raise (RuntimeError msg))
       | _ -> raise (RuntimeError (Errors.wrong_arg_count "POTNIJ KANAPĘ" 3 (List.length args)))));

  (* PRZESUŃ NA KANAPIE - Split string *)
  ["PRZESUŃ NA KANAPIE"], Some 2, (fun env args ->
      (match args with
       | [str_arg; sep_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let sep = to_string (eval_expr env sep_arg) in
           let parts = Builtins_string.kanapa_przesun s sep in
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
           VString (Builtins_string.kanapa_zamien s old_str new_str)
       | _ -> raise (RuntimeError "ZAMIEŃ NA KANAPIE oczekuje 3 argumentów")));

  (* ZNAK Z KANAPY(s, i) - znak (bajt) na pozycji i, jak w POTNIJ KANAPĘ *)
  ["ZNAK Z KANAPY"], Some 2, (fun env args ->
      (match args with
       | [str_arg; idx_arg] ->
           let s = to_string (eval_expr env str_arg) in
           let i = to_int (eval_expr env idx_arg) in
           let chars = Builtins_string.utf8_chars s in
           if i < 0 || i >= Array.length chars then raise (RuntimeError "ZNAK Z KANAPY: indeks poza zakresem");
           VString chars.(i)
       | _ -> raise (RuntimeError "ZNAK Z KANAPY oczekuje 2 argumentów")));

  ["KANAPA DO GÓRY"], Some 1, (fun env args ->
      (match args with
       | [arg] -> VString (Builtins_string.kanapa_do_gory (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "KANAPA DO GÓRY oczekuje 1 argumentu")));

  ["KANAPA W DÓŁ"], Some 1, (fun env args ->
      (match args with
       | [arg] -> VString (Builtins_string.kanapa_w_dol (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "KANAPA W DÓŁ oczekuje 1 argumentu")));

  (* ILE MIEJSCA NA KANAPIE - Zwraca długość stringu *)
  ["ILE MIEJSCA NA KANAPIE"], Some 1, (fun env args ->
      (match args with
       | [arg] ->
           VInt (Builtins_string.utf8_length (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "ILE MIEJSCA NA KANAPIE oczekuje 1 argumentu")));

  (* OTWÓRZ KIBEL(ścieżka) - otwiera plik do odczytu *)
  ["OTWÓRZ KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           (try
             let channel = open_in path in
             VFileHandle (InputHandle channel)
           with Sys_error msg ->
             raise (RuntimeError (Printf.sprintf "OTWÓRZ KIBEL: %s" msg)))
       | _ -> raise (RuntimeError "OTWÓRZ KIBEL oczekuje 1 argumentu")));

  (* ZAMKNIJ KIBEL(uchwyt) - zamyka plik *)
  ["ZAMKNIJ KIBEL"], Some 1, (fun env args ->
      (match args with
       | [handle_arg] ->
           let handle_val = eval_expr env handle_arg in
           (match handle_val with
            | VFileHandle (InputHandle ch) ->
                close_in ch;
                VNull
            | VFileHandle (OutputHandle ch) ->
                close_out ch;
                VNull
            | _ -> raise (RuntimeError "ZAMKNIJ_KIBEL: argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "ZAMKNIJ_KIBEL oczekuje 1 argumentu")));

  (* SPUŚĆ WODĘ(uchwyt, dane) - zapisuje do pliku *)
  ["SPUŚĆ WODĘ"], Some 2, (fun env args ->
      (match args with
       | [handle_arg; data_arg] ->
           let handle_val = eval_expr env handle_arg in
           let data = to_string (eval_expr env data_arg) in
           (match handle_val with
            | VFileHandle (OutputHandle ch) ->
                output_string ch data;
                flush ch;
                VNull
            | VFileHandle (InputHandle _) ->
                raise (RuntimeError "SPUŚĆ_WODĘ: nie można pisać do pliku otwartego do odczytu")
            | _ -> raise (RuntimeError "SPUŚĆ_WODĘ: pierwszy argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "SPUŚĆ_WODĘ oczekuje 2 argumentów")));

  (* WYPOMPUJ(uchwyt) - czyta cały plik *)
  ["WYPOMPUJ"], Some 1, (fun env args ->
      (match args with
       | [handle_arg] ->
           let handle_val = eval_expr env handle_arg in
           (match handle_val with
            | VFileHandle (InputHandle ch) ->
                let rec read_all acc =
                  try
                    let line = input_line ch in
                    read_all (line :: acc)
                  with End_of_file ->
                    List.rev acc
                in
                let lines = read_all [] in
                VArray (Array.of_list (List.map (fun s -> VString s) lines))
            | VFileHandle (OutputHandle _) ->
                raise (RuntimeError "WYPOMPUJ: nie można czytać z pliku otwartego do zapisu")
            | _ -> raise (RuntimeError "WYPOMPUJ: argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "WYPOMPUJ oczekuje 1 argumentu")));

  (* CZY KIBEL ZAJĘTY(ścieżka) - sprawdza czy plik istnieje *)
  ["CZY KIBEL ZAJĘTY"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Sys.file_exists path)
       | _ -> raise (RuntimeError "CZY_KIBEL_ZAJĘTY oczekuje 1 argumentu")));

  (* OTWÓRZ KIBEL DO ZAPISU(ścieżka) - otwiera plik do zapisu *)
  ["OTWÓRZ KIBEL DO ZAPISU"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           (try
             let channel = open_out path in
             VFileHandle (OutputHandle channel)
           with Sys_error msg ->
             raise (RuntimeError (Printf.sprintf "OTWÓRZ_KIBEL_DO_ZAPISU: %s" msg)))
       | _ -> raise (RuntimeError "OTWÓRZ_KIBEL_DO_ZAPISU oczekuje 1 argumentu")));

  (* SYSTEM(komenda) - wykonuje komendę systemową i zwraca output *)
  (* OPAKUJ W GAZETĘ(tekst) - bezpieczne cytowanie argumentu dla powłoki (do SYSTEM) *)
  ["OPAKUJ W GAZETĘ"], Some 1, (fun env args ->
      (match args with
       | [arg] -> VString (Filename.quote (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "OPAKUJ W GAZETĘ oczekuje 1 argumentu")));

  ["SYSTEM"], Some 1, (fun env args ->
      (match args with
       | [cmd_arg] ->
           let cmd = to_string (eval_expr env cmd_arg) in
           (try
             let ic = Unix.open_process_in cmd in
             let buf = Buffer.create 256 in
             (try
               while true do
                 Buffer.add_channel buf ic 1
               done;
               VString ""
             with End_of_file ->
               let _ = Unix.close_process_in ic in
               let output = Buffer.contents buf in
               VString output)
           with Unix.Unix_error (err, _, _) ->
             raise (RuntimeError (Printf.sprintf "SYSTEM: błąd: %s" (Unix.error_message err))))
       | _ -> raise (RuntimeError "SYSTEM oczekuje 1 argumentu")));

  (* ========== SZAFKA (HashMap/Dictionary) operations ========== *)
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
                VBool (Builtins_hashmap.szafka_czy_w_szafce tbl key)
            | _ -> raise (RuntimeError "CZY W SZAFCE: pierwszy argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "CZY W SZAFCE oczekuje 2 argumentów")));

  (* WSZYSTKIE SZUFLADKI(dict) - returns list of all keys *)
  ["WSZYSTKIE SZUFLADKI"], Some 1, (fun env args ->
      (match args with
       | [dict_arg] ->
           let dict_val = eval_expr env dict_arg in
           (match dict_val with
            | VHashMap tbl ->
                let keys = Builtins_hashmap.szafka_wszystkie_szufladki tbl in
                VArray (Array.of_list (List.map (fun k -> VString k) keys))
            | _ -> raise (RuntimeError "WSZYSTKIE SZUFLADKI: argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "WSZYSTKIE SZUFLADKI oczekuje 1 argumentu")));

  (* ILE W SZAFCE(dict) - returns number of elements *)
  ["ILE W SZAFCE"], Some 1, (fun env args ->
      (match args with
       | [dict_arg] ->
           let dict_val = eval_expr env dict_arg in
           (match dict_val with
            | VHashMap tbl ->
                VInt (Builtins_hashmap.szafka_ile_w_szafce tbl)
            | _ -> raise (RuntimeError "ILE W SZAFCE: argument musi być szafką (mapą)"))
       | _ -> raise (RuntimeError "ILE W SZAFCE oczekuje 1 argumentu")));

  (* ========== KIBEL (File operations) ========== *)
  (* ZRÓB KIBEL(path) - creates directory *)
  ["ZRÓB KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Builtins_file.kibel_zrob path)
       | _ -> raise (RuntimeError "ZRÓB KIBEL oczekuje 1 argumentu")));

  (* WYWAL KIBEL(path) - removes directory *)
  ["WYWAL KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Builtins_file.kibel_wywal path)
       | _ -> raise (RuntimeError "WYWAL KIBEL oczekuje 1 argumentu")));

  (* CO W KIBLU(path) - lists files in directory *)
  ["CO W KIBLU"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           let files = Builtins_file.kibel_co_w_kiblu path in
           VArray (Array.of_list (List.map (fun f -> VString f) files))
       | _ -> raise (RuntimeError "CO W KIBLU oczekuje 1 argumentu")));

  (* CZY TO KIBEL(path) - checks if path is directory *)
  ["CZY TO KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (Builtins_file.kibel_czy_to_kibel path)
       | _ -> raise (RuntimeError "CZY TO KIBEL oczekuje 1 argumentu")));

  (* PRZEKOPIUJ KIBEL(src, dest) - copies file *)
  ["PRZEKOPIUJ KIBEL"], Some 2, (fun env args ->
      (match args with
       | [src_arg; dest_arg] ->
           let src = to_string (eval_expr env src_arg) in
           let dest = to_string (eval_expr env dest_arg) in
           VBool (Builtins_file.kibel_przekopiuj src dest)
       | _ -> raise (RuntimeError "PRZEKOPIUJ KIBEL oczekuje 2 argumentów")));

  (* PRZENIEŚ KIBEL(src, dest) - moves/renames file *)
  ["PRZENIEŚ KIBEL"], Some 2, (fun env args ->
      (match args with
       | [src_arg; dest_arg] ->
           let src = to_string (eval_expr env src_arg) in
           let dest = to_string (eval_expr env dest_arg) in
           VBool (Builtins_file.kibel_przenies src dest)
       | _ -> raise (RuntimeError "PRZENIEŚ KIBEL oczekuje 2 argumentów")));

  (* WYKOP WSZYSTKIE KIBLE(path) - recursive delete *)
  ["WYKOP WSZYSTKIE KIBLE"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           Builtins_file.kibel_wykop_wszystkie path;
           VNull
       | _ -> raise (RuntimeError "WYKOP WSZYSTKIE KIBLE oczekuje 1 argumentu")));

  (* ========== WERSALKA (List/Array operations) ========== *)
  (* ILE NA WERSALCE(array) - returns array length *)
  ["ILE NA WERSALCE"], Some 1, (fun env args ->
      (match args with
       | [arr_arg] ->
           let arr_val = eval_expr env arr_arg in
           (match arr_val with
            | VArray arr -> VInt (Builtins_list.wersalka_ile_na arr)
            | _ -> raise (RuntimeError "ILE NA WERSALCE: argument musi być tablicą"))
       | _ -> raise (RuntimeError "ILE NA WERSALCE oczekuje 1 argumentu")));

  (* POŁÓŻ NA WERSALCE(array, element) - appends element to array *)
  ["POŁÓŻ NA WERSALCE"], Some 2, (fun env args ->
      (match args with
       | [arr_arg; elem_arg] ->
           let arr_val = eval_expr env arr_arg in
           let elem = eval_expr env elem_arg in
           (match arr_val with
            | VArray arr ->
                let new_arr = Builtins_list.wersalka_poloz_na arr elem in
                VArray new_arr
            | _ -> raise (RuntimeError "POŁÓŻ NA WERSALCE: pierwszy argument musi być tablicą"))
       | _ -> raise (RuntimeError "POŁÓŻ NA WERSALCE oczekuje 2 argumentów")));

  (* ZDEJMIJ Z WERSALKI(array) - pops last element *)
  ["ZDEJMIJ Z WERSALKI"], Some 1, (fun env args ->
      (match args with
       | [arr_arg] ->
           let arr_val = eval_expr env arr_arg in
           (match arr_val with
            | VArray arr ->
                (try
                  let (new_arr, popped) = Builtins_list.wersalka_zdejmij_z arr in
                  (* Return the popped element *)
                  popped
                with Failure msg ->
                  raise (RuntimeError msg))
            | _ -> raise (RuntimeError "ZDEJMIJ Z WERSALKI: argument musi być tablicą"))
       | _ -> raise (RuntimeError "ZDEJMIJ Z WERSALKI oczekuje 1 argumentu")));

  (* CZY LEŻY NA WERSALCE(array, element) - checks if element is in array *)
  ["CZY LEŻY NA WERSALCE"], Some 2, (fun env args ->
      (match args with
       | [arr_arg; elem_arg] ->
           let arr_val = eval_expr env arr_arg in
           let elem = eval_expr env elem_arg in
           (match arr_val with
            | VArray arr ->
                let equal_func a b =
                  match (a, b) with
                  | (VInt x, VInt y) -> x = y
                  | (VString x, VString y) -> x = y
                  | (VBool x, VBool y) -> x = y
                  | _ -> false
                in
                VBool (Builtins_list.wersalka_czy_lezy_na arr elem equal_func)
            | _ -> raise (RuntimeError "CZY LEŻY NA WERSALCE: pierwszy argument musi być tablicą"))
       | _ -> raise (RuntimeError "CZY LEŻY NA WERSALCE oczekuje 2 argumentów")));

  (* ============ TYPE CASTING FUNCTIONS ============ *)
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
            | VFloat f -> VInt (int_of_float f)
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
      let rng_next () =
        if !rng_state < 0 then rng_state := int_of_float (Unix.gettimeofday () *. 1000.) land 0x7FFFFFFF;
        rng_state := (!rng_state * 1103515245 + 12345) land 0x7FFFFFFF;
        !rng_state
      in
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

  (* ============ LOW-LEVEL I/O ============ *)
  (* OTWORZ(filename, mode) - open() - Open file *)
  ["OTWORZ"], Some 2, (fun env args ->
      (match args with
       | [filename_arg; mode_arg] ->
           let filename = match eval_expr env filename_arg with
             | VString s -> s
             | _ -> raise (RuntimeError "OTWORZ: nazwa pliku musi być tekstem")
           in
           let mode = match eval_expr env mode_arg with
             | VString s -> s
             | _ -> raise (RuntimeError "OTWORZ: tryb musi być tekstem")
           in
           (try
              let handle = match mode with
                | "r" | "rb" -> InputHandle (open_in_bin filename)
                | "w" | "wb" -> OutputHandle (open_out_bin filename)
                | "a" | "ab" -> OutputHandle (open_out_gen [Open_append; Open_binary; Open_creat] 0o666 filename)
                | _ -> raise (RuntimeError (Printf.sprintf "Nieprawidłowy tryb pliku: %s (dozwolone: 'r', 'w', 'a')" mode))
              in
              VFileHandle handle
            with Sys_error msg ->
              raise (RuntimeError (Printf.sprintf "Nie można otworzyć pliku '%s': %s" filename msg)))
       | _ -> raise (RuntimeError "OTWORZ oczekuje 2 argumentów (filename, mode)")));

  (* ZAMKNIJ(file_handle) - close() - Close file *)
  ["ZAMKNIJ"], Some 1, (fun env args ->
      (match args with
       | [handle_arg] ->
           let handle = eval_expr env handle_arg in
           (match handle with
            | VFileHandle (InputHandle ch) -> close_in ch; VNull
            | VFileHandle (OutputHandle ch) -> close_out ch; VNull
            | _ -> raise (RuntimeError "ZAMKNIJ: argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "ZAMKNIJ oczekuje 1 argumentu (file_handle)")));

  (* CZYTAJ(file_handle, [num_bytes]) - read() - Read bytes *)
  ["CZYTAJ"], None, (fun env args ->
      (match args with
       | [handle_arg; size_arg] ->
           let handle = eval_expr env handle_arg in
           let size = to_int (eval_expr env size_arg) in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                (try
                   let buffer = Bytes.create size in
                   let bytes_read = input ch buffer 0 size in
                   (* Return array of bytes *)
                   let byte_array = Array.init bytes_read (fun i -> VByte (Char.code (Bytes.get buffer i))) in
                   VArray byte_array
                 with End_of_file ->
                   VArray [||])  (* Return empty array on EOF *)
            | _ -> raise (RuntimeError "CZYTAJ GAZETĘ: pierwszy argument musi być uchwytem pliku do odczytu"))
       | [handle_arg] ->
           (* CZYTAJ BAJT - single argument means read single byte *)
           let handle = eval_expr env handle_arg in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                (try
                   let byte = input_byte ch in
                   VByte byte
                 with End_of_file ->
                   VInt (-1))  (* Return -1 on EOF like C *)
            | _ -> raise (RuntimeError "CZYTAJ: argument musi być uchwytem pliku do odczytu"))
       | _ -> raise (RuntimeError "CZYTAJ oczekuje 1 albo 2 argumentów")));

  (* PISZ(file_handle, data) - write() - Write bytes *)
  ["PISZ"], Some 2, (fun env args ->
      (match args with
       | [handle_arg; data_arg] ->
           let handle = eval_expr env handle_arg in
           let data = eval_expr env data_arg in
           (match handle with
            | VFileHandle (OutputHandle ch) ->
                (match data with
                 | VArray bytes ->
                     (* Write array of bytes *)
                     Array.iter (fun b ->
                       let byte_val = to_int b in
                       output_byte ch byte_val
                     ) bytes;
                     VInt (Array.length bytes)
                 | VString s ->
                     (* Write string as bytes *)
                     output_string ch s;
                     VInt (String.length s)
                 | VByte b | VInt b | VShort b ->
                     (* PISZ BAJT - single byte/int means write single byte *)
                     output_byte ch (b land 0xFF);
                     VInt 1
                 | _ -> raise (RuntimeError "PISZ: dane muszą być tablicą, tekstem albo bajtem"))
            | _ -> raise (RuntimeError "PISZ: pierwszy argument musi być uchwytem pliku do zapisu"))
       | _ -> raise (RuntimeError "PISZ oczekuje 2 argumentów (file_handle, data)"))

  (* SKOCZ(file_handle, offset, [mode]) - lseek() - Seek in file
     mode: 0 = absolute (default), 1 = relative forward, -1 = relative backward *));

  ["SKOCZ"], None, (fun env args ->
      (match args with
       | [handle_arg; offset_arg] ->
           (* Default: absolute seek *)
           let handle = eval_expr env handle_arg in
           let pos = to_int (eval_expr env offset_arg) in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                seek_in ch pos;
                VInt pos
            | VFileHandle (OutputHandle ch) ->
                seek_out ch pos;
                VInt pos
            | _ -> raise (RuntimeError "SKOCZ: pierwszy argument musi być uchwytem pliku"))
       | [handle_arg; offset_arg; mode_arg] ->
           (* With mode: 0 = absolute, 1 = forward, -1 = backward *)
           let handle = eval_expr env handle_arg in
           let offset = to_int (eval_expr env offset_arg) in
           let mode = to_int (eval_expr env mode_arg) in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                let new_pos = match mode with
                  | 0 -> offset  (* Absolute *)
                  | 1 -> pos_in ch + offset  (* Relative forward *)
                  | -1 -> max 0 (pos_in ch - offset)  (* Relative backward *)
                  | _ -> raise (RuntimeError "SKOCZ: tryb musi być 0 (od początku), 1 (do przodu) albo -1 (do tyłu)")
                in
                seek_in ch new_pos;
                VInt new_pos
            | VFileHandle (OutputHandle ch) ->
                let new_pos = match mode with
                  | 0 -> offset  (* Absolute *)
                  | 1 -> pos_out ch + offset  (* Relative forward *)
                  | -1 -> max 0 (pos_out ch - offset)  (* Relative backward *)
                  | _ -> raise (RuntimeError "SKOCZ: tryb musi być 0 (od początku), 1 (do przodu) albo -1 (do tyłu)")
                in
                seek_out ch new_pos;
                VInt new_pos
            | _ -> raise (RuntimeError "SKOCZ: pierwszy argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "SKOCZ oczekuje 2 albo 3 argumentów (file_handle, offset, [mode])")));

  (* POZYCJA(file_handle) - tell() - Get current file position *)
  ["POZYCJA"], Some 1, (fun env args ->
      (match args with
       | [handle_arg] ->
           let handle = eval_expr env handle_arg in
           (match handle with
            | VFileHandle (InputHandle ch) ->
                VInt (pos_in ch)
            | VFileHandle (OutputHandle ch) ->
                VInt (pos_out ch)
            | _ -> raise (RuntimeError "POZYCJA: argument musi być uchwytem pliku"))
       | _ -> raise (RuntimeError "POZYCJA oczekuje 1 argumentu (file_handle)")));

  (* ============ MULTIDIMENSIONAL ARRAYS ============ *)
  (* TABLICA 2D(rows, cols) - Create 2D array *)
  ["TABLICA 2D"], Some 2, (fun env args ->
      (match args with
       | [rows_arg; cols_arg] ->
           let rows = to_int (eval_expr env rows_arg) in
           let cols = to_int (eval_expr env cols_arg) in
           if rows <= 0 || cols <= 0 then
             raise (RuntimeError "TABLICA 2D: wymiary muszą być dodatnie")
           else
             (* Create array of arrays *)
             let inner_arrays = Array.init rows (fun _ -> VArray (Array.make cols (VInt 0))) in
             VArray inner_arrays
       | _ -> raise (RuntimeError "TABLICA 2D oczekuje 2 argumentów (rows, cols)")));

  (* TABLICA 3D(x, y, z) - Create 3D array *)
  ["TABLICA 3D"], Some 3, (fun env args ->
      (match args with
       | [x_arg; y_arg; z_arg] ->
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           let z = to_int (eval_expr env z_arg) in
           if x <= 0 || y <= 0 || z <= 0 then
             raise (RuntimeError "TABLICA 3D: wymiary muszą być dodatnie")
           else
             (* Create array of arrays of arrays *)
             let inner_arrays = Array.init x (fun _ ->
               VArray (Array.init y (fun _ ->
                 VArray (Array.make z (VInt 0))
               ))
             ) in
             VArray inner_arrays
       | _ -> raise (RuntimeError "TABLICA 3D oczekuje 3 argumentów (x, y, z)")));

  (* POLAŁA SIĘ KREW(format, ...) - Variadic error function like I_Error *)
  ["POLAŁA SIĘ KREW"; "POLALA SIE KREW"], None, (fun env args ->
      (match args with
       | [] -> raise (RuntimeError "POLAŁA SIĘ KREW: potrzeba co najmniej jednego argumentu")
       | format_arg :: rest_args ->
           let format = to_string (eval_expr env format_arg) in
           let arg_values = List.map (eval_expr env) rest_args in
           (* Simple printf-like formatting: replace %d, %s, %i with arguments *)
           let rec format_string fmt args_left acc =
             if String.length fmt = 0 then
               acc
             else if String.length fmt >= 2 && String.get fmt 0 = '%' then
               let spec = String.get fmt 1 in
               match spec, args_left with
               | 'd', v::rest | 'i', v::rest ->
                   let num = to_int v in
                   format_string (String.sub fmt 2 (String.length fmt - 2)) rest (acc ^ string_of_int num)
               | 's', v::rest ->
                   let str = to_string v in
                   format_string (String.sub fmt 2 (String.length fmt - 2)) rest (acc ^ str)
               | '%', _ ->
                   format_string (String.sub fmt 2 (String.length fmt - 2)) args_left (acc ^ "%")
               | _, [] ->
                   (* No more args, keep format specifier *)
                   format_string (String.sub fmt 1 (String.length fmt - 1)) [] (acc ^ String.make 1 (String.get fmt 0))
               | _, _ ->
                   (* Unknown specifier, keep it *)
                   format_string (String.sub fmt 2 (String.length fmt - 2)) args_left (acc ^ "%" ^ String.make 1 spec)
             else
               format_string (String.sub fmt 1 (String.length fmt - 1)) args_left (acc ^ String.make 1 (String.get fmt 0))
           in
           let message = format_string format arg_values "" in
           raise (RuntimeError (Printf.sprintf "I_Error: %s" message))));

  ["POSKŁADAJ WERSALKĘ"], None, (fun env args ->
      let arr, cmp = match List.map (eval_expr env) args with
        | [VArray a] -> a, (fun x y -> compare_values x y)
        | [VArray a; f] ->
            let f = function_arg "POSKŁADAJ WERSALKĘ" f in
            a, (fun x y -> let r = f [x; y] in compare (to_float r) 0.0)
        | [_] | [_; _] -> raise (RuntimeError "POSKŁADAJ WERSALKĘ: pierwszy argument musi być tablicą")
        | _ -> raise (RuntimeError "POSKŁADAJ WERSALKĘ oczekuje 1 albo 2 argumentów")
      in
      (* stable_sort = merge sort, jak w runtime C - przy remisach ta sama kolejność *)
      VArray (Array.of_list (List.stable_sort cmp (Array.to_list arr))));

  ["ODWRÓĆ WERSALKĘ"], Some 1, (fun env args ->
      match eval_expr env (List.hd args) with
      | VArray a -> VArray (Builtins_list.wersalka_odwroc a)
      | _ -> raise (RuntimeError "ODWRÓĆ WERSALKĘ: argument musi być tablicą"));

  ["PRZERABIAJ WERSALKĘ"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a; f] -> let f = function_arg "PRZERABIAJ WERSALKĘ" f in VArray (Array.map (fun x -> f [x]) a)
      | _ -> raise (RuntimeError "PRZERABIAJ WERSALKĘ: pierwszy argument musi być tablicą"));

  ["PRZEFILTRUJ WERSALKĘ"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a; f] ->
          let f = function_arg "PRZEFILTRUJ WERSALKĘ" f in
          VArray (Array.of_list (List.filter (fun x -> to_bool (f [x])) (Array.to_list a)))
      | _ -> raise (RuntimeError "PRZEFILTRUJ WERSALKĘ: pierwszy argument musi być tablicą"));

  (* SKRZYNKA: pierwiastek, sinus, cosinus (w radianach) - wynik z przecinkiem *)
  ["PIERWIASTEK ZE SKRZYNKI"], Some 1, (fun env args ->
      let x = to_float (eval_expr env (List.hd args)) in
      if x < 0.0 then raise (RuntimeError "PIERWIASTEK ZE SKRZYNKI: pierwiastek z liczby ujemnej");
      VFloat (sqrt x));

  ["SINUS ZE SKRZYNKI"], Some 1, (fun env args -> VFloat (sin (to_float (eval_expr env (List.hd args)))));

  ["COSINUS ZE SKRZYNKI"], Some 1, (fun env args -> VFloat (cos (to_float (eval_expr env (List.hd args)))));

  (* Czas: TRZEBA SPAĆ(ms) usypia, JEST TRZECIA W NOCY() - milisekundy od startu programu *)
  ["TRZEBA SPAĆ"], Some 1, (fun env args ->
      let ms = to_float (eval_expr env (List.hd args)) in
      if ms < 0.0 then raise (RuntimeError "TRZEBA SPAĆ: czas nie może być ujemny");
      flush stdout;
      Unix.sleepf (ms /. 1000.);
      VNull);

  ["JEST TRZECIA W NOCY"], Some 0, (fun _ _ ->
      VInt (int_of_float ((Unix.gettimeofday () -. program_start) *. 1000.)));

  (* PO PIERWSZE PRIMO(x, miejsca) - liczba jako tekst z ustaloną liczbą miejsc po przecinku *)
  ["PO PIERWSZE PRIMO"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [x; places] ->
          let n = to_int places in
          if n < 0 || n > 30 then raise (RuntimeError "PO PIERWSZE PRIMO: liczba miejsc musi być od 0 do 30");
          VString (Printf.sprintf "%.*f" n (to_float x))
      | _ -> VNull);
  ]
