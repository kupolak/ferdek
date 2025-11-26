(* Ferdek Compiler - compiles .ferdek files to C *)

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

(* Compile a file *)
let compile_file input_file output_file =
  match parse_file input_file with
  | Ok ast ->
      let c_code = Compiler.compile_program ast in
      let oc = open_out output_file in
      output_string oc c_code;
      close_out oc;
      Printf.printf "Compiled %s -> %s\n" input_file output_file;
      Ok ()
  | Error msg ->
      Printf.eprintf "%s\n" msg;
      Error msg

(* Compile and link to executable *)
let compile_and_link input_file output_exe =
  let c_file = (Filename.remove_extension input_file) ^ ".c" in
  match compile_file input_file c_file with
  | Ok () ->
      (* Compile C file with gcc *)
      let cmd = Printf.sprintf "gcc -o %s %s -std=c99" output_exe c_file in
      Printf.printf "Compiling C code: %s\n" cmd;
      let exit_code = Sys.command cmd in
      if exit_code = 0 then begin
        Printf.printf "Successfully created executable: %s\n" output_exe;
        Ok ()
      end else begin
        Printf.eprintf "C compilation failed with exit code %d\n" exit_code;
        Error "C compilation failed"
      end
  | Error msg -> Error msg

(* Compile, run and cleanup - like an interpreter *)
let compile_run_cleanup input_file =
  match parse_file input_file with
  | Ok ast ->
      let c_code = Compiler.compile_program ast in

      (* Create temporary files *)
      let temp_c = Filename.temp_file "ferdek_" ".c" in
      let temp_exe = Filename.temp_file "ferdek_" "" in

      (* Write C code to temp file *)
      let oc = open_out temp_c in
      output_string oc c_code;
      close_out oc;

      (* Compile to executable *)
      let compile_cmd = Printf.sprintf "gcc -o %s %s -std=c99 2>/dev/null" temp_exe temp_c in
      let compile_exit = Sys.command compile_cmd in

      if compile_exit = 0 then begin
        (* Run the executable *)
        let run_exit = Sys.command temp_exe in

        (* Cleanup temp files *)
        (try Sys.remove temp_c with _ -> ());
        (try Sys.remove temp_exe with _ -> ());

        if run_exit = 0 then Ok ()
        else Error (Printf.sprintf "Program exited with code %d" run_exit)
      end else begin
        (* Cleanup on compile error *)
        (try Sys.remove temp_c with _ -> ());
        (try Sys.remove temp_exe with _ -> ());
        Error "Compilation failed"
      end
  | Error msg ->
      Printf.eprintf "%s\n" msg;
      Error msg

(* Usage message *)
let usage () =
  Printf.eprintf "Usage: %s [options] <input.ferdek>\n" Sys.argv.(0);
  Printf.eprintf "Options:\n";
  Printf.eprintf "  -c            Compile to C only (default: <input>.c)\n";
  Printf.eprintf "  -o <output>   Output file name (for compile mode)\n";
  Printf.eprintf "  -r, --run     Compile and run immediately (no files left behind)\n";
  Printf.eprintf "  -h, --help    Show this help\n";
  Printf.eprintf "\n";
  Printf.eprintf "Default mode: compile to executable with same name as input\n";
  exit 1

(* Main entry point *)
let () =
  let argc = Array.length Sys.argv in

  if argc < 2 then
    usage ();

  let rec parse_args i compile_only run_mode output_file input_file =
    if i >= argc then
      (compile_only, run_mode, output_file, input_file)
    else
      match Sys.argv.(i) with
      | "-c" -> parse_args (i + 1) true false output_file input_file
      | "-r" | "--run" -> parse_args (i + 1) false true output_file input_file
      | "-o" ->
          if i + 1 >= argc then usage ();
          parse_args (i + 2) compile_only run_mode (Some Sys.argv.(i + 1)) input_file
      | "-h" | "--help" -> usage ()
      | arg when input_file = None ->
          parse_args (i + 1) compile_only run_mode output_file (Some arg)
      | _ -> usage ()
  in

  let compile_only, run_mode, output_file, input_file = parse_args 1 false false None None in

  match input_file with
  | None -> usage ()
  | Some input ->
      let result =
        if run_mode then
          (* Run mode: compile, execute, cleanup *)
          compile_run_cleanup input
        else if compile_only then
          (* Compile to C only *)
          let output = match output_file with
            | Some f -> f
            | None -> (Filename.remove_extension input) ^ ".c"
          in
          compile_file input output
        else
          (* Compile to executable *)
          let output = match output_file with
            | Some f -> f
            | None -> Filename.remove_extension input
          in
          compile_and_link input output
      in
      match result with
      | Ok () -> exit 0
      | Error _ -> exit 1
