(* ferdek --dap: Debug Adapter Protocol (VS Code i inne edytory) na stdin/stdout.
   Silnik jak w --debug (Value.stmt_hook). stdout należy do protokołu, więc to, co wypisuje
   program, idzie do pliku tymczasowego i trafia do edytora jako zdarzenia "output".
   CO TAM U PANA SŁYCHAĆ czyta z "input" (tekst) albo "inputFile" z konfiguracji uruchomienia -
   stdin to protokół. *)

open Value

type mode = Step | Next of int | Finish of int | Run

let out = ref stdout   (* kanał protokołu (kopia prawdziwego stdout) *)
let seq = ref 0

let send json =
  incr seq;
  let json = match json with `Assoc l -> `Assoc (("seq", `Int !seq) :: l) | j -> j in
  let body = Yojson.Safe.to_string json in
  Printf.fprintf !out "Content-Length: %d\r\n\r\n%s%!" (String.length body) body

let event name body = send (`Assoc ["type", `String "event"; "event", `String name; "body", body])
let respond req ?(body = `Assoc []) ok =
  let open Yojson.Safe.Util in
  send (`Assoc ["type", `String "response"; "request_seq", req |> member "seq";
                "command", req |> member "command"; "success", `Bool ok; "body", body])

let read_message () =
  let rec headers len =
    match input_line stdin with
    | exception End_of_file -> None
    | l ->
        let l = String.trim l in
        if l = "" then (match len with Some n -> Some n | None -> headers None)
        else match String.split_on_char ':' l with
          | [k; v] when String.lowercase_ascii (String.trim k) = "content-length" ->
              headers (int_of_string_opt (String.trim v))
          | _ -> headers len in
  Option.bind (headers None) (fun n ->
    match really_input_string stdin n with
    | s -> (try Some (Yojson.Safe.from_string s) with _ -> None)
    | exception End_of_file -> None)

(* Wyjście programu: plik zamiast stdout; nowe bajty wysyłamy jako zdarzenia output *)
let capture_file = Filename.temp_file "ferdek_dap" ".out"
let () = at_exit (fun () -> try Sys.remove capture_file with Sys_error _ -> ())
let sent = ref 0
let flush_output () =
  flush stdout;
  let text = In_channel.with_open_bin capture_file In_channel.input_all in
  if String.length text > !sent then begin
    event "output" (`Assoc ["category", `String "stdout";
                            "output", `String (String.sub text !sent (String.length text - !sent))]);
    sent := String.length text
  end

let run ~parse ~load_module () =
  set_binary_mode_in stdin true;
  let proto_fd = Unix.dup Unix.stdout in
  out := Unix.out_channel_of_descr proto_fd;
  set_binary_mode_out !out true;
  let fd = Unix.openfile capture_file [Unix.O_WRONLY; Unix.O_TRUNC; Unix.O_CREAT] 0o600 in
  Unix.dup2 fd Unix.stdout;
  Unix.close fd;
  let open Yojson.Safe.Util in
  let breakpoints : (string, int list) Hashtbl.t = Hashtbl.create 8 in
  let program = ref None in
  let mode = ref Step and stop_on_entry = ref false in
  let depth () = List.length !call_stack in
  let norm f = try Unix.realpath f with _ -> f in
  let has_bp file line =
    match Hashtbl.find_opt breakpoints (norm file) with Some ls -> List.mem line ls | None -> false in
  let current_env = ref None in
  (* ramki: od najgłębszej - (nazwa, plik, linia) *)
  let frames () =
    let names = List.map fst !call_stack @ ["program"] in
    let locs = current_loc () :: List.map snd !call_stack in
    List.map2 (fun n (f, l) -> (n, f, l)) names locs in
  let vars_of e =
    List.filter (fun (n, v) -> match v with
      | VFunction _ | VClass _ | VStruct _ | VUnion _ | VEnum _ -> false
      | _ -> n <> lambda_marker) (local_bindings e) |> List.sort compare
    |> List.map (fun (n, v) -> `Assoc ["name", `String n; "value", `String (string_of_value v);
                                        "variablesReference", `Int 0]) in
  let rec root e = match e.parent with Some p -> root p | None -> e in
  (* Obsługa jednej prośby; true = program ma ruszyć dalej *)
  let handle req =
    let args = req |> member "arguments" in
    match req |> member "command" |> to_string with
    | "initialize" ->
        respond req true ~body:(`Assoc ["supportsConfigurationDoneRequest", `Bool true;
                                        "supportsEvaluateForHovers", `Bool true]);
        event "initialized" (`Assoc []); false
    | "launch" ->
        let path = args |> member "program" |> to_string in
        stop_on_entry := (try args |> member "stopOnEntry" |> to_bool with _ -> false);
        (* wejście programu: tekst albo plik; bez nich CO TAM U PANA SŁYCHAĆ zgłasza błąd *)
        let input = match args |> member "input", args |> member "inputFile" with
          | `String s, _ -> Some s
          | _, `String f -> (try Some (In_channel.with_open_bin f In_channel.input_all) with Sys_error _ -> None)
          | _ -> None in
        let lines = ref (match input with
          | Some "" | None -> []
          | Some s -> String.split_on_char '\n' (if String.ends_with ~suffix:"\n" s then String.sub s 0 (String.length s - 1) else s)) in
        read_input := (fun () ->
          if input = None then
            raise (RuntimeError "CO TAM U PANA SŁYCHAĆ: w debuggerze podaj wejście w konfiguracji (\"input\" albo \"inputFile\")");
          match !lines with
          | l :: rest -> lines := rest; l
          | [] -> raise End_of_file);
        (match parse path with
         | Ok prog -> program := Some prog; respond req true
         | Error msg ->
             event "output" (`Assoc ["category", `String "stderr"; "output", `String (msg ^ "\n")]);
             respond req false);
        false
    | "setBreakpoints" ->
        let path = norm (args |> member "source" |> member "path" |> to_string) in
        let lines = try args |> member "breakpoints" |> to_list |> List.map (fun b -> b |> member "line" |> to_int)
                    with _ -> [] in
        Hashtbl.replace breakpoints path lines;
        respond req true ~body:(`Assoc ["breakpoints", `List (List.map (fun l ->
          `Assoc ["verified", `Bool true; "line", `Int l]) lines)]);
        false
    | "threads" -> respond req true ~body:(`Assoc ["threads", `List [`Assoc ["id", `Int 1; "name", `String "Ferdek"]]]); false
    | "stackTrace" ->
        respond req true ~body:(`Assoc ["stackFrames", `List (List.mapi (fun i (n, f, l) ->
          `Assoc ["id", `Int i; "name", `String n; "line", `Int l; "column", `Int 1;
                  "source", `Assoc ["path", `String f; "name", `String (Filename.basename f)]]) (frames ()))]);
        false
    | "scopes" ->
        (* zmienne widzimy tylko w bieżącej ramce (interpreter trzyma jej środowisko) *)
        let scopes = if (try args |> member "frameId" |> to_int with _ -> 0) <> 0 then [] else
          [`Assoc ["name", `String "Lokalne"; "variablesReference", `Int 1; "expensive", `Bool false];
           `Assoc ["name", `String "Globalne"; "variablesReference", `Int 2; "expensive", `Bool false]] in
        respond req true ~body:(`Assoc ["scopes", `List scopes]); false
    | "variables" ->
        let vars = match !current_env, args |> member "variablesReference" |> to_int with
          | Some env, 1 -> if env == root env then [] else vars_of env
          | Some env, 2 -> vars_of (root env)
          | _ -> [] in
        respond req true ~body:(`Assoc ["variables", `List vars]); false
    | "evaluate" ->
        let text = args |> member "expression" |> to_string in
        (match !current_env, Debugger.parse_expr text with
         | Some env, Some e ->
             (match Eval.eval_expr env e with
              | v -> respond req true ~body:(`Assoc ["result", `String (string_of_value v); "variablesReference", `Int 0])
              | exception RuntimeError msg -> respond req false ~body:(`Assoc ["error", `Assoc ["format", `String msg]]))
         | _ -> respond req false);
        false
    | "continue" -> mode := Run; respond req true ~body:(`Assoc ["allThreadsContinued", `Bool true]); true
    | "next" -> mode := Next (depth ()); respond req true; true
    | "stepIn" -> mode := Step; respond req true; true
    | "stepOut" -> mode := Finish (depth ()); respond req true; true
    | "configurationDone" -> respond req true; true
    | "disconnect" | "terminate" -> respond req true; exit 0
    | _ -> respond req true; false in
  (* Czekamy na prośby, aż któraś każe ruszyć *)
  let rec serve () =
    match read_message () with
    | None -> exit 0
    | Some req -> if not (handle req) then serve () in
  let hook file line env =
    flush_output ();
    let reason =
      if has_bp file line then Some "breakpoint"
      else match !mode with
        | Step -> Some (if !stop_on_entry then "entry" else "step")
        | Next d when depth () <= d -> Some "step"
        | Finish d when depth () < d -> Some "step"
        | _ -> None in
    match reason with
    | Some reason ->
        stop_on_entry := false;
        current_env := Some env;
        event "stopped" (`Assoc ["reason", `String reason; "threadId", `Int 1; "allThreadsStopped", `Bool true]);
        serve ()
    | None -> () in
  (* do configurationDone: inicjalizacja, launch, punkty zatrzymania *)
  serve ();
  (match !program with
   | None -> event "terminated" (`Assoc [])
   | Some prog ->
       if not !stop_on_entry then mode := Run;
       Interpreter.set_module_loader load_module;
       stmt_hook := Some hook;
       let code = match Interpreter.eval_program prog with
         | Ok () -> 0
         | Error msg ->
             flush_output ();
             event "output" (`Assoc ["category", `String "stderr"; "output", `String (Printf.sprintf
               "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: %s\n%s" msg (Interpreter.error_context ()))]);
             1 in
       stmt_hook := None;
       flush_output ();
       event "exited" (`Assoc ["exitCode", `Int code]);
       event "terminated" (`Assoc []));
  (* czekamy na disconnect *)
  let rec drain () = match read_message () with None -> () | Some req -> ignore (handle req); drain () in
  drain ();
  0
