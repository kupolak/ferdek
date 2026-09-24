(* Ferdek - główna komenda CLI *)

open Source

(* Katalog pliku źródłowego - do szukania stdlib *)
let source_file_dir = ref ""

(* Find stdlib directory *)
let find_stdlib_dir () =
  (* Get directory where ferdek executable is located *)
  let exe_dir = Filename.dirname Sys.executable_name in
  let source_dir = !source_file_dir in
  (* Check environment variable first *)
  let ferdek_home = Sys.getenv_opt "FERDEK_HOME" in
  let ferdek_stdlib = Sys.getenv_opt "FERDEK_STDLIB" in
  let home_dir = Sys.getenv_opt "HOME" |> Option.value ~default:"/tmp" in
  let env_paths = match ferdek_stdlib, ferdek_home with
    | Some stdlib, _ -> [stdlib]
    | None, Some home -> [Filename.concat home "stdlib"]
    | None, None -> []
  in
  let candidates = env_paths @ [
    (* Standard search paths *)
    "./stdlib";
    "../stdlib";
    "../../stdlib";
    (* Relative to source file location *)
    Filename.concat source_dir "stdlib";
    Filename.concat source_dir "../stdlib";
    Filename.concat (Filename.dirname source_dir) "stdlib";
    (* Relative to executable location *)
    Filename.concat exe_dir "stdlib";
    Filename.concat exe_dir "../stdlib";
    Filename.concat (Filename.dirname exe_dir) "stdlib";
    (* Common installation paths *)
    "/usr/local/share/ferdek/stdlib";
    "/usr/share/ferdek/stdlib";
    Filename.concat home_dir ".ferdek/stdlib";
  ] in
  let rec find_first = function
    | [] -> None
    | dir :: rest ->
        (* Samo "stdlib" nie wystarczy - np. tests/integration/stdlib to katalog testów *)
        if Sys.file_exists (Filename.concat dir "KLAMOTY") then
          Some dir
        else
          find_first rest
  in
  find_first candidates

(* Wyświetla help *)
let print_help () =
  Printf.printf "Ferdek - Język Biedy i Zjednoczenia Narodowego v2.0\n\n";
  Printf.printf "Jak uruchomić, żeby nie było wstydu: ferdek [opcje] [plik.ferdek]\n\n";
  Printf.printf "Opcje:\n";
  Printf.printf "  -h, --help              Pytaj o pomoc. Ferdek jest bezrobotny i ma czas.\n";
  Printf.printf "  -v, --version           Sprawdza, czy to jest już ta nowa, lepsza Polska.\n";
  Printf.printf "  -i, --interpret <plik>  Odpal na szybko, bez zbędnych ceregieli (standard).\n";
  Printf.printf "  -c, --compile <plik>    Rób karierę, kompiluj do C (dla ambitnych, jak Paździoch).\n";
  Printf.printf "  -o <wyjście>            Gdzie to schować, żeby Halina nie znalazła? (Plik wyjściowy)\n";
  Printf.printf "  -r, --run               Szybki szlag! Kompiluj i odpal (tryb testowy).\n";
  Printf.printf "  --check <plik>          Sprawdź bez uruchamiania: nieznane zmienne, funkcje, liczba argumentów.\n";
  Printf.printf "  test [katalog]          Uruchom wszystkie pliki *_test.ferdek (np. z BABKĄ) i podsumuj.\n";
  Printf.printf "  nowy <nazwa>            Nowy projekt: program, moduł, test BABKI i README.\n";
  Printf.printf "  --fmt <plik>            Wypisz program z uporządkowanymi wcięciami.\n";
  Printf.printf "  --fmt-check <plik>      Sprawdź, że formatowanie nie zmienia programu i jest stabilne.\n";
  Printf.printf "  --repl                  Pogadaj sobie z Ferdkiem (tryb interaktywny).\n";
  Printf.printf "  --lsp                   Serwer LSP dla edytorów: definicje, użycia, zmiana nazwy.\n";
  Printf.printf "  --debug <plik>          Debugger: krok po kroku, punkty zatrzymania, podgląd zmiennych.\n\n";

  Printf.printf "Przykłady (A niech to dunder świśnie!):\n";
  Printf.printf "  ferdek program.ferdek           # Idziemy na łatwiznę, odpalamy program!\n";
  Printf.printf "  ferdek --compile program.ferdek # Generujemy ten kod C (dla zarobku).\n";
  Printf.printf "  ferdek -c program.ferdek -o app # Budujemy 'apkę' (Paździoch sprzeda to na bazarku).\n";
  Printf.printf "  ferdek --run program.ferdek     # Testujemy na prędko, czy działa piwo.\n";
  Printf.printf "  ferdek --repl                   # Czas na filozoficzne rozmowy o życiu.\n\n";
  Printf.printf "Więcej głupot (i dokumentacji): https://github.com/kupolak/ferdek\n"

