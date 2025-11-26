(* Interpreter for Ferdek Programming Language *)

open Ast

(* ============ RUNTIME VALUES ============ *)

(* Runtime value types *)
type value =
  | VInt of int
  | VString of string
  | VBool of bool
  | VNull
  | VArray of value array
  | VFunction of function_decl * environment
  | VObject of (string, value) Hashtbl.t

and environment = {
  mutable vars: (string, value) Hashtbl.t;
  parent: environment option;
}

(* Runtime exceptions *)
exception RuntimeError of string
exception ReturnValue of value
exception BreakLoop
exception ContinueLoop
exception ThrowException of value

(* ============ ENVIRONMENT MANAGEMENT ============ *)

(* Create a new environment *)
let create_env parent =
  { vars = Hashtbl.create 16; parent }

(* Create the global environment *)
let global_env () =
  create_env None

(* Get variable from environment *)
let rec get_var env name =
  try
    Hashtbl.find env.vars name
  with Not_found ->
    match env.parent with
    | Some parent -> get_var parent name
    | None -> raise (RuntimeError (Printf.sprintf "Undefined variable: %s" name))

(* Set variable in environment *)
let rec set_var env name value =
  if Hashtbl.mem env.vars name then
    Hashtbl.replace env.vars name value
  else
    match env.parent with
    | Some parent ->
        if Hashtbl.mem parent.vars name then
          set_var parent name value
        else
          Hashtbl.add env.vars name value
    | None ->
        Hashtbl.add env.vars name value

(* Define variable in current scope *)
let define_var env name value =
  Hashtbl.replace env.vars name value

(* ============ VALUE OPERATIONS ============ *)

(* Convert value to string *)
let rec string_of_value = function
  | VInt n -> string_of_int n
  | VString s -> s
  | VBool true -> "true"
  | VBool false -> "false"
  | VNull -> "null"
  | VArray arr ->
      "[" ^ String.concat ", " (Array.to_list (Array.map string_of_value arr)) ^ "]"
  | VFunction (fdecl, _) ->
      Printf.sprintf "<function %s>" fdecl.name
  | VObject _ ->
      "<object>"

(* Convert value to boolean *)
let to_bool = function
  | VBool b -> b
  | VInt 0 -> false
  | VInt _ -> true
  | VString "" -> false
  | VString _ -> true
  | VNull -> false
  | _ -> true

(* Convert value to integer *)
let to_int = function
  | VInt n -> n
  | VBool true -> 1
  | VBool false -> 0
  | VString s -> (try int_of_string s with _ -> 0)
  | VNull -> 0
  | _ -> raise (RuntimeError "Cannot convert to integer")

(* ============ EXPRESSION EVALUATION ============ *)

(* Evaluate arithmetic operator *)
let eval_arith_op op v1 v2 =
  let n1 = to_int v1 in
  let n2 = to_int v2 in
  VInt (match op with
    | Plus -> n1 + n2
    | Minus -> n1 - n2
    | Multiply -> n1 * n2
    | Divide ->
        if n2 = 0 then raise (RuntimeError "Division by zero")
        else n1 / n2
    | Modulo ->
        if n2 = 0 then raise (RuntimeError "Modulo by zero")
        else n1 mod n2
  )

(* Evaluate comparison operator *)
let eval_comparison_op op v1 v2 =
  let n1 = to_int v1 in
  let n2 = to_int v2 in
  VBool (match op with
    | Equal -> n1 = n2
    | NotEqual -> n1 <> n2
    | Greater -> n1 > n2
    | Less -> n1 < n2
  )

(* Evaluate logical operator *)
let eval_logical_op op v1 v2 =
  let b1 = to_bool v1 in
  let b2 = to_bool v2 in
  VBool (match op with
    | And -> b1 && b2
    | Or -> b1 || b2
  )

(* Evaluate expression *)
let rec eval_expr env = function
  | IntLiteral n -> VInt n
  | StringLiteral s -> VString s
  | BoolLiteral b -> VBool b
  | NullLiteral -> VNull
  | Identifier name -> get_var env name
  | BinaryOp (e1, op, e2) ->
      let v1 = eval_expr env e1 in
      let v2 = eval_expr env e2 in
      eval_arith_op op v1 v2
  | ComparisonOp (e1, op, e2) ->
      let v1 = eval_expr env e1 in
      let v2 = eval_expr env e2 in
      eval_comparison_op op v1 v2
  | LogicalOp (e1, op, e2) ->
      let v1 = eval_expr env e1 in
      let v2 = eval_expr env e2 in
      eval_logical_op op v1 v2
  | ArrayAccess (name, index_expr) ->
      let arr = get_var env name in
      let index = to_int (eval_expr env index_expr) in
      (match arr with
       | VArray arr ->
           if index < 0 || index >= Array.length arr then
             raise (RuntimeError "Array index out of bounds")
           else
             arr.(index)
       | _ -> raise (RuntimeError "Not an array"))
  | FunctionCall (name, args) ->
      eval_function_call env name args
  | NewObject (class_name, args) ->
      eval_new_object env class_name args
  | Parenthesized e -> eval_expr env e

