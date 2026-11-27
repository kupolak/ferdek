(* Wbudowane funkcje: KIBEL - pliki i niskopoziomowe wejście/wyjście *)

open Value
open Builtins_common

let register () = add [
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

  (* ZRÓB KIBEL(path) - creates directory *)
  ["ZRÓB KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (File_utils.kibel_zrob path)
       | _ -> raise (RuntimeError "ZRÓB KIBEL oczekuje 1 argumentu")));

  (* WYWAL KIBEL(path) - removes directory *)
  ["WYWAL KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (File_utils.kibel_wywal path)
       | _ -> raise (RuntimeError "WYWAL KIBEL oczekuje 1 argumentu")));

  (* CO W KIBLU(path) - lists files in directory *)
  ["CO W KIBLU"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           let files = File_utils.kibel_co_w_kiblu path in
           VArray (Array.of_list (List.map (fun f -> VString f) files))
       | _ -> raise (RuntimeError "CO W KIBLU oczekuje 1 argumentu")));

  (* CZY TO KIBEL(path) - checks if path is directory *)
  ["CZY TO KIBEL"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           VBool (File_utils.kibel_czy_to_kibel path)
       | _ -> raise (RuntimeError "CZY TO KIBEL oczekuje 1 argumentu")));

  (* PRZEKOPIUJ KIBEL(src, dest) - copies file *)
  ["PRZEKOPIUJ KIBEL"], Some 2, (fun env args ->
      (match args with
       | [src_arg; dest_arg] ->
           let src = to_string (eval_expr env src_arg) in
           let dest = to_string (eval_expr env dest_arg) in
           VBool (File_utils.kibel_przekopiuj src dest)
       | _ -> raise (RuntimeError "PRZEKOPIUJ KIBEL oczekuje 2 argumentów")));

  (* PRZENIEŚ KIBEL(src, dest) - moves/renames file *)
  ["PRZENIEŚ KIBEL"], Some 2, (fun env args ->
      (match args with
       | [src_arg; dest_arg] ->
           let src = to_string (eval_expr env src_arg) in
           let dest = to_string (eval_expr env dest_arg) in
           VBool (File_utils.kibel_przenies src dest)
       | _ -> raise (RuntimeError "PRZENIEŚ KIBEL oczekuje 2 argumentów")));

  (* WYKOP WSZYSTKIE KIBLE(path) - recursive delete *)
  ["WYKOP WSZYSTKIE KIBLE"], Some 1, (fun env args ->
      (match args with
       | [path_arg] ->
           let path = to_string (eval_expr env path_arg) in
           File_utils.kibel_wykop_wszystkie path;
           VNull
       | _ -> raise (RuntimeError "WYKOP WSZYSTKIE KIBLE oczekuje 1 argumentu")));

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
                if size < 0 then raise (RuntimeError "CZYTAJ: liczba bajtów nie może być ujemna");
                (try
                   let buffer = Bytes.create size in
                   (* input oddaje najwyżej to, co ma w buforze kanału (64 KB) - czytamy do skutku albo do końca pliku *)
                   let rec fill got =
                     if got >= size then got
                     else match input ch buffer got (size - got) with 0 -> got | n -> fill (got + n) in
                   let bytes_read = fill 0 in
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
  ]
