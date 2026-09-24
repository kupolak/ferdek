(* Ferdek w przeglądarce: interpreter jako Web Worker. Strona wysyła {cmd, code, input},
   worker odsyła {kind: "out"|"err"|"done"|"fmt"|"examples", ...}. Nowy worker na każde
   uruchomienie - świeży stan, a "Stop" to po prostu terminate(). *)

open Js_of_ocaml

let post fields = Worker.post_message (Js.Unsafe.obj (Array.of_list fields))
let str s = Js.Unsafe.inject (Js.string s)

(* Moduły: KLAMOTY/SKRZYNKA, SKRZYNKA albo BABKA (KLAMOTY/BABKA/BABKA.ferdek) - jak w ferdek *)
let load_module name =
  let name = if String.length name > 8 && String.sub name 0 8 = "KLAMOTY/"
             then String.sub name 8 (String.length name - 8) else name in
  let candidates = ["KLAMOTY/" ^ name ^ ".ferdek"; "KLAMOTY/" ^ name ^ "/" ^ name ^ ".ferdek"] in
  List.find_map (fun path ->
    Option.bind (List.assoc_opt path Embedded.files) (fun text ->
      match Loader.parse_source path text with
      | Ok prog -> Some prog
      | Error _ -> None)) candidates

let run code input =
  Sys_js.set_channel_flusher stdout (fun s -> post ["kind", str "out"; "text", str s]);
  Sys_js.set_channel_flusher stderr (fun s -> post ["kind", str "err"; "text", str s]);
  (* CO TAM U PANA SŁYCHAĆ czyta z pola "Wejście" *)
  let pending = ref input in
  Sys_js.set_channel_filler stdin (fun () -> let s = !pending in pending := ""; s);
  Interpreter.set_module_loader load_module;
  let code =
    match Loader.parse_source "program.ferdek" code with
    | Error errs ->
        List.iter (fun (_, _, m) -> prerr_endline ("A fe! " ^ m)) errs; 1
    | Ok prog ->
        match Interpreter.eval_program prog with
        | Ok () -> flush stdout; print_endline "Program zakończony pomyślnie. Piwo dla Pana!"; 0
        | Error msg ->
            flush stdout;
            prerr_string ("Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: " ^ msg ^ "\n" ^ Interpreter.error_context ()); 1
        | exception Stack_overflow ->
            flush stdout; prerr_endline "Błąd Wykonania: za głęboka rekurencja"; 1 in
  flush stdout; flush stderr;
  post ["kind", str "done"; "code", Js.Unsafe.inject code]

let () =
  Worker.set_onmessage (fun (msg : Js.Unsafe.any) ->
    let get k = Js.to_string (Js.Unsafe.get msg (Js.string k)) in
    match get "cmd" with
    | "run" -> run (get "code") (get "input")
    | "fmt" -> post ["kind", str "fmt"; "text", str (Formatter.format (get "code"))]
    | "examples" ->
        let ex = List.filter (fun (p, _) -> String.length p > 10 && String.sub p 0 10 = "przyklady/") Embedded.files in
        post ["kind", str "examples";
              "names", Js.Unsafe.inject (Js.array (Array.of_list (List.map (fun (p, _) -> Js.string p) ex)));
              "texts", Js.Unsafe.inject (Js.array (Array.of_list (List.map (fun (_, t) -> Js.string t) ex)))]
    | _ -> ())
