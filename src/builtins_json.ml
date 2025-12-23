(* JSON utilities for Ferdek *)

open Interpreter

(* Simple JSON parser *)
let rec parse_json json_str =
  let json_str = String.trim json_str in
  
  if json_str = "null" then
    VNull
  else if json_str = "true" then
    VBool true
  else if json_str = "false" then
    VBool false
  else if String.length json_str > 0 && json_str.[0] = '"' then
    (* Parse string *)
    if String.length json_str > 1 && json_str.[String.length json_str - 1] = '"' then
      let str = String.sub json_str 1 (String.length json_str - 2) in
      (* Unescape basic escapes *)
      let str = Str.global_replace (Str.regexp "\\\\\"") "\"" str in
      let str = Str.global_replace (Str.regexp "\\\\n") "\n" str in
      let str = Str.global_replace (Str.regexp "\\\\t") "\t" str in
      let str = Str.global_replace (Str.regexp "\\\\\\\\") "\\" str in
      VString str
    else
      raise (RuntimeError "Invalid JSON string")
  else if String.length json_str > 0 && (json_str.[0] = '-' || Char.code json_str.[0] >= 48 && Char.code json_str.[0] <= 57) then
    (* Parse number *)
    (try
      if String.contains json_str '.' then
        VInt (int_of_float (float_of_string json_str))
      else
        VInt (int_of_string json_str)
    with _ ->
      raise (RuntimeError "Invalid JSON number"))
  else if json_str.[0] = '[' then
    (* Parse array *)
    parse_json_array json_str
  else if json_str.[0] = '{' then
    (* Parse object *)
    parse_json_object json_str
  else
    raise (RuntimeError ("Invalid JSON: " ^ json_str))

and parse_json_array json_str =
  let json_str = String.trim json_str in
  if String.length json_str < 2 || json_str.[0] <> '[' || json_str.[String.length json_str - 1] <> ']' then
    raise (RuntimeError "Invalid JSON array")
  else
    let content = String.sub json_str 1 (String.length json_str - 2) in
    let content = String.trim content in
    if content = "" then
      VArray [||]
    else
      let items = split_json_array content in
      let values = List.map parse_json items in
      VArray (Array.of_list values)

and parse_json_object json_str =
  let json_str = String.trim json_str in
  if String.length json_str < 2 || json_str.[0] <> '{' || json_str.[String.length json_str - 1] <> '}' then
    raise (RuntimeError "Invalid JSON object")
  else
    let content = String.sub json_str 1 (String.length json_str - 2) in
    let content = String.trim content in
    if content = "" then
      VHashMap (Hashtbl.create 0)
    else
      let items = split_json_object content in
      let tbl = Hashtbl.create (List.length items) in
      List.iter (fun (key, value) ->
        Hashtbl.add tbl key (parse_json value)
      ) items;
      VHashMap tbl

(* Split JSON array elements respecting nesting *)
and split_json_array json_str =
  let rec loop acc current depth i =
    if i >= String.length json_str then
      if current = "" then List.rev acc else List.rev (current :: acc)
    else
      let c = json_str.[i] in
      match c with
      | '[' | '{' -> loop acc (current ^ String.make 1 c) (depth + 1) (i + 1)
      | ']' | '}' -> loop acc (current ^ String.make 1 c) (depth - 1) (i + 1)
      | '"' ->
          (* Handle strings - skip until closing quote *)
          let j = find_json_string_end json_str (i + 1) in
          let str_part = String.sub json_str i (j - i + 1) in
          loop acc (current ^ str_part) depth (j + 1)
      | ',' when depth = 0 ->
          let trimmed = String.trim current in
          loop (trimmed :: acc) "" depth (i + 1)
      | _ -> loop acc (current ^ String.make 1 c) depth (i + 1)
  in
  loop [] "" 0 0

(* Split JSON object key-value pairs *)
and split_json_object json_str =
  let pairs = split_json_array json_str in
  List.map (fun pair ->
    let colon_pos = String.index pair ':' in
    let key_str = String.trim (String.sub pair 0 colon_pos) in
    let value_str = String.trim (String.sub pair (colon_pos + 1) (String.length pair - colon_pos - 1)) in
    let key = 
      if String.length key_str > 0 && key_str.[0] = '"' then
        String.sub key_str 1 (String.length key_str - 2)
      else
        key_str
    in
    (key, value_str)
  ) pairs

(* Find closing quote in JSON string *)
and find_json_string_end json_str i =
  let rec loop i =
    if i >= String.length json_str then i
    else if json_str.[i] = '"' && (i = 0 || json_str.[i-1] <> '\\') then i
    else loop (i + 1)
  in
  loop i

(* Convert Ferdek value to JSON string *)
let rec value_to_json = function
  | VNull -> "null"
  | VBool true -> "true"
  | VBool false -> "false"
  | VInt n -> string_of_int n
  | VString s -> "\"" ^ (escape_json_string s) ^ "\""
  | VArray arr ->
      let items = Array.to_list (Array.map value_to_json arr) in
      "[" ^ String.concat "," items ^ "]"
  | VHashMap tbl ->
      let pairs = ref [] in
      Hashtbl.iter (fun k v ->
        pairs := ("\"" ^ escape_json_string k ^ "\":" ^ value_to_json v) :: !pairs
      ) tbl;
      "{" ^ String.concat "," (List.rev !pairs) ^ "}"
  | VFunction (fdecl, _) ->
      "\"<function:" ^ fdecl.name ^ ">\""
  | VObject _ ->
      "{}"
  | VFileHandle _ ->
      "\"<file>\""

and escape_json_string s =
  let s = Str.global_replace (Str.regexp "\\\\") "\\\\" s in
  let s = Str.global_replace (Str.regexp "\"") "\\\"" s in
  let s = Str.global_replace (Str.regexp "\n") "\\n" s in
  let s = Str.global_replace (Str.regexp "\t") "\\t" s in
  s
