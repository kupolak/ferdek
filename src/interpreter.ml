(* Interpreter for Ferdek Programming Language: moduły, deklaracje i uruchamianie programu.
   Wartości - Value, wyrażenia i instrukcje - Eval, wbudowane funkcje - Interp_builtins. *)

open Ast
include Value
open Eval

let () = Interp_builtins.register (); Interp_builtins_doom.register ()

(* ============ MODULE LOADING ============ *)

(* Module loader function type - will be set by the main program *)
let module_loader : (string -> program option) ref = ref (fun _ -> None)

(* Set the module loader function *)
let set_module_loader loader =
  module_loader := loader

(* Import a module *)
(* Każdy moduł wykonujemy raz na sesję - jak kompilator, który wkleja go raz *)
let imported_modules : (string, unit) Hashtbl.t = Hashtbl.create 8


let rec import_module env module_name =
  if Hashtbl.mem imported_modules module_name then () else begin
  Hashtbl.add imported_modules module_name ();
  match !module_loader module_name with
  | Some module_ast ->
      (* Execute module in current environment *)
      List.iter (eval_top_level_decl env) module_ast.declarations
  | None ->
      raise (RuntimeError (Printf.sprintf "Nie ma takiego modułu: %s" module_name))
  end

(* ============ TOP-LEVEL DECLARATIONS ============ *)

(* Execute top-level declaration *)
and eval_top_level_decl env = function
  | Import module_name ->
      import_module env module_name

  | Statement stmt ->
      eval_stmt env stmt

  | FunctionDecl fdecl ->
      define_var env fdecl.name (VFunction (fdecl, env))

  | ClassDecl cdecl ->
      (* Store class definition in environment *)
      define_var env cdecl.name (VClass (cdecl, env))

  | StructDecl sdecl ->
      (* Store struct definition in environment *)
      define_var env sdecl.name (VStruct (sdecl, env))

  | UnionDecl udecl ->
      (* Store union definition in environment *)
      define_var env udecl.name (VUnion (udecl, env))

  | EnumDecl edecl ->
      (* Store enum definition in environment *)
      define_var env edecl.name (VEnum (edecl, env));
      (* Also define all enum values as constants *)
      let rec define_enum_values values next_value =
        match values with
        | [] -> ()
        | (name, value_opt) :: rest ->
            let actual_value = match value_opt with
              | Some v -> v
              | None -> next_value
            in
            define_var env name (VInt actual_value);
            define_enum_values rest (actual_value + 1)
      in
      define_enum_values edecl.values 0

(* ============ PROGRAM EXECUTION ============ *)

(* Execute program *)
(* Sesja = środowisko globalne żyjące między kolejnymi programami (REPL) *)
let new_session () =
  Hashtbl.reset imported_modules;
  global_env ()

let eval_in env prog =
  current_loc := ("", 0);
  try
    List.iter (eval_top_level_decl env) prog.declarations;
    Ok ()
  with
  | RuntimeError msg ->
      Error (Printf.sprintf "%s%s" msg (loc_suffix ()))
  | ThrowException value ->
      Error (Printf.sprintf "Nikt nie złapał wyjątku: %s%s" (string_of_value value) (loc_suffix ()))
  | ReturnValue _ -> Error ("I JA INFORMUJĘ ŻE WYCHODZĘ poza funkcją" ^ loc_suffix ())
  | BreakLoop -> Error ("A POCAŁUJCIE MNIE WSZYSCY W DUPĘ poza pętlą" ^ loc_suffix ())
  | ContinueLoop -> Error ("AKUKARACZA poza pętlą" ^ loc_suffix ())
  | Failure msg ->
      Error (Printf.sprintf "Poważna awaria: %s%s" msg (loc_suffix ()))
  | e ->
      Error (Printf.sprintf "Nieoczekiwany błąd: %s%s" (Printexc.to_string e) (loc_suffix ()))

let eval_program prog = eval_in (new_session ()) prog