(* Wyświetla wersję *)
let print_version () =
  Printf.printf "Ferdek - Język Prawdziwych Polaków v2.0\n";
  Printf.printf "Nie ma pracy dla ludzi z naszym wykształceniem! / Walduś, to jest język!\n"

(* Parse a file *)
let parse_file filename =
  (try Sources.register filename (In_channel.with_open_bin filename In_channel.input_all) with Sys_error _ -> ());
  match String.concat "\n" (Preprocessor.preprocess_file filename) with
  | text ->
      (match parse_source ~preprocessed:true filename text with
       | Ok prog -> Ok prog
       | Error errs ->
           Error (String.concat "\nA fe! " (List.map (fun (l, c, m) -> m ^ Sources.caret filename l c) errs)))
  | exception Failure msg -> Error (Printf.sprintf "Błąd Preprocesora w %s: %s" filename msg)
  | exception Lexer.LexError msg ->
      Error (Printf.sprintf "Błąd Leksera! Ktoś tu namieszał w słowach! W %s: %s (Paździoch ukradł słowa)." filename msg)
  | exception Sys_error msg -> Error (Printf.sprintf "Nie ma takiego pliku, Paździoch go zajumał: %s" msg)

(* Plik modułu: ścieżka z resolve_local_imports (plik obok programu) albo moduł z stdlib *)
let find_module_file module_name =
  if Filename.check_suffix module_name ".ferdek" && Sys.file_exists module_name then Some module_name
  else match find_stdlib_dir () with
    | None -> None
    | Some stdlib_dir ->
        let klamoty = Filename.concat stdlib_dir "KLAMOTY" in
        let name = if String.length module_name > 8 && String.sub module_name 0 8 = "KLAMOTY/"
                   then String.sub module_name 8 (String.length module_name - 8) else module_name in
        (* KLAMOTY/<nazwa>/<nazwa>.ferdek (np. BABKA) albo KLAMOTY/<nazwa>.ferdek *)
        List.find_opt Sys.file_exists
          [Filename.concat (Filename.concat klamoty name) (name ^ ".ferdek");
           Filename.concat klamoty (name ^ ".ferdek")]

(* Module loader for stdlib *)
let load_stdlib_module module_name =
  match find_module_file module_name with
  | None -> None
  | Some path ->
      match parse_file path with
      | Ok ast -> Some ast
      | Error msg ->
          Printf.eprintf "Błąd w module %s: %s\n" module_name msg;
          None

(* Dla ferdek --lsp: błędy składni albo problemy z --check, jako (linia, kolumna, komunikat) *)
let diagnose filename text =
  match parse_source filename text with
  | Error errs -> errs
  | Ok prog ->
      let where = Str.regexp "^\\(\\(.*\\), \\)?linia \\([0-9]+\\): " in
      Checker.check ~load_module:load_stdlib_module prog |> List.filter_map (fun issue ->
        if Str.string_match where issue 0 then
          let file = try Str.matched_group 2 issue with Not_found -> filename in
          let line = int_of_string (Str.matched_group 3 issue) in
          (* problemy z modułów zostają w modułach *)
          if file = filename then Some (line, 1, Str.string_after issue (Str.match_end ())) else None
        else Some (0, 1, issue))

(* Interpretuje plik *)
let interpret_file filename =
  match parse_file filename with
  | Ok ast ->
      (match Interpreter.eval_program ast with
       | Ok () -> 
           Printf.printf "Program zakończony pomyślnie. Piwo dla Pana!\n";
           0
       | Error msg ->
           Printf.eprintf "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: %s\n%s" msg (Interpreter.error_context ());
           1)
  | Error msg ->
      Printf.eprintf "A fe! %s\n" msg;
      1

