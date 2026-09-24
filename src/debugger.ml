(* ferdek --debug: zatrzymywanie przed instrukcjami, krok po kroku, podgląd zmiennych.
   Działa na interpreterze (Value.stmt_hook); polecenia czyta ze standardowego wejścia. *)

open Value

type mode =
  | Step              (* k: zatrzymaj przed następną instrukcją, także w wołanej funkcji *)
  | Next of int       (* n: następna instrukcja na tym samym (albo płytszym) poziomie wywołań *)
  | Finish of int     (* w: aż funkcja wróci *)
  | Run               (* c: do punktu zatrzymania *)

let help = {|Polecenia (Enter powtarza ostatnie):
  k            krok - następna instrukcja, także wewnątrz wołanej funkcji
  n            następna instrukcja w tej funkcji (wywołania bez zatrzymywania)
  w            wyjdź z bieżącej funkcji
  c            jedź do najbliższego punktu zatrzymania
  b 12         punkt zatrzymania w linii 12 (b plik.ferdek:12 - w innym pliku)
  u 12         usuń punkt zatrzymania
  p wyrażenie  pokaż wartość, np. p licznik BABKA DAWAJ RENTĘ 1
  z            zmienne (lokalne i globalne)
  g            gdzie jestem - ścieżka wywołań
  l            kod wokół bieżącej linii
  q            przerwij program
  h            ta pomoc
|}

exception Quit

(* Wyrażenie wpisane w debuggerze -> AST: parsujemy je jako PANIE SENSACJA REWELACJA wyrażenie *)
let parse_expr text =
  let code = "CO JEST KURDE\nPANIE SENSACJA REWELACJA " ^ text ^ "\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE\n" in
  match Parser.program Lexer.token (Lexing.from_string code) with
  | { Ast.declarations = [Ast.Statement (Ast.Located (_, _, Ast.Print e))] } -> Some e
  | _ -> None
  | exception _ -> None

let show_line file line =
  match Sources.line file line with
  | Some l -> Printf.printf "%s:%d  %s\n%!" (Filename.basename file) line l
  | None -> Printf.printf "%s:%d\n%!" (Filename.basename file) line

let list_around file line =
  for l = max 1 (line - 3) to line + 3 do
    match Sources.line file l with
    | Some text -> Printf.printf "%s%4d  %s\n" (if l = line then "->" else "  ") l text
    | None -> ()
  done;
  flush stdout

let print_vars env =
  let show title tbl =
    let vars = Hashtbl.fold (fun n v acc ->
      match v with
      | VFunction _ | VClass _ | VStruct _ | VUnion _ | VEnum _ -> acc
      | _ when n = lambda_marker -> acc
      | _ -> (n, v) :: acc) tbl [] |> List.sort compare in
    if vars <> [] then begin
      Printf.printf "%s:\n" title;
      List.iter (fun (n, v) -> Printf.printf "  %s = %s\n" n (string_of_value v)) vars
    end in
  let rec root e = match e.parent with Some p -> root p | None -> e in
  let g = root env in
  if env != g then show "lokalne" env.vars;
  show "globalne" g.vars;
  flush stdout

let run ~main_file prog =
  let breakpoints = Hashtbl.create 8 in
  let mode = ref Step in
  let last = ref "k" in
  let interactive = ref true in
  let depth () = List.length !call_stack in
  let bp_key spec =
    match String.rindex_opt spec ':' with
    | Some i -> (String.sub spec 0 i, int_of_string_opt (String.sub spec (i + 1) (String.length spec - i - 1)))
    | None -> (main_file, int_of_string_opt spec) in
  let matches_bp file line =
    Hashtbl.fold (fun (f, l) () acc -> acc || (l = line && (f = file || Filename.basename f = Filename.basename file)))
      breakpoints false in
  let hook file line env =
    let stop = !interactive && (matches_bp file line || match !mode with
      | Step -> true
      | Next d -> depth () <= d
      | Finish d -> depth () < d
      | Run -> false) in
    if stop then begin
      show_line file line;
      let rec prompt () =
        print_string "(ferdek) "; flush stdout;
        match In_channel.input_line stdin with
        | None -> interactive := false   (* koniec wejścia: program jedzie dalej bez zatrzymań *)
        | Some input ->
            let input = String.trim input in
            let input = if input = "" then !last else input in
            last := input;
            let cmd, arg = match String.index_opt input ' ' with
              | Some i -> String.sub input 0 i, String.trim (String.sub input i (String.length input - i))
              | None -> input, "" in
            match cmd with
            | "k" -> mode := Step
            | "n" -> mode := Next (depth ())
            | "w" -> mode := Finish (depth ())
            | "c" -> mode := Run
            | "q" -> raise Quit
            | "b" | "u" ->
                (match bp_key arg with
                 | f, Some l ->
                     if cmd = "b" then (Hashtbl.replace breakpoints (f, l) ();
                                        Printf.printf "Punkt zatrzymania: %s:%d\n" (Filename.basename f) l)
                     else (Hashtbl.remove breakpoints (f, l);
                           Printf.printf "Usunięty: %s:%d\n" (Filename.basename f) l)
                 | _ -> print_endline "Podaj linię, np. b 12");
                prompt ()
            | "p" ->
                (match parse_expr arg with
                 | None -> print_endline "Nie rozumiem tego wyrażenia"
                 | Some e ->
                     (try print_endline (string_of_value (Eval.eval_expr env e))
                      with RuntimeError msg -> print_endline ("Błąd: " ^ msg)));
                prompt ()
            | "z" -> print_vars env; prompt ()
            | "g" ->
                if !call_stack = [] then print_endline "Program główny"
                else List.iter (fun (name, (_, l)) ->
                  Printf.printf "  w funkcji %s, wywołanej w linii %d\n" name l) !call_stack;
                prompt ()
            | "l" -> list_around file line; prompt ()
            | "h" | "?" -> print_string help; prompt ()
            | _ -> print_endline "Nie znam polecenia - h pokaże listę"; prompt () in
      prompt ()
    end in
  Printf.printf "Debugger Ferdka - h pokaże polecenia. Zatrzymuję się przed pierwszą instrukcją.\n%!";
  stmt_hook := Some hook;
  let result = try Some (Interpreter.eval_program prog) with Quit -> None in
  stmt_hook := None;
  match result with
  | None -> print_endline "Przerwane."; 0
  | Some (Ok ()) -> print_endline "Program zakończony pomyślnie. Piwo dla Pana!"; 0
  | Some (Error msg) ->
      Printf.eprintf "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: %s\n%s%!" msg (Interpreter.error_context ());
      1
