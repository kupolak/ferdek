(* Wbudowane funkcje: polecenia systemu, czas, pauza, POLAŁA SIĘ KREW *)

open Value
open Eval
open Builtins_common

let register () = add [
  (* SYSTEM(komenda) - wykonuje komendę systemową i zwraca output *)
  (* OPAKUJ W GAZETĘ(tekst) - bezpieczne cytowanie argumentu dla powłoki (do SYSTEM) *)
  ["OPAKUJ W GAZETĘ"], Some 1, (fun env args ->
      (match args with
       | [arg] -> VString (Filename.quote (to_string (eval_expr env arg)))
       | _ -> raise (RuntimeError "OPAKUJ W GAZETĘ oczekuje 1 argumentu")));

  ["SYSTEM"], Some 1, (fun env args ->
      (match args with
       | [cmd_arg] ->
           let cmd = to_string (eval_expr env cmd_arg) in
           (try
             let ic = Unix.open_process_in cmd in
             let buf = Buffer.create 256 in
             (try
               while true do
                 Buffer.add_channel buf ic 1
               done;
               VString ""
             with End_of_file ->
               let _ = Unix.close_process_in ic in
               let output = Buffer.contents buf in
               VString output)
           with Unix.Unix_error (err, _, _) ->
             raise (RuntimeError (Printf.sprintf "SYSTEM: błąd: %s" (Unix.error_message err))))
       | _ -> raise (RuntimeError "SYSTEM oczekuje 1 argumentu")));

  (* POLAŁA SIĘ KREW(format, ...) - Variadic error function like I_Error *)
  ["POLAŁA SIĘ KREW"; "POLALA SIE KREW"], None, (fun env args ->
      (match args with
       | [] -> raise (RuntimeError "POLAŁA SIĘ KREW: potrzeba co najmniej jednego argumentu")
       | format_arg :: rest_args ->
           let format = to_string (eval_expr env format_arg) in
           let arg_values = List.map (eval_expr env) rest_args in
           (* Simple printf-like formatting: replace %d, %s, %i with arguments *)
           let rec format_string fmt args_left acc =
             if String.length fmt = 0 then
               acc
             else if String.length fmt >= 2 && String.get fmt 0 = '%' then
               let spec = String.get fmt 1 in
               match spec, args_left with
               | 'd', v::rest | 'i', v::rest ->
                   let num = to_int v in
                   format_string (String.sub fmt 2 (String.length fmt - 2)) rest (acc ^ string_of_int num)
               | 's', v::rest ->
                   let str = to_string v in
                   format_string (String.sub fmt 2 (String.length fmt - 2)) rest (acc ^ str)
               | '%', _ ->
                   format_string (String.sub fmt 2 (String.length fmt - 2)) args_left (acc ^ "%")
               | _, [] ->
                   (* No more args, keep format specifier *)
                   format_string (String.sub fmt 1 (String.length fmt - 1)) [] (acc ^ String.make 1 (String.get fmt 0))
               | _, _ ->
                   (* Unknown specifier, keep it *)
                   format_string (String.sub fmt 2 (String.length fmt - 2)) args_left (acc ^ "%" ^ String.make 1 spec)
             else
               format_string (String.sub fmt 1 (String.length fmt - 1)) args_left (acc ^ String.make 1 (String.get fmt 0))
           in
           let message = format_string format arg_values "" in
           raise (RuntimeError (Printf.sprintf "I_Error: %s" message))));

  (* Czas: TRZEBA SPAĆ(ms) usypia, JEST TRZECIA W NOCY() - milisekundy od startu programu *)
  ["TRZEBA SPAĆ"], Some 1, (fun env args ->
      let ms = to_float (eval_expr env (List.hd args)) in
      if ms < 0.0 then raise (RuntimeError "TRZEBA SPAĆ: czas nie może być ujemny");
      flush stdout;
      Unix.sleepf (ms /. 1000.);
      VNull);

  ["JEST TRZECIA W NOCY"], Some 0, (fun _ _ ->
      VInt (int_of_float ((Unix.gettimeofday () -. program_start) *. 1000.)));
  ]
