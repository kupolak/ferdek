(* Wbudowane funkcje: WERSALKA - tablice *)

open Ast
open Value
open Eval
open Builtins_common

let register () = add [
  (* ILE NA WERSALCE(array) - returns array length *)
  ["ILE NA WERSALCE"], Some 1, (fun env args ->
      (match args with
       | [arr_arg] ->
           let arr_val = eval_expr env arr_arg in
           (match arr_val with
            | VArray arr -> VInt (List_utils.wersalka_ile_na arr)
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
                let new_arr = List_utils.wersalka_poloz_na arr elem in
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
                  let (new_arr, popped) = List_utils.wersalka_zdejmij_z arr in
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
                VBool (List_utils.wersalka_czy_lezy_na arr elem equal_func)
            | _ -> raise (RuntimeError "CZY LEŻY NA WERSALCE: pierwszy argument musi być tablicą"))
       | _ -> raise (RuntimeError "CZY LEŻY NA WERSALCE oczekuje 2 argumentów")));

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
      | VArray a -> VArray (List_utils.wersalka_odwroc a)
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

  ["WYTNIJ Z WERSALKI"], Some 3, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a; od; d] ->
          let od = to_int od and d = to_int d in
          if od < 0 || d < od || d > Array.length a then
            raise (RuntimeError (Printf.sprintf "WYTNIJ Z WERSALKI: zły zakres %d..%d (tablica ma %d)" od d (Array.length a)));
          VArray (Array.sub a od (d - od))
      | _ -> raise (RuntimeError "WYTNIJ Z WERSALKI: pierwszy argument musi być tablicą"));

  ["GDZIE LEŻY NA WERSALCE"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a; x] ->
          let rec find i = if i >= Array.length a then -1 else if same_element a.(i) x then i else find (i + 1) in
          VInt (find 0)
      | _ -> raise (RuntimeError "GDZIE LEŻY NA WERSALCE: pierwszy argument musi być tablicą"));

  ["ZESTAW WERSALKI"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a; VArray b] -> VArray (Array.append a b)
      | _ -> raise (RuntimeError "ZESTAW WERSALKI: oba argumenty muszą być tablicami"));

  (* Suma jak kolejne BABKA DAWAJ RENTĘ; pusta tablica to 0 *)
  ["ZSUMUJ WERSALKĘ"], Some 1, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a] ->
          if Array.length a = 0 then VInt 0
          else Array.fold_left (eval_arith_op Plus) a.(0) (Array.sub a 1 (Array.length a - 1))
      | _ -> raise (RuntimeError "ZSUMUJ WERSALKĘ: argument musi być tablicą"));

  ["NAJMNIEJSZY NA WERSALCE"], Some 1, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a] ->
          if Array.length a = 0 then raise (RuntimeError "NAJMNIEJSZY NA WERSALCE: pusta tablica");
          Array.fold_left (fun best x -> if compare_values x best < 0 then x else best) a.(0) a
      | _ -> raise (RuntimeError "NAJMNIEJSZY NA WERSALCE: argument musi być tablicą"));

  ["NAJWIĘKSZY NA WERSALCE"], Some 1, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a] ->
          if Array.length a = 0 then raise (RuntimeError "NAJWIĘKSZY NA WERSALCE: pusta tablica");
          Array.fold_left (fun best x -> if compare_values x best > 0 then x else best) a.(0) a
      | _ -> raise (RuntimeError "NAJWIĘKSZY NA WERSALCE: argument musi być tablicą"));

  (* ZWIŃ WERSALKĘ(t, start, f): f(f(f(start, t[0]), t[1]), ...) *)
  ["ZWIŃ WERSALKĘ"], Some 3, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a; start; VFunction (fdecl, closure_env)] ->
          Array.fold_left (fun acc x -> apply_function fdecl.name fdecl closure_env [acc; x]) start a
      | [VArray _; _; _] -> raise (RuntimeError "ZWIŃ WERSALKĘ: trzeci argument musi być funkcją")
      | _ -> raise (RuntimeError "ZWIŃ WERSALKĘ: pierwszy argument musi być tablicą"));

  ["BEZ POWTÓREK"], Some 1, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a] ->
          let out = List.fold_left (fun acc x -> if List.exists (same_element x) acc then acc else x :: acc) [] (Array.to_list a) in
          VArray (Array.of_list (List.rev out))
      | _ -> raise (RuntimeError "BEZ POWTÓREK: argument musi być tablicą"));

  ["ZRÓB KOLEJKĘ"], Some 2, (fun env args ->
      match List.map (eval_expr env) args with
      | [od; d] ->
          let od = to_int od and d = to_int d in
          if d >= od && d - od >= 10_000_000 then raise (RuntimeError "ZRÓB KOLEJKĘ: za długa (najwyżej 10000000 liczb)");
          if d < od then VArray [||] else VArray (Array.init (d - od + 1) (fun i -> VInt (od + i)))
      | _ -> VNull);

  ["WYLOSUJ Z WERSALKI"], Some 1, (fun env args ->
      match List.map (eval_expr env) args with
      | [VArray a] ->
          if Array.length a = 0 then raise (RuntimeError "WYLOSUJ Z WERSALKI: pusta tablica");
          a.(rng_next () mod Array.length a)
      | _ -> raise (RuntimeError "WYLOSUJ Z WERSALKI: argument musi być tablicą"));
  ]
