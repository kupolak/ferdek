(* Ferdek - główna komenda CLI *)

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
        if Sys.file_exists dir && Sys.is_directory dir then
          Some dir
        else
          find_first rest
  in
  find_first candidates

(* Wyświetla help *)
let print_help () =
  Printf.printf "Ferdek - Język Biedy i Zjednoczenia Narodowego v1.0\n\n";
  Printf.printf "Jak uruchomić, żeby nie było wstydu: ferdek [opcje] [plik.ferdek]\n\n";
  Printf.printf "Opcje:\n";
  Printf.printf "  -h, --help              Pytaj o pomoc. Ferdek jest bezrobotny i ma czas.\n";
  Printf.printf "  -v, --version           Sprawdza, czy to jest już ta nowa, lepsza Polska.\n";
  Printf.printf "  -i, --interpret <plik>  Odpal na szybko, bez zbędnych ceregieli (standard).\n";
  Printf.printf "  -c, --compile <plik>    Rób karierę, kompiluj do C (dla ambitnych, jak Paździoch).\n";
  Printf.printf "  -o <wyjście>            Gdzie to schować, żeby Halina nie znalazła? (Plik wyjściowy)\n";
  Printf.printf "  -r, --run               Szybki szlag! Kompiluj i odpal (tryb testowy).\n";
  Printf.printf "  --repl                  Pogadaj sobie z Ferdkiem (tryb interaktywny).\n\n";

  Printf.printf "Przykłady (A niech to dunder świśnie!):\n";
  Printf.printf "  ferdek program.ferdek           # Idziemy na łatwiznę, odpalamy program!\n";
  Printf.printf "  ferdek --compile program.ferdek # Generujemy ten kod C (dla zarobku).\n";
  Printf.printf "  ferdek -c program.ferdek -o app # Budujemy 'apkę' (Paździoch sprzeda to na bazarku).\n";
  Printf.printf "  ferdek --run program.ferdek     # Testujemy na prędko, czy działa piwo.\n";
  Printf.printf "  ferdek --repl                   # Czas na filozoficzne rozmowy o życiu.\n\n";
  Printf.printf "Więcej głupot (i dokumentacji): https://github.com/kupolak/ferdek\n"

(* Wyświetla wersję *)
let print_version () =
  Printf.printf "Ferdek - Język Prawdziwych Polaków v1.0\n";
  Printf.printf "Nie ma pracy dla ludzi z naszym wykształceniem! / Walduś, to jest język!\n"

(* Parse a file *)
let parse_file filename =
  try
    (* Step 1: Preprocess the file *)
    let preprocessed_lines = Preprocessor.preprocess_file filename in
    let preprocessed_content = String.concat "\n" preprocessed_lines in

    (* Step 2: Parse the preprocessed content *)
    let lexbuf = Lexing.from_string preprocessed_content in
    lexbuf.Lexing.lex_curr_p <- {
      lexbuf.Lexing.lex_curr_p with
      Lexing.pos_fname = filename
    };
    (try Ok (Parser.program Lexer.token lexbuf)
     with Parser.Error ->
       let p = lexbuf.Lexing.lex_start_p in
       Error (Printf.sprintf "Błąd Parsowania! Walduś, coś tu jest pokręcone! W %s, linia %d, kolumna %d, przy '%s'"
                filename p.Lexing.pos_lnum (p.Lexing.pos_cnum - p.Lexing.pos_bol + 1) (Lexing.lexeme lexbuf)))
  with
  | Lexer.LexError msg ->
      Error (Printf.sprintf "Błąd Leksera! Ktoś tu namieszał w słowach! W %s: %s (Paździoch ukradł słowa)." filename msg)
  | Failure msg ->
      Error (Printf.sprintf "Błąd Preprocesora w %s: %s" filename msg)
  | Sys_error msg ->
      Error (Printf.sprintf "Nie ma takiego pliku, Paździoch go zajumał: %s" msg)