(* Evaluate function call *)
and eval_function_call env name args =
  let func = get_var env name in
  match func with
  | VFunction (fdecl, closure_env) ->
      (* Create new environment for function execution *)
      let func_env = create_env (Some closure_env) in

      (* Evaluate arguments *)
      let arg_values = List.map (eval_expr env) args in

      (* Bind parameters *)
      if List.length fdecl.params <> List.length arg_values then
        raise (RuntimeError (Printf.sprintf "Function %s expects %d arguments, got %d"
                              name (List.length fdecl.params) (List.length arg_values)));

      List.iter2 (fun param value -> define_var func_env param value)
        fdecl.params arg_values;

      (* Execute function body *)
      (try
        List.iter (eval_stmt func_env) fdecl.body;
        VNull (* No explicit return *)
      with ReturnValue v -> v)
  | _ -> raise (RuntimeError (Printf.sprintf "%s is not a function" name))

(* Evaluate object creation *)
and eval_new_object env class_name args =
  (* For now, create empty object - full class support would need class environment *)
  let obj = Hashtbl.create 16 in
  VObject obj

(* ============ STATEMENT EXECUTION ============ *)

(* Execute statement *)
and eval_stmt env = function
  | VarDecl (name, expr) ->
      let value = eval_expr env expr in
      define_var env name value

  | ArrayDecl (name, exprs) ->
      let values = List.map (eval_expr env) exprs in
      let arr = Array.of_list values in
      define_var env name (VArray arr)

  | Print expr ->
      let value = eval_expr env expr in
      print_endline (string_of_value value)

  | Read name ->
      let line = read_line () in
      let value = try VInt (int_of_string line) with _ -> VString line in
      set_var env name value

  | Assign (name, expr) ->
      let value = eval_expr env expr in
      set_var env name value

  | If (cond, then_stmts, else_stmts_opt) ->
      let cond_value = eval_expr env cond in
      if to_bool cond_value then
        List.iter (eval_stmt env) then_stmts
      else
        (match else_stmts_opt with
         | Some else_stmts -> List.iter (eval_stmt env) else_stmts
         | None -> ())

  | While (cond, body) ->
      let rec loop () =
        let cond_value = eval_expr env cond in
        if to_bool cond_value then
          try
            List.iter (eval_stmt env) body;
            loop ()
          with
          | BreakLoop -> ()
          | ContinueLoop -> loop ()
      in
      loop ()

  | FunctionCallStmt (name, args) ->
      let _ = eval_function_call env name args in
      ()

  | FunctionCallWithAssign (var, func, args) ->
      let result = eval_function_call env func args in
      set_var env var result

  | Return expr_opt ->
      let value = match expr_opt with
        | Some expr -> eval_expr env expr
        | None -> VNull
      in
      raise (ReturnValue value)

  | Try (try_stmts, catch_var, catch_stmts) ->
      (try
        List.iter (eval_stmt env) try_stmts
      with ThrowException value ->
        let catch_env = create_env (Some env) in
        define_var catch_env catch_var value;
        List.iter (eval_stmt catch_env) catch_stmts)

  | Throw expr ->
      let value = eval_expr env expr in
      raise (ThrowException value)

  | Break -> raise BreakLoop

  | Continue -> raise ContinueLoop

(* ============ TOP-LEVEL DECLARATIONS ============ *)

(* Execute top-level declaration *)
let eval_top_level_decl env = function
  | Import module_name ->
      (* TODO: Implement module import *)
      Printf.eprintf "Warning: Import not yet implemented: %s\n" module_name

  | Statement stmt ->
      eval_stmt env stmt

  | FunctionDecl fdecl ->
      define_var env fdecl.name (VFunction (fdecl, env))

  | ClassDecl cdecl ->
      (* TODO: Implement class declarations *)
      Printf.eprintf "Warning: Classes not yet fully implemented: %s\n" cdecl.name

(* ============ PROGRAM EXECUTION ============ *)

(* Execute program *)
let eval_program prog =
  let env = global_env () in
  try
    List.iter (eval_top_level_decl env) prog.declarations;
    Ok ()
  with
  | RuntimeError msg ->
      Error (Printf.sprintf "Runtime error: %s" msg)
  | ThrowException value ->
      Error (Printf.sprintf "Uncaught exception: %s" (string_of_value value))
  | Failure msg ->
      Error (Printf.sprintf "Fatal error: %s" msg)
  | e ->
      Error (Printf.sprintf "Unexpected error: %s" (Printexc.to_string e))
