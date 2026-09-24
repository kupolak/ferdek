(* Analiza liczb całkowitych w kompilatorze (infer_ints): co trafia do C jako long long,
   a co musi zostać zwykłą wartością. Sprawdzamy deklaracje w wygenerowanym kodzie. *)

let compile body =
  let src = "CO JEST KURDE\n" ^ body ^ "\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE\n" in
  match Source.parse_source "test.ferdek" src with
  | Ok prog -> Compiler.compile_program prog
  | Error errs -> failwith (String.concat "\n" (List.map (fun (_, _, m) -> m) errs))

let contains s sub =
  let n = String.length sub in
  let rec go i = i + n <= String.length s && (String.sub s i n = sub || go (i + 1)) in
  go 0

let failures = ref 0
let check name body ~has ~lacks =
  let c = compile body in
  List.iter (fun sub -> if not (contains c sub) then (incr failures; Printf.printf "FAIL %s: brak %S\n" name sub)) has;
  List.iter (fun sub -> if contains c sub then (incr failures; Printf.printf "FAIL %s: jest %S\n" name sub)) lacks

let fn name params body =
  Printf.sprintf "ALE WIE PAN JA ZASADNICZO %s\nNO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ\n%s%s\nDO WIDZENIA PANU\n" name
    (if params = "" then "" else "NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO " ^ params ^ "\n") body

