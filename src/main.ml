(* Ferdek - główna komenda CLI *)

(* Wyświetla help *)
let print_help () =
  Printf.printf "Ferdek Programming Language v1.0\n\n";
  Printf.printf "Usage: ferdek [opcje] [plik.ferdek]\n\n";
  Printf.printf "Opcje:\n";
  Printf.printf "  -h, --help              Wyświetla tę pomoc\n";
  Printf.printf "  -v, --version           Wyświetla wersję języka Ferdek\n";
  Printf.printf "  -i, --interpret <plik>  Interpretuje plik .ferdek (domyślnie)\n";
  Printf.printf "  -c, --compile <plik>    Kompiluje plik .ferdek do C\n";
  Printf.printf "  -o <wyjście>            Określa nazwę pliku wyjściowego\n";
  Printf.printf "  -r, --run               Kompiluje i uruchamia (tryb quick run)\n";
  Printf.printf "  --repl                  Uruchamia interaktywny REPL\n\n";
  Printf.printf "Przykłady:\n";
  Printf.printf "  ferdek program.ferdek           # Interpretuje program\n";
  Printf.printf "  ferdek --compile program.ferdek # Kompiluje do C\n";
  Printf.printf "  ferdek -c program.ferdek -o app # Kompiluje do wykonywalnego 'app'\n";
  Printf.printf "  ferdek --run program.ferdek     # Szybkie uruchomienie przez kompilację\n";
  Printf.printf "  ferdek --repl                   # Tryb interaktywny\n\n";
  Printf.printf "Więcej informacji: https://github.com/kupolak/ferdek\n"

(* Wyświetla wersję *)
let print_version () =
  Printf.printf "Ferdek Programming Language v1.0\n";
  Printf.printf "\"CO JEST KURDE\" - język dla prawdziwych Polaków\n"

(* Parse a file *)
let parse_file filename =
  let ic = open_in filename in
  let lexbuf = Lexing.from_channel ic in
  lexbuf.Lexing.lex_curr_p <- {
    lexbuf.Lexing.lex_curr_p with
    Lexing.pos_fname = filename
  };
  try
    let ast = Parser.program Lexer.token lexbuf in
    close_in ic;
    Ok ast
  with
  | Lexer.LexError msg ->
      close_in ic;
      Error (Printf.sprintf "Błąd leksera w %s: %s" filename msg)
  | Parser.Error ->
      close_in ic;
      let pos = lexbuf.Lexing.lex_curr_p in
      Error (Printf.sprintf "Błąd parsowania w %s, linia %d, kolumna %d"
              filename pos.Lexing.pos_lnum
              (pos.Lexing.pos_cnum - pos.Lexing.pos_bol))

(* Interpretuje plik *)
let interpret_file filename =
  match parse_file filename with
  | Ok ast ->
      (match Interpreter.eval_program ast with
       | Ok () -> 
           Printf.printf "Program zakończony pomyślnie.\n";
           0
       | Error msg ->
           Printf.eprintf "Błąd wykonania: %s\n" msg;
           1)
  | Error msg ->
      Printf.eprintf "%s\n" msg;
      1

(* Kompiluje plik do C *)
let compile_file input_file output_file =
  match parse_file input_file with
  | Ok ast ->
      let c_code = Compiler.compile_program ast in
      let oc = open_out output_file in
      output_string oc c_code;
      close_out oc;
      Printf.printf "Skompilowano %s -> %s\n" input_file output_file;
      0
  | Error msg ->
      Printf.eprintf "%s\n" msg;
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
      Printf.printf "Kompilowanie: %s\n" cmd;
      let exit_code = Sys.command cmd in
      if exit_code = 0 then begin
        Printf.printf "Sukces! Utworzono: %s\n" output_exe;
        0
      end else begin
        Printf.eprintf "Błąd kompilacji gcc (kod: %d)\n" exit_code;
        1
      end
  | Error msg ->
      Printf.eprintf "%s\n" msg;
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
        Printf.eprintf "Błąd kompilacji\n";
        1
      end
  | Error msg ->
      Printf.eprintf "%s\n" msg;
      1

(* REPL *)
let repl () =
  Printf.printf "Ferdek REPL v1.0\n";
  Printf.printf "Wpisz 'exit' aby wyjść\n\n";

  let rec loop () =
    Printf.printf "> ";
    flush stdout;
    try
      let line = read_line () in
      if line = "exit" || line = "quit" then
        ()
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
        | Lexer.LexError msg -> Printf.eprintf "Błąd leksera: %s\n" msg
        | Parser.Error -> Printf.eprintf "Błąd parsowania\n");
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
          Printf.eprintf "Nieznana opcja: %s\n\n" Sys.argv.(i);
          print_help ();
          exit 1
  in

  let mode, output_file, input_file = parse_args 1 `Interpret None None in

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