(* ferdek test [katalog]: każdy *_test.ferdek osobno; porażka = niezerowy kod wyjścia *)
let run_tests dir =
  let rec find dir =
    Sys.readdir dir |> Array.to_list |> List.sort compare
    |> List.concat_map (fun name ->
         let path = Filename.concat dir name in
         if Sys.is_directory path then (if name.[0] = '.' || name = "_build" then [] else find path)
         else if Filename.check_suffix name "_test.ferdek" then [path] else [])
  in
  match find dir with
  | [] -> Printf.printf "Nie ma żadnych plików *_test.ferdek w %s\n" dir; 1
  | files ->
      let log = Filename.temp_file "ferdek_test_" ".log" in
      let failed = List.filter (fun file ->
        let rc = Sys.command (Printf.sprintf "%s %s > %s 2>&1 < /dev/null"
                                (Filename.quote Sys.executable_name) (Filename.quote file) (Filename.quote log)) in
        if rc = 0 then (Printf.printf "--- %s: OK\n%!" file; false)
        else begin
          Printf.printf "--- %s: OBLANY\n" file;
          let lines = In_channel.with_open_bin log In_channel.input_all |> String.split_on_char '\n'
                      |> List.filter (( <> ) "") in
          let n = List.length lines in
          List.iteri (fun i l -> if i >= n - 3 then Printf.printf "    %s\n" l) lines;
          true
        end) files in
      (try Sys.remove log with _ -> ());
      let total = List.length files and bad = List.length failed in
      Printf.printf "Zaliczone: %d/%d%s\n" (total - bad) total
        (if bad = 0 then " - Babka zadowolona!" else " - Babka niezadowolona.");
      if bad = 0 then 0 else 1

(* ferdek nowy nazwa: szkielet projektu - program, moduł z funkcją, test BABKI, README *)
let new_project name =
  let valid = name <> "" && String.for_all (fun c -> match c with
    | 'a'..'z' | 'A'..'Z' | '0'..'9' | '_' | '-' -> true | _ -> false) name in
  if not valid then (Printf.eprintf "A fe! Nazwa projektu: litery, cyfry, _ i - (bez polskich znaków i spacji)\n"; 1)
  else if Sys.file_exists name then (Printf.eprintf "A fe! %s już istnieje - nie ruszam\n" name; 1)
  else begin
    Sys.mkdir name 0o755;
    let write file text = Out_channel.with_open_bin (Filename.concat name file) (fun oc -> output_string oc text) in
    write (name ^ ".ferdek") (Printf.sprintf {|CO JEST KURDE
RYM CYM CYM %s - uruchom: ferdek %s.ferdek
O KOGO MOJE PIĘKNE OCZY WIDZĄ pomocnik

PANIE SENSACJA REWELACJA W MORDĘ JEŻA powitanie("Ferdek")
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
|} name name);
    write "pomocnik.ferdek" {|CO JEST KURDE
RYM CYM CYM Moduł projektu - funkcje do użycia w programie i w testach

ALE WIE PAN JA ZASADNICZO powitanie
NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ TO SĄ STRINGI
NA TAKIE TEMATY NIE ROZMAWIAM NA SUCHO kto TO SĄ STRINGI
    I JA INFORMUJĘ ŻE WYCHODZĘ "Walduś, to jest " BABKA DAWAJ RENTĘ kto BABKA DAWAJ RENTĘ "!"
DO WIDZENIA PANU
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
|};
    write "pomocnik_test.ferdek" {|CO JEST KURDE
RYM CYM CYM Testy - uruchom: ferdek test
O KOGO MOJE PIĘKNE OCZY WIDZĄ BABKA
O KOGO MOJE PIĘKNE OCZY WIDZĄ pomocnik

W MORDĘ JEŻA MA BYĆ RÓWNE("Walduś, to jest Boczek!", W MORDĘ JEŻA powitanie("Boczek"))
W MORDĘ JEŻA BABKA PODSUMUJ
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
|};
    write "README.md" (Printf.sprintf {|# %s

Projekt w języku Ferdek.

- `ferdek %s.ferdek` - uruchom
- `ferdek test` - testy (pliki `*_test.ferdek`, asercje z modułu BABKA)
- `ferdek -c %s.ferdek -o %s` - skompiluj do pliku wykonywalnego
- `ferdek --check %s.ferdek` - sprawdź bez uruchamiania
- `ferdek --debug %s.ferdek` - krok po kroku
|} name name name name name name);
    write ".gitignore" (name ^ "\n");
    Printf.printf "Zrobione! Projekt %s:\n  cd %s\n  ferdek %s.ferdek\n  ferdek test\n" name name name;
    0
  end

