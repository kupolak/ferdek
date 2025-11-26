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
      Error (Printf.sprintf "Tatooo… coś tu źle napisane jest w tym lekszeeerze: %s" msg)
  | Parser.Error ->
      close_in ic;
      let pos = lexbuf.Lexing.lex_curr_p in
      Error (Printf.sprintf
        "Tato… program się obraził i nie chce parsować. Linia %d, kolumna %d…"
        pos.Lexing.pos_lnum
        (pos.Lexing.pos_cnum - pos.Lexing.pos_bol))

(* Compile a file *)
let compile_file input_file output_file =
  match parse_file input_file with
  | Ok ast ->
      let c_code = Compiler.compile_program ast in
      let oc = open_out output_file in
      output_string oc c_code;
      close_out oc;
      Printf.printf "Tatooo, zrobiłem z %s taki plik %s, no działa chyba.\n"
        input_file output_file;
      Ok ()
  | Error msg ->
      Printf.eprintf "%s\n" msg;
      Error msg

(* Compile and link to executable *)
let compile_and_link input_file output_exe =
  let c_file = (Filename.remove_extension input_file) ^ ".c" in
  match compile_file input_file c_file with
  | Ok () ->
      let cmd = Printf.sprintf "gcc -o %s %s -std=c99" output_exe c_file in
      Printf.printf "No tatooo, teraz gcc-uję, tak jak Boczek mówił: %s\n" cmd;
      let exit_code = Sys.command cmd in
      if exit_code = 0 then begin
        Printf.printf "Taaatooo, gotowe! Masz ten programik: %s\n" output_exe;
        Ok ()
      end else begin
        Printf.eprintf "Tato… no nie wyszło. Gcc się wkurzył, kod: %d\n" exit_code;
        Error "Nie udało się, tato."
      end
  | Error msg -> Error msg

(* Compile, run and cleanup - like an interpreter *)
let compile_run_cleanup input_file =
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

        if run_exit = 0 then Ok ()
        else Error (Printf.sprintf "Tatooo… programik wyszedł z kodem %d" run_exit)
      end else begin
        (try Sys.remove temp_c with _ -> ());
        (try Sys.remove temp_exe with _ -> ());
        Error "Tatooo, kompilacja nie wyszła…"
      end
  | Error msg ->
      Printf.eprintf "%s\n" msg;
      Error msg

(* Usage message *)
let usage () =
  Printf.eprintf "Tatooo, to się tak używa: %s [opcje] <plik.ferdek>\n" Sys.argv.(0);
  Printf.eprintf "Opcje są proste, nawet Boczka byś nauczył:\n";
  Printf.eprintf "  -c            Kompilacja do C, tato. No C jak Czesio, no!\n";
  Printf.eprintf "  -o <wyjście>  Możesz nazwać plik jak chcesz, nawet \"paździoch.exe\".\n";
  Printf.eprintf "  -r, --run     Kompiluje i od razu uruchamia. \"Nie kombinuj, Walduś!\"\n";
  Printf.eprintf "  -h, --help    Pomoc. \"Walduś, przeczytaj ojcu…\"\n";
  Printf.eprintf "\n";
  Printf.eprintf "Domyślnie robi plik wykonywalny o tej samej nazwie. Normalka.\n";
  Printf.eprintf "\"A jak jest napisane, to trzeba czytać, Walduś!\" — F. Kiepski\n";
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

  let compile_only, run_mode, output_file, input_file =
    parse_args 1 false false None None
  in

  match input_file with
  | None -> usage ()
  | Some input ->
      let result =
        if run_mode then
          compile_run_cleanup input
        else if compile_only then
          let output = match output_file with
            | Some f -> f
            | None -> (Filename.remove_extension input) ^ ".c"
          in
          compile_file input output
        else
          let output = match output_file with
            | Some f -> f
            | None -> Filename.remove_extension input
          in
          compile_and_link input output
      in
      match result with
      | Ok () -> exit 0
      | Error _ -> exit 1
