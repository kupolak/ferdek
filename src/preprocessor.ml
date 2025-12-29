(* preprocessor.ml - C-style preprocessor for Ferdek *)

type macro = {
  name: string;
  params: string list option;  (* None for simple defines, Some [...] for function-like *)
  body: string;
}

type conditional_state =
  | Active      (* Currently processing *)
  | Inactive    (* Skipping due to false condition *)
  | Done        (* Already processed true branch *)

let macros : (string, macro) Hashtbl.t = Hashtbl.create 100

(* Built-in platform macros *)
let () =
  Hashtbl.add macros "LINUX" { name = "LINUX"; params = None; body = if Sys.os_type = "Unix" then "1" else "0" };
  Hashtbl.add macros "UNIX" { name = "UNIX"; params = None; body = if Sys.os_type = "Unix" then "1" else "0" };
  Hashtbl.add macros "WINDOWS" { name = "WINDOWS"; params = None; body = if Sys.os_type = "Win32" || Sys.os_type = "Cygwin" then "1" else "0" };
  Hashtbl.add macros "MACOS" { name = "MACOS"; params = None; body = if Sys.os_type = "Unix" && Sys.file_exists "/Applications" then "1" else "0" }

(* Tokenize macro replacement (simple whitespace split) *)
let tokenize s =
  let s = String.trim s in
  if s = "" then [] else String.split_on_char ' ' s

(* Replace macro parameters in body *)
let replace_params params args body =
  if List.length params <> List.length args then
    failwith "Macro argument count mismatch"
  else
    List.fold_left2 (fun acc param arg ->
      (* Simple string replacement - can be improved with proper tokenization *)
      let re = Str.regexp_string param in
      Str.global_replace re arg acc
    ) body params args

(* Expand a macro invocation *)
let expand_macro name args =
  match Hashtbl.find_opt macros name with
  | None -> name (* Not a macro, return as-is *)
  | Some macro ->
      match macro.params with
      | None -> macro.body (* Simple macro *)
      | Some params -> replace_params params args macro.body

(* Process a single line *)
let process_line line cond_stack =
  let trimmed = String.trim line in

  (* Check if this is a preprocessor directive *)
  if String.length trimmed > 0 && trimmed.[0] = '#' then
    let directive = String.sub trimmed 1 (String.length trimmed - 1) |> String.trim in
    let tokens = tokenize directive in

    match tokens with
    (* #define NAME VALUE or #PAŹDZIOCH KRADNIE NAME VALUE *)
    | "define" :: name :: rest
    | "PAŹDZIOCH" :: "KRADNIE" :: name :: rest
    | "PAZDZIOCH" :: "KRADNIE" :: name :: rest ->
        let body = String.concat " " rest in
        (* Check for function-like macro: #define FOO(x,y) ... *)
        if String.contains name '(' then
          let paren_pos = String.index name '(' in
          let macro_name = String.sub name 0 paren_pos in
          let params_str = String.sub name (paren_pos + 1) (String.length name - paren_pos - 2) in
          let params = String.split_on_char ',' params_str |> List.map String.trim in
          Hashtbl.replace macros macro_name { name = macro_name; params = Some params; body };
          (None, cond_stack)
        else begin
          Hashtbl.replace macros name { name; params = None; body };
          (None, cond_stack)
        end

    (* #undef NAME or #PAŹDZIOCH ODDAJ NAME *)
    | "undef" :: name :: _
    | "PAŹDZIOCH" :: "ODDAJ" :: name :: _
    | "PAZDZIOCH" :: "ODDAJ" :: name :: _ ->
        Hashtbl.remove macros name;
        (None, cond_stack)

    (* #ifdef NAME or #JEŚLI JEST NAME *)
    | "ifdef" :: name :: _
    | "JEŚLI" :: "JEST" :: name :: _
    | "JESLI" :: "JEST" :: name :: _ ->
        let state = if Hashtbl.mem macros name then Active else Inactive in
        (None, state :: cond_stack)

    (* #ifndef NAME or #JEŚLI NIE MA NAME *)
    | "ifndef" :: name :: _
    | "JEŚLI" :: "NIE" :: "MA" :: name :: _
    | "JESLI" :: "NIE" :: "MA" :: name :: _ ->
        let state = if not (Hashtbl.mem macros name) then Active else Inactive in
        (None, state :: cond_stack)

    (* #else or #A MOŻE TAK *)
    | "else" :: _
    | "A" :: "MOŻE" :: "TAK" :: _
    | "A" :: "MOZE" :: "TAK" :: _ ->
        (match cond_stack with
         | Active :: rest -> (None, Inactive :: rest)
         | Inactive :: rest -> (None, Active :: rest)
         | Done :: rest -> (None, Done :: rest)
         | [] -> failwith "#else/#A MOŻE TAK without #ifdef/#ifndef"
        )

    (* #endif or #KONIEC PRZEKRĘTU *)
    | "endif" :: _
    | "KONIEC" :: "PRZEKRĘTU" :: _
    | "KONIEC" :: "PRZEKRETU" :: _ ->
        (match cond_stack with
         | _ :: rest -> (None, rest)
         | [] -> failwith "#endif/#KONIEC PRZEKRĘTU without #ifdef/#ifndef"
        )

    | _ ->
        (* Unknown directive - ignore *)
        (None, cond_stack)

  (* Not a directive - check if we should process this line *)
  else if cond_stack = [] || List.hd cond_stack = Active then
    (* Expand macros in the line *)
    let expanded = Hashtbl.fold (fun name macro acc ->
      match macro.params with
      | None ->
          (* Simple text replacement *)
          let re = Str.regexp ("\\b" ^ name ^ "\\b") in
          Str.global_replace re macro.body acc
      | Some _ ->
          (* Function-like macros would need proper parsing - skip for now *)
          acc
    ) macros line in
    (Some expanded, cond_stack)
  else
    (* Skipping this line due to conditional *)
    (None, cond_stack)

(* Preprocess a file *)
let preprocess_file filename =
  let ic = open_in filename in
  let result = ref [] in
  let cond_stack = ref [] in

  try
    while true do
      let line = input_line ic in
      let (output, new_stack) = process_line line !cond_stack in
      cond_stack := new_stack;
      match output with
      | Some l -> result := l :: !result
      | None -> ()
    done;
    close_in ic;
    List.rev !result
  with End_of_file ->
    close_in ic;
    if !cond_stack <> [] then
      failwith "Unclosed #ifdef/#ifndef";
    List.rev !result

(* Preprocess a string *)
let preprocess_string content =
  let lines = String.split_on_char '\n' content in
  let result = ref [] in
  let cond_stack = ref [] in

  List.iter (fun line ->
    let (output, new_stack) = process_line line !cond_stack in
    cond_stack := new_stack;
    match output with
    | Some l -> result := l :: !result
    | None -> ()
  ) lines;

  if !cond_stack <> [] then
    failwith "Unclosed #ifdef/#ifndef";

  String.concat "\n" (List.rev !result)
