(* Interpreter i kompilator znają te same funkcje wbudowane, z tą samą liczbą argumentów.
   Pisownie bez polskich znaków lekser zamienia na polskie - te liczą się jak polskie. *)

let () =
  (* tylko gdy lekser przeczytał całą nazwę jako jedno słowo *)
  let canonical name =
    let lb = Lexing.from_string name in
    match Lexer.token lb with
    | Parser.IDENTIFIER n when lb.Lexing.lex_curr_pos = String.length name -> n
    | _ | exception _ -> name in
  let norm l = List.sort_uniq compare (List.map (fun (n, a) -> (canonical n, a)) l) in
  let interp = norm (Interpreter.builtin_arities ()) and comp = norm (Compiler.builtin_arities ()) in
  let missing_in what a b = List.filter_map (fun (n, arity) ->
    match List.assoc_opt n b with
    | None -> Some (Printf.sprintf "%s: brak %s" what n)
    | Some a2 when a2 <> arity -> Some (Printf.sprintf "%s: %s ma inną liczbę argumentów" what n)
    | _ -> None) a in
  let problems = List.sort_uniq compare (missing_in "kompilator" interp comp @ missing_in "interpreter" comp interp) in
  List.iter print_endline problems;
  if problems <> [] then exit 1;
  Printf.printf "--- funkcje wbudowane: %d, takie same w obu trybach\n" (List.length interp)
