(* List/Array operations library functions helpers for WERSALKA *)

(* Append element to array - returns new array *)
let wersalka_poloz_na arr element =
  let new_arr = Array.make (Array.length arr + 1) element in
  Array.blit arr 0 new_arr 0 (Array.length arr);
  new_arr.(Array.length arr) <- element;
  new_arr

(* Pop last element - returns (new_array, popped_element) *)
let wersalka_zdejmij_z arr =
  let len = Array.length arr in
  if len = 0 then
    raise (Failure "ZDEJMIJ Z WERSALKI: lista jest pusta")
  else
    let new_arr = Array.sub arr 0 (len - 1) in
    let popped = arr.(len - 1) in
    (new_arr, popped)

(* Sort array - returns new sorted array *)
let wersalka_poskladaj arr compare_func =
  let new_arr = Array.copy arr in
  Array.sort compare_func new_arr;
  new_arr

(* Check if element is in array *)
let wersalka_czy_lezy_na arr element equal_func =
  Array.exists (fun x -> equal_func x element) arr

(* Find element in array - returns Some index or None *)
let wersalka_znajdz_na arr predicate =
  let rec find_idx i =
    if i >= Array.length arr then
      None
    else if predicate arr.(i) then
      Some i
    else
      find_idx (i + 1)
  in
  find_idx 0

(* Filter array *)
let wersalka_przefiltruj arr predicate =
  Array.of_list (List.filter predicate (Array.to_list arr))

(* Map array *)
let wersalka_przerabiaj arr func =
  Array.map func arr

(* Reverse array *)
let wersalka_odwroc arr =
  let new_arr = Array.copy arr in
  let len = Array.length new_arr in
  for i = 0 to len / 2 - 1 do
    let temp = new_arr.(i) in
    new_arr.(i) <- new_arr.(len - 1 - i);
    new_arr.(len - 1 - i) <- temp
  done;
  new_arr

(* Get array length *)
let wersalka_ile_na arr =
  Array.length arr

(* Get element at index with bounds check *)
let wersalka_co_lezy_na arr idx =
  if idx < 0 || idx >= Array.length arr then
    raise (Failure "ILE NA WERSALCE: indeks poza zakresem")
  else
    arr.(idx)
