(* Kolorowanie składni: rodzaje fragmentów i ich granice (także tekst z cudzysłowem po komentarzu) *)
open Highlight

let () =
  let src = "CO JEST KURDE\n#define X 1\nRYM CYM CYM \"nie tekst\"\nPANIE SENSACJA REWELACJA \"a\\\"b\" BABKA DAWAJ RENTĘ 12\n"
            ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA ILE MIEJSCA NA KANAPIE(x)\n"
            ^ "PANIE SENSACJA REWELACJA POWIEM PANU TAK \"a {x PASZOŁ WON 1} b {x}\"\n"
            ^ "PANIE SENSACJA REWELACJA POWIEM PANU TAK \"c\"\n" in
  let got = spans ~is_builtin:(fun n -> n = "ILE MIEJSCA NA KANAPIE") src
            |> List.map (fun (a, b, k) -> (String.sub src a (b - a), kind_code k)) in
  let want = [ "CO JEST KURDE", 0; "#define X 1", 5; "RYM CYM CYM \"nie tekst\"", 4;
               "PANIE SENSACJA REWELACJA", 0; "\"a\\\"b\"", 2; "BABKA DAWAJ RENTĘ", 0; "12", 3;
               "PANIE SENSACJA REWELACJA", 0; "W MORDĘ JEŻA", 0; "ILE MIEJSCA NA KANAPIE", 1;
               "(", 0; ")", 0;
               "PANIE SENSACJA REWELACJA", 0; "POWIEM PANU TAK ", 0; "\"a {", 2; "PASZOŁ WON", 0; "1", 3;
               "} b {", 2; "}\"", 2;
               "PANIE SENSACJA REWELACJA", 0; "POWIEM PANU TAK ", 0; "\"c\"", 2 ] in
  if got <> want then begin
    List.iter (fun (s, k) -> Printf.printf "%d %S\n" k s) got;
    exit 1
  end;
  print_endline "--- highlight: OK"
