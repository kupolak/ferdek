(* HashMap (dictionary/map) library functions helpers for SZAFKA *)

(* Get all keys from hashtable *)
let szafka_wszystkie_szufladki tbl =
  Hashtbl.fold (fun k _ acc -> k :: acc) tbl []

(* Get all values from hashtable *)
let szafka_wszystkie_wartosci tbl =
  Hashtbl.fold (fun _ v acc -> v :: acc) tbl []

(* Check if key exists *)
let szafka_czy_w_szafce tbl key =
  Hashtbl.mem tbl key

(* Get value or return default *)
let szafka_wyjmij_lub_domyslna tbl key default =
  match Hashtbl.find_opt tbl key with
  | Some v -> v
  | None -> default

(* Count elements *)
let szafka_ile_w_szafce tbl =
  Hashtbl.length tbl

(* Clear all elements *)
let szafka_oproznij tbl =
  Hashtbl.clear tbl

(* Create a copy of hashtable *)
let szafka_kopiuj tbl =
  Hashtbl.copy tbl