(* --fmt i --fmt-check *)
let read_file path = In_channel.with_open_bin path In_channel.input_all

let fmt_file filename =
  match read_file filename with
  | src -> print_string (Formatter.format src); 0
  | exception Sys_error msg -> Printf.eprintf "A fe! %s\n" msg; 1

(* Sformatowany program ma to samo AST (bez numerów linii), a drugie formatowanie nic nie zmienia *)
let fmt_check filename =
  let src = read_file filename in
  let once = Formatter.format src in
  let tmp = Filename.concat (Filename.dirname filename) (".fmt_check_" ^ Filename.basename filename) in
  Out_channel.with_open_bin tmp (fun oc -> output_string oc once);
  let ast f = match parse_file f with Ok a -> Some (Ast.string_of_program a) | Error _ -> None in
  let same_ast = ast filename = ast tmp in
  (try Sys.remove tmp with _ -> ());
  let stable = Formatter.format once = once in
  if same_ast && stable then 0
  else begin
    Printf.eprintf "%s: %s\n" filename
      (if not same_ast then "formatowanie zmienia program!" else "formatowanie nie jest stabilne");
    1
  end

(* --check: błędy przed uruchomieniem *)
let check_file filename =
  match parse_file filename with
  | Error msg -> Printf.eprintf "A fe! %s\n" msg; 1
  | Ok ast ->
      match Checker.check ~load_module:load_stdlib_module ast with
      | [] -> Printf.printf "Wszystko gra, można odpalać: %s\n" filename; 0
      | issues ->
          List.iter (Printf.eprintf "Paździoch znalazł: %s\n") issues;
          Printf.eprintf "Problemów: %d\n" (List.length issues);
          1

(* Parsuje i generuje kod C; błędy parsowania i nieobsługiwane konstrukcje -> Error *)
let generate_c input_file =
  match parse_file input_file with
  | Error msg -> Error msg
  | Ok ast ->
      (try Ok (Compiler.compile_program ~load_module:load_stdlib_module ast)
       with Compiler.Compile_error msg -> Error msg)

let write_file path content =
  let oc = open_out path in
  output_string oc content;
  close_out oc

(* cc zamiast gcc: na macOS i Linuksie to domyślny kompilator C *)
let cc c_file exe =
  (* Program z grafiką (Graphics_source w środku) potrzebuje X11: XQuartz, Homebrew albo systemowe *)
  let code = In_channel.with_open_bin c_file In_channel.input_all in
  let x11 =
    try ignore (Str.search_forward (Str.regexp_string "X11/Xlib.h") code 0);
        " -I/opt/X11/include -I/opt/homebrew/include -I/usr/local/include -L/opt/X11/lib -L/opt/homebrew/lib -L/usr/local/lib -lX11"
    with Not_found -> "" in
  (* Odśmiecacz Boehma, jeśli jest w systemie (Homebrew, /usr/local, pakiet libgc-dev) *)
  let gc =
    List.find_map (fun (inc, lib) ->
      if Sys.file_exists (Filename.concat inc "gc.h")
      then Some (Printf.sprintf " -DFERDEK_GC -I%s -L%s -lgc" inc lib) else None)
      ["/opt/homebrew/include", "/opt/homebrew/lib"; "/usr/local/include", "/usr/local/lib"; "/usr/include", "/usr/lib"]
    |> Option.value ~default:"" in
  (* -w: ostrzeżenia o wygenerowanym kodzie (np. x == x z programu) nic nie mówią użytkownikowi.
     -ffp-contract=off: bez łączenia a*b+c w jedno działanie (FMA) - inaczej ostatnie cyfry
     liczb z przecinkiem różniłyby się od interpretera. -fno-builtin-sin/cos: gcc liczyłby sin stałej
     już przy kompilacji (dokładniej niż biblioteka, z której korzysta interpreter) *)
  (* FERDEK_CC: inny kompilator C (np. gcc-15), domyślnie systemowe cc *)
  let compiler = match Sys.getenv_opt "FERDEK_CC" with Some c when c <> "" -> c | _ -> "cc" in
  Sys.command (Printf.sprintf "%s -std=c99 -O2 -ffp-contract=off -fno-builtin-sin -fno-builtin-cos -w -o %s %s -lm%s%s" compiler (Filename.quote exe) (Filename.quote c_file) x11 gc)