let () =
  check "rekurencja" (fn "fib" "n" "    NO JAK NIE JAK TAK n ŁYSA PAŁA 2\n        I JA INFORMUJĘ ŻE WYCHODZĘ n\n    DO CHAŁUPY ALE JUŻ\n    I JA INFORMUJĘ ŻE WYCHODZĘ W MORDĘ JEŻA fib(n PASZOŁ WON 1) BABKA DAWAJ RENTĘ W MORDĘ JEŻA fib(n PASZOŁ WON 2)"
                          ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA fib(20)")
    ~has:["long long f_fib(long long v_n)"] ~lacks:[];
  check "funkcja jako wartość" (fn "kw" "x" "    I JA INFORMUJĘ ŻE WYCHODZĘ x ROZDUPCĘ BANK x"
                                ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA kw(2)\nCYCU PRZYNIEŚ NO p\nTO NIE SĄ TANIE RZECZY PALCEM POKAZUJĘ kw")
    ~has:["FerdekValue f_kw(FerdekValue v_x)"] ~lacks:["long long f_kw"];
  check "raz z tekstem" (fn "d" "x" "    I JA INFORMUJĘ ŻE WYCHODZĘ x BABKA DAWAJ RENTĘ x"
                         ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA d(2)\nPANIE SENSACJA REWELACJA W MORDĘ JEŻA d(\"a\")")
    ~has:["FerdekValue f_d(FerdekValue v_x)"] ~lacks:[];
  check "wynik raz tekstem" (fn "m" "x" "    NO JAK NIE JAK TAK x GRUBA ŚWINIA 0\n        I JA INFORMUJĘ ŻE WYCHODZĘ 1\n    A DUPA TAM\n        I JA INFORMUJĘ ŻE WYCHODZĘ \"nie\"\n    DO CHAŁUPY ALE JUŻ"
                             ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA m(3)")
    ~has:["FerdekValue f_m(long long v_x)"] ~lacks:[];
  check "bez return na końcu" (fn "b" "x" "    NO JAK NIE JAK TAK x GRUBA ŚWINIA 0\n        I JA INFORMUJĘ ŻE WYCHODZĘ 1\n    DO CHAŁUPY ALE JUŻ"
                               ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA b(3)")
    ~has:["FerdekValue f_b(long long v_x)"] ~lacks:["long long f_b"];
  check "globalne" ("CYCU PRZYNIEŚ NO g\nTO NIE SĄ TANIE RZECZY 1\nCYCU PRZYNIEŚ NO h\nTO NIE SĄ TANIE RZECZY 1\n"
                    ^ fn "psuj" "" "    O KURDE MAM POMYSŁA h A PROSZĘ BARDZO \"tekst\" NO I GITARA"
                    ^ "O KURDE MAM POMYSŁA g A PROSZĘ BARDZO g BABKA DAWAJ RENTĘ 1 NO I GITARA\nW MORDĘ JEŻA psuj()")
    ~has:["static long long v_g = 0;"; "static FerdekValue v_h;"] ~lacks:[];
  check "globalna zmieniana w lambdzie"
    ("CYCU PRZYNIEŚ NO g\nTO NIE SĄ TANIE RZECZY 1\nCYCU PRZYNIEŚ NO f\nTO NIE SĄ TANIE RZECZY JAK ROBIĆ ŻEBY SIĘ NIE NAROBIĆ() NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ\n"
     ^ "    O KURDE MAM POMYSŁA g A PROSZĘ BARDZO 2 NO I GITARA\nDO WIDZENIA PANU")
    ~has:["static FerdekValue v_g;"] ~lacks:[];
  check "lokalne" (fn "suma" "n" "    CYCU PRZYNIEŚ NO s\n    TO NIE SĄ TANIE RZECZY 0\n    CYCU PRZYNIEŚ NO t\n    TO NIE SĄ TANIE RZECZY 0\n    CO TAM U PANA SŁYCHAĆ t\n    KRĘCI CEMENT BETONIARA i OD 1 DO n\n        O KURDE MAM POMYSŁA s A PROSZĘ BARDZO s BABKA DAWAJ RENTĘ i NO I GITARA\n    A ROBIĆ NI MA KOMU\n    I JA INFORMUJĘ ŻE WYCHODZĘ s"
                   ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA suma(10)")
    ~has:["long long v_s = 0;"; "long long v_i = 0;"; "FerdekValue v_t = make_null();"] ~lacks:[];
  check "wariadyczna" ("ALE WIE PAN JA ZASADNICZO w\nNO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ\nNA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO a, ...\n    I JA INFORMUJĘ ŻE WYCHODZĘ a\nDO WIDZENIA PANU\n"
                       ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA w(1, 2)")
    ~has:["FerdekValue f_w(FerdekValue v_a, FerdekValue v_varargs)"] ~lacks:[];
  check "przesłonięta nazwa" (fn "p" "x" "    I JA INFORMUJĘ ŻE WYCHODZĘ x"
                              ^ fn "q" "p" "    I JA INFORMUJĘ ŻE WYCHODZĘ p"
                              ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA p(1)\nPANIE SENSACJA REWELACJA W MORDĘ JEŻA q(1)")
    ~has:["FerdekValue f_p(FerdekValue v_x)"] ~lacks:[];
  check "wywołanie z metody z polem"
    (fn "k" "x" "    I JA INFORMUJĘ ŻE WYCHODZĘ x ROZDUPCĘ BANK 2"
     ^ "ALE JAJA A\n    CYCU PRZYNIEŚ NO pole\n    TO NIE SĄ TANIE RZECZY 3\n    ALE WIE PAN JA ZASADNICZO m\n    NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ\n        I JA INFORMUJĘ ŻE WYCHODZĘ W MORDĘ JEŻA k(pole)\n    DO WIDZENIA PANU\nDO WIDZENIA PANU\n"
     ^ "PANIE SENSACJA REWELACJA W MORDĘ JEŻA k(1)")
    ~has:["f_k(FerdekValue v_x)"] ~lacks:["f_k(long long"];
  check "z przecinkiem" ("CYCU PRZYNIEŚ NO s\nTO NIE SĄ TANIE RZECZY 0.0\nKRĘCI CEMENT BETONIARA k OD 1 DO 10\n"
                         ^ "    O KURDE MAM POMYSŁA s A PROSZĘ BARDZO s BABKA DAWAJ RENTĘ 1 MUSZĘ DO SRACZA k NO I GITARA\nA ROBIĆ NI MA KOMU\n"
                         ^ "CYCU PRZYNIEŚ NO r\nTO NIE SĄ TANIE RZECZY W MORDĘ JEŻA SINUS ZE SKRZYNKI(s)")
    ~has:["static double v_s = 0.0;"; "static double v_r = 0.0;"; "static long long v_k = 0;"] ~lacks:[];
  check "raz całkowita, raz z przecinkiem" ("CYCU PRZYNIEŚ NO m\nTO NIE SĄ TANIE RZECZY 1\nO KURDE MAM POMYSŁA m A PROSZĘ BARDZO 2.5 NO I GITARA")
    ~has:["static FerdekValue v_m;"] ~lacks:["static double v_m"; "static long long v_m"];
  check "długość jako liczba" ("CYCU PRZYNIEŚ NO n\nTO NIE SĄ TANIE RZECZY W MORDĘ JEŻA ILE NA WERSALCE([1, 2]) BABKA DAWAJ RENTĘ 1")
    ~has:["static long long v_n = 0;"] ~lacks:[];
  if !failures > 0 then (Printf.printf "Padło: %d\n" !failures; exit 1)
  else print_endline "--- infer_ints: OK"
