(* File operations library functions helpers for KIBEL *)

(* Create directory *)
let kibel_zrob path =
  try
    Unix.mkdir path 0o755;
    true
  with Unix.Unix_error (Unix.EEXIST, _, _) ->
    false  (* Directory already exists *)

(* Remove directory *)
let kibel_wywal path =
  try
    Unix.rmdir path;
    true
  with Unix.Unix_error _ ->
    false

(* List files in directory *)
let kibel_co_w_kiblu path =
  try
    let handle = Unix.opendir path in
    let rec read_all acc =
      try
        let entry = Unix.readdir handle in
        if entry = "." || entry = ".." then
          read_all acc
        else
          read_all (entry :: acc)
      with End_of_file ->
        Unix.closedir handle;
        List.rev acc
    in
    read_all []
  with Unix.Unix_error _ ->
    []

(* Check if path is directory *)
let kibel_czy_to_kibel path =
  try
    let stats = Unix.stat path in
    stats.st_kind = Unix.S_DIR
  with Unix.Unix_error _ ->
    false

(* Copy file *)
let kibel_przekopiuj src dest =
  try
    let ic = open_in_bin src in
    let oc = open_out_bin dest in
    let buf = Bytes.create 4096 in
    let rec copy () =
      let n = input ic buf 0 4096 in
      if n > 0 then begin
        output oc buf 0 n;
        copy ()
      end
    in
    copy ();
    close_in ic;
    close_out oc;
    true
  with _ ->
    false

(* Move/rename file *)
let kibel_przenies src dest =
  try
    Sys.rename src dest;
    true
  with Sys_error _ ->
    false

(* Recursive delete *)
let rec kibel_wykop_wszystkie path =
  if kibel_czy_to_kibel path then begin
    (* It's a directory - recursively delete contents *)
    let entries = kibel_co_w_kiblu path in
    List.iter (fun entry ->
      let full_path = Filename.concat path entry in
      kibel_wykop_wszystkie full_path
    ) entries;
    (* Now delete the empty directory *)
    ignore (kibel_wywal path)
  end else begin
    (* It's a file - just delete it *)
    try
      Sys.remove path
    with Sys_error _ ->
      ()
  end

(* Create directory recursively (like mkdir -p) *)
let rec kibel_zrob_rekursywnie path =
  if Sys.file_exists path then
    true
  else begin
    let parent = Filename.dirname path in
    if parent <> path && parent <> "." && parent <> "/" then begin
      ignore (kibel_zrob_rekursywnie parent)
    end;
    kibel_zrob path
  end

(* Get file size *)
let kibel_rozmiar path =
  try
    let stats = Unix.stat path in
    stats.st_size
  with Unix.Unix_error _ ->
    0