(* -c: plik .c albo (inne rozszerzenie) gotowa binarka *)
let compile_file input_file output_file =
  match generate_c input_file with
  | Error msg -> Printf.eprintf "A fe! %s\n" msg; 1
  | Ok c_code when Filename.check_suffix output_file ".c" ->
      write_file output_file c_code;
      Printf.printf "No i gitara! Kod C gotowy: %s -> %s\n" input_file output_file;
      0
  | Ok c_code ->
      let c_file = Filename.temp_file "ferdek_" ".c" in
      write_file c_file c_code;
      let rc = cc c_file output_file in
      (try Sys.remove c_file with _ -> ());
      if rc = 0 then begin
        Printf.printf "Sukces! Działa! Halina, mam pieniądze! (Plik: %s)\n" output_file;
        0
      end else begin
        Printf.eprintf "Błąd kompilacji C. A żeby cię Babka pokręciła! (Kod: %d)\n" rc;
        1
      end

(* -r: kompiluje, uruchamia i sprząta *)
let quick_run input_file =
  match generate_c input_file with
  | Error msg -> Printf.eprintf "A fe! %s\n" msg; 1
  | Ok c_code ->
      let temp_c = Filename.temp_file "ferdek_" ".c" in
      let temp_exe = Filename.temp_file "ferdek_" "" in
      write_file temp_c c_code;
      let rc =
        if cc temp_c temp_exe = 0 then Sys.command (Filename.quote temp_exe)
        else (Printf.eprintf "Błąd kompilacji. Nawet szybki szlag się nie udał...\n"; 1)
      in
      (try Sys.remove temp_c with _ -> ());
      (try Sys.remove temp_exe with _ -> ());
      rc

(* REPL *)
let repl () =
  Printf.printf "Ferdek REPL - Gadka Szmatka v2.0\n";
  Printf.printf "Wpisz 'wypad' albo 'spadaj' aby iść na piwo (exit/quit)\n";
  Printf.printf "Instrukcje na kilka linii zbieram, aż będą kompletne. Pusta linia = porzuć.\n\n";
  let session = Interpreter.new_session () in
  let program_end = "MOJA NOGA JUŻ TUTAJ NIE POSTANIE" in

  (* Ok (Some ast) = gotowe, Ok None = instrukcja niekompletna, Error = błąd *)
  let try_parse buf =
    let code = "CO JEST KURDE\n" ^ buf ^ "\n" ^ program_end in
    let lexbuf = Lexing.from_string code in
    (* Linia z CO JEST KURDE ma numer 0 - pierwsza linia użytkownika to 1 *)
    Lexing.set_position lexbuf { lexbuf.Lexing.lex_curr_p with Lexing.pos_lnum = 0 };
    try Ok (Some (Parser.program Lexer.token lexbuf)) with
    | Lexer.LexError msg -> Error ("Błąd leksera: Ktoś tu kłamie! " ^ msg)
    | Parser.Error ->
        (* Parser potknął się dopiero na doklejonym końcu programu = brakuje reszty instrukcji *)
        if Lexing.lexeme lexbuf = program_end then Ok None
        else Error ("Błąd parsowania. Jak ten Walduś w szkole!" ^ Syntax_errors.hint code "")
  in

  let rec loop buf =
    Printf.printf "%s" (if buf = "" then "(Ferdek)> " else "      ...> ");
    flush stdout;
    match read_line () with
    | exception End_of_file -> Printf.printf "\n"
    | line when buf = "" && List.mem (String.trim line) ["exit"; "quit"; "wypad"; "spadaj"] ->
        Printf.printf "Trzeba kończyć, robota czeka... (na kanapie)\n"
    | line when String.trim line = "" ->
        if buf <> "" then Printf.eprintf "Porzucam niedokończoną instrukcję.\n%!";
        loop ""
    | line ->
        let buf = if buf = "" then line else buf ^ "\n" ^ line in
        (match try_parse buf with
         | Ok None -> loop buf
         | Ok (Some ast) ->
             (match Interpreter.eval_in session ast with
              | Ok () -> ()
              | Error msg -> Printf.eprintf "Błąd: %s\n%!" msg);
             loop ""
         | Error msg -> Printf.eprintf "%s\n%!" msg; loop "")
  in
  loop ""

