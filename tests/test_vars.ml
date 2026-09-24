(* Tablica zmiennych interpretera (Value.Vars): wstawianie z powiększaniem, podmiana, kopia *)
open Value

let () =
  let t = Vars.create 1 in
  for i = 0 to 999 do Vars.replace t ("x" ^ string_of_int i) i done;
  for i = 0 to 999 do assert (Vars.find_opt t ("x" ^ string_of_int i) = Some i) done;
  assert (Vars.find_opt t "brak" = None && not (Vars.mem t "brak"));
  Vars.replace t "x5" 42;
  assert (Vars.find_opt t "x5" = Some 42);
  assert (Vars.fold (fun _ _ n -> n + 1) t 0 = 1000);
  let c = Vars.copy t in
  Vars.replace c "x5" 7;
  Vars.replace c "nowa" 1;
  assert (Vars.find_opt t "x5" = Some 42 && not (Vars.mem t "nowa"));
  print_endline "--- vars: OK"

(* Liczba jako tekst (Value.int_to_string) - to samo co string_of_int, też na krańcach *)
let () =
  List.iter (fun n -> assert (Value.int_to_string n = string_of_int n))
    [0; 7; 9; 10; -1; -9; -10; 123456789; -987654321; max_int; min_int];
  for n = -2000 to 2000 do assert (Value.int_to_string n = string_of_int n) done;
  print_endline "--- int_to_string: OK"
