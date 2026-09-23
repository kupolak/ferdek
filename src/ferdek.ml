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
        (* Samo "stdlib" nie wystarczy - np. tests/integration/stdlib to katalog testów *)
        if Sys.file_exists (Filename.concat dir "KLAMOTY") then
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
  Printf.printf "  --check <plik>          Sprawdź bez uruchamiania: nieznane zmienne, funkcje, liczba argumentów.\n";
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

(* Import lokalny: jeśli obok pliku leży <nazwa>.ferdek, import dostaje ścieżkę do niego.
   Dzięki temu zagnieżdżone importy liczą się od pliku, który importuje. *)
let resolve_local_imports filename (prog : Ast.program) =
  let dir = Filename.dirname filename in
  { Ast.declarations = List.map (function
      | Ast.Import name ->
          let path = Filename.concat dir (name ^ ".ferdek") in
          if Sys.file_exists path then Ast.Import path else Ast.Import name
      | d -> d) prog.declarations }

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
    (try Ok (resolve_local_imports filename (Parser.program Lexer.token lexbuf))
     with Parser.Error ->
       let p = lexbuf.Lexing.lex_start_p in
       Error (Printf.sprintf "Błąd Parsowania! Walduś, coś tu jest pokręcone! W %s, linia %d, kolumna %d, przy '%s'.%s"
                filename p.Lexing.pos_lnum (p.Lexing.pos_cnum - p.Lexing.pos_bol + 1) (Lexing.lexeme lexbuf)
                (Syntax_errors.hint preprocessed_content filename)))
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
  (* Ścieżka do pliku użytkownika (z resolve_local_imports) ma pierwszeństwo przed stdlib *)
  if Filename.check_suffix module_name ".ferdek" && Sys.file_exists module_name then
    try_load_from_path module_name
  else
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
  Sys.command (Printf.sprintf "cc -std=c99 -o %s %s -lm%s" (Filename.quote exe) (Filename.quote c_file) x11)

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
  Printf.printf "Ferdek REPL - Gadka Szmatka v1.0\n";
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
      | "--check" ->
          if i + 1 >= argc then (print_help (); exit 1);
          parse_args (i + 2) `Check output_file (Some Sys.argv.(i + 1))
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
  