(* Main *)
let () =
  let argc = Array.length Sys.argv in
  
  if argc < 2 then begin
    print_help ();
    exit 0
  end;

  Interpreter.set_module_loader load_stdlib_module;

  let rec parse_args i mode output_file input_file =
    if i >= argc then
      (mode, output_file, input_file)
    else
      match Sys.argv.(i) with
      | "-h" | "--help" -> 
          print_help ();
          exit 0
      | "-v" | "--version" ->
          print_version ();
          exit 0
      | "nowy" when input_file = None && i = 1 ->
          if i + 1 >= argc then (Printf.eprintf "Użycie: ferdek nowy nazwa_projektu\n"; exit 1);
          exit (new_project Sys.argv.(i + 1))
      | "test" when input_file = None && i = 1 ->
          let dir = if i + 1 < argc then Sys.argv.(i + 1) else "." in
          exit (run_tests dir)
      | "--fmt" | "--fmt-check" as flag ->
          if i + 1 >= argc then (print_help (); exit 1);
          exit ((if flag = "--fmt" then fmt_file else fmt_check) Sys.argv.(i + 1))
      | "--check" ->
          if i + 1 >= argc then (print_help (); exit 1);
          parse_args (i + 2) `Check output_file (Some Sys.argv.(i + 1))
      | "--lsp" -> exit (Lsp.run ~diagnose ~find_module:find_module_file ())
      | "--debug" ->
          if i + 1 >= argc then (print_help (); exit 1);
          let file = Sys.argv.(i + 1) in
          (match parse_file file with
           | Error msg -> Printf.eprintf "A fe! %s\n" msg; exit 1
           | Ok prog ->
               Interpreter.set_module_loader load_stdlib_module;
               exit (Debugger.run ~main_file:file prog))
      | "--repl" ->
          parse_args (i + 1) `REPL output_file input_file
      | "-i" | "--interpret" ->
          if i + 1 >= argc then (print_help (); exit 1);
          parse_args (i + 2) `Interpret output_file (Some Sys.argv.(i + 1))
      | "-c" | "--compile" ->
          if i + 1 >= argc then (print_help (); exit 1);
          parse_args (i + 2) `Compile output_file (Some Sys.argv.(i + 1))
      | "-r" | "--run" ->
          if i + 1 >= argc then (print_help (); exit 1);
          parse_args (i + 2) `QuickRun output_file (Some Sys.argv.(i + 1))
      | "-o" ->
          if i + 1 >= argc then (print_help (); exit 1);
          parse_args (i + 2) mode (Some Sys.argv.(i + 1)) input_file
      | arg when input_file = None && not (String.starts_with ~prefix:"-" arg) ->
          parse_args (i + 1) mode output_file (Some arg)
      | _ ->
          Printf.eprintf "Nieznana opcja: %s. Ktoś tu oszukuje!\n\n" Sys.argv.(i);
          print_help ();
          exit 1
  in

  let mode, output_file, input_file = parse_args 1 `Interpret None None in
  Option.iter (fun f -> source_file_dir := Filename.dirname f) input_file;

  let exit_code = match mode with
  | `REPL ->
      repl ();
      0
  | `Interpret ->
      (match input_file with
       | None -> print_help (); 1
       | Some file -> interpret_file file)
  | `Compile ->
      (match input_file with
       | None -> print_help (); 1
       | Some file ->
           let output = match output_file with
             | Some f -> f
             | None -> (Filename.remove_extension file) ^ ".c"
           in
           compile_file file output)
  | `Check ->
      (match input_file with
       | None -> print_help (); 1
       | Some file -> check_file file)
  | `QuickRun ->
      (match input_file with
       | None -> print_help (); 1
       | Some file -> quick_run file)
  in
  exit exit_code
  