(* Module loader for stdlib *)
let load_stdlib_module module_name =
  (* Try to find module in stdlib *)
  let try_load_from_path module_path =
    if Sys.file_exists module_path then begin
      match parse_file module_path with
      | Ok ast -> Some ast
      | Error msg ->
          Printf.eprintf "Error parsing module %s: %s\n" module_name msg;
          None
    end else
      None
  in
  match find_stdlib_dir () with
  | Some stdlib_dir ->
      (* First, check if it's a direct module name like "BABKA" - look in KLAMOTY/<name>/<name>.ferdek *)
      let direct_path = Filename.concat (Filename.concat (Filename.concat stdlib_dir "KLAMOTY") module_name) (module_name ^ ".ferdek") in
      (match try_load_from_path direct_path with
      | Some ast -> Some ast
      | None ->
          (* Then check KLAMOTY/<name>.ferdek for simple modules *)
          let simple_path = Filename.concat (Filename.concat stdlib_dir "KLAMOTY") (module_name ^ ".ferdek") in
          (match try_load_from_path simple_path with
          | Some ast -> Some ast
          | None ->
              (* Finally, check if it starts with KLAMOTY/ prefix *)
              if String.length module_name > 8 && String.sub module_name 0 8 = "KLAMOTY/" then
                let stdlib_module = String.sub module_name 8 (String.length module_name - 8) in
                let prefixed_path = Filename.concat (Filename.concat stdlib_dir "KLAMOTY") (stdlib_module ^ ".ferdek") in
                (match try_load_from_path prefixed_path with
                | Some ast -> Some ast
                | None -> None)
              else None))
  | None ->
      None

(* Interpretuje plik *)
let interpret_file filename =
  match parse_file filename with
  | Ok ast ->
      (match Interpreter.eval_program ast with
       | Ok () -> 
           Printf.printf "Program zakończony pomyślnie. Piwo dla Pana!\n";
           0
       | Error msg ->
           Printf.eprintf "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: %s\n" msg;
           1)
  | Error msg ->
      Printf.eprintf "A fe! %s\n" msg;
      1

(* Kompiluje plik do C *)
let compile_file input_file output_file =
  match parse_file input_file with
  | Ok ast ->
      let c_code = Compiler.compile_program ast in
      let oc = open_out output_file in
      output_string oc c_code;
      close_out oc;
      Printf.printf "No i gitara! Kod C gotowy: %s -> %s\n" input_file output_file;
      0
  | Error msg ->
      Printf.eprintf "A fe! %s\n" msg;
      1

(* Kompiluje i linkuje do executable *)
let compile_and_link input_file output_exe =
  let c_file = (Filename.remove_extension input_file) ^ ".c" in
  match parse_file input_file with
  | Ok ast ->
      let c_code = Compiler.compile_program ast in
      let oc = open_out c_file in
      output_string oc c_code;
      close_out oc;
      
      let cmd = Printf.sprintf "gcc -o %s %s -std=c99" output_exe c_file in
      Printf.printf "No to jazda! Kręcimy to C: %s\n" cmd;
      let exit_code = Sys.command cmd in
      if exit_code = 0 then begin
        Printf.printf "Sukces! Działa! Halina, mam pieniądze! (Plik: %s)\n" output_exe;
        0
      end else begin
        Printf.eprintf "Błąd kompilacji gcc. A żeby cię Babka pokręciła! (Kod: %d)\n" exit_code;
        1
      end
  | Error msg ->
      Printf.eprintf "A fe! %s\n" msg;
      1

(* Kompiluje, uruchamia i czyści *)
let quick_run input_file =
  match parse_file input_file with
  | Ok ast ->
      let c_code = Compiler.compile_program ast in
      let temp_c = Filename.temp_file "ferdek_" ".c" in
      let temp_exe = Filename.temp_file "ferdek_" "" in

      let oc = open_out temp_c in
      output_string oc c_code;
      close_out oc;

      let compile_cmd = Printf.sprintf "gcc -o %s %s -std=c99 2>/dev/null"
        temp_exe temp_c in

      let compile_exit = Sys.command compile_cmd in

      if compile_exit = 0 then begin
        let run_exit = Sys.command temp_exe in
        (try Sys.remove temp_c with _ -> ());
        (try Sys.remove temp_exe with _ -> ());
        run_exit
      end else begin
        (try Sys.remove temp_c with _ -> ());
        (try Sys.remove temp_exe with _ -> ());
        Printf.eprintf "Błąd kompilacji. Nawet szybki szlag się nie udał...\n";
        1
      end
  | Error msg ->
      Printf.eprintf "A fe! %s\n" msg;
      1

(* REPL *)
let repl () =
  Printf.printf "Ferdek REPL - Gadka Szmatka v1.0\n";
  Printf.printf "Wpisz 'wypad' albo 'spadaj' aby iść na piwo (exit/quit)\n\n";

  let rec loop () =
    Printf.printf "(Ferdek)> "; (* Zmieniony prompt *)
    flush stdout;
    try
      let line = read_line () in
      if line = "exit" || line = "quit" || line = "wypad" || line = "spadaj" then
        Printf.printf "Trzeba kończyć, robota czeka... (na kanapie)\n"
      else if String.trim line = "" then
        loop ()
      else begin
        let code = "CO JEST KURDE\n" ^ line ^ "\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE" in
        let lexbuf = Lexing.from_string code in
        (try
          let ast = Parser.program Lexer.token lexbuf in
          (match Interpreter.eval_program ast with
           | Ok () -> ()
           | Error msg -> Printf.eprintf "Błąd: %s\n" msg)
        with
        | Lexer.LexError msg -> Printf.eprintf "Błąd leksera: Ktoś tu kłamie! %s\n" msg
        | Parser.Error -> Printf.eprintf "Błąd parsowania. Jak ten Walduś w szkole!\n");
        loop ()
      end
    with End_of_file ->
      Printf.printf "\n"
  in
  loop ()

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
  | `QuickRun ->
      (match input_file with
       | None -> print_help (); 1
       | Some file -> quick_run file)
  in
  exit exit_code
  
