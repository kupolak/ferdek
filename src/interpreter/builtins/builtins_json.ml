(* Wbudowane funkcje: SŁOIK - JSON *)

open Value
open Eval
open Builtins_common

let register () = add [
  ["ZAPAKUJ DO SŁOIKA"], Some 1, (fun env args -> VString (Json.pack (eval_expr env (List.hd args))));

  ["WYJMIJ ZE SŁOIKA"], Some 1, (fun env args -> Json.unpack (to_string (eval_expr env (List.hd args))));
  ]
