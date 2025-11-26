(* Main Ferdek interpreter program *)

(* Find stdlib directory *)
let find_stdlib_dir () =
  let candidates = [
    "./stdlib";
    "../stdlib";
    "../../stdlib";
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
      Error (Printf.sprintf "Lexer error in %s: %s" filename msg)
  | Parser.Error ->
      close_in ic;
      let pos = lexbuf.Lexing.lex_curr_p in
      Error (Printf.sprintf "Parse error in %s at line %d, column %d"
              filename pos.Lexing.pos_lnum
              (pos.Lexing.pos_cnum - pos.Lexing.pos_bol))

(* Parse a string *)
let parse_string str =
  let lexbuf = Lexing.from_string str in
  try
    let ast = Parser.program Lexer.token lexbuf in
    Ok ast
  with
  | Lexer.LexError msg ->
      Error (Printf.sprintf "Lexer error: %s" msg)
  | Parser.Error ->
      Error "Parse error"

(* Run a file *)
let run_file filename =
  match parse_file filename with
  | Ok ast ->
      (match Interpreter.eval_program ast with
       | Ok () -> 0
       | Error msg ->
           Printf.eprintf "%s\n" msg;
           1)
  | Error msg ->
      Printf.eprintf "%s\n" msg;
      1

(* Run a string *)
let run_string str =
  match parse_string str with
  | Ok ast ->
      (match Interpreter.eval_program ast with
       | Ok () -> 0
       | Error msg ->
           Printf.eprintf "%s\n" msg;
           1)
  | Error msg ->
      Printf.eprintf "%s\n" msg;
      1

(* Interactive REPL *)
let repl () =
  print_endline "Ferdek Programming Language Interpreter";
  print_endline "Type 'exit' to quit";
  print_newline ();

  let rec loop () =
    print_string "> ";
    flush stdout;
    try
      let line = read_line () in
      if line = "exit" || line = "quit" then
        ()
      else if String.trim line = "" then
        loop ()
      else
        let code = "CO JEST KURDE\n" ^ line ^ "\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE" in
        let _ = run_string code in
        loop ()
    with End_of_file ->
      print_newline ()
  in
  loop ()

(* Module loader for stdlib *)
let load_stdlib_module module_name =
  if String.length module_name > 8 && String.sub module_name 0 8 = "KLAMOTY/" then
    let stdlib_module = String.sub module_name 8 (String.length module_name - 8) in
    match find_stdlib_dir () with
    | Some stdlib_dir ->
        let module_path = Filename.concat (Filename.concat stdlib_dir "KLAMOTY") (stdlib_module ^ ".ferdek") in
        if Sys.file_exists module_path then begin
          Printf.printf "Loading stdlib module: %s\n" module_name;
          match parse_file module_path with
          | Ok ast -> Some ast
          | Error msg ->
              Printf.eprintf "Error parsing module %s: %s\n" module_name msg;
              None
        end else begin
          Printf.eprintf "Module not found: %s (searched: %s)\n" module_name module_path;
          None
        end
    | None ->
        Printf.eprintf "Cannot find stdlib directory for module: %s\n" module_name;
        None
  else
    None

(* Main entry point *)
let () =
  (* Set up module loader *)
  Interpreter.set_module_loader load_stdlib_module;

  let argc = Array.length Sys.argv in
  if argc < 2 then begin
    repl ()
  end else begin
    let filename = Sys.argv.(1) in
    exit (run_file filename)
  end
