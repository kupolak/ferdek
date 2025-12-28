(* Compiler for Ferdek Programming Language - Compiles to C *)

open Ast

(* ============ CODE GENERATION ============ *)

(* Code generation context *)
type codegen_context = {
  mutable temp_counter: int;           (* Counter for temporary variables *)
  mutable label_counter: int;          (* Counter for labels *)
  mutable function_protos: string list; (* Function prototypes *)
  mutable includes: string list;       (* Include statements *)
}

(* Create new context *)
let create_context () = {
  temp_counter = 0;
  label_counter = 0;
  function_protos = [];
  includes = ["#include <stdio.h>"; "#include <stdlib.h>"; "#include <string.h>"; "#include <stdbool.h>"];
}

(* Generate new temporary variable name *)
let new_temp ctx =
  let name = Printf.sprintf "t%d" ctx.temp_counter in
  ctx.temp_counter <- ctx.temp_counter + 1;
  name

(* Generate new label *)
let new_label ctx =
  let name = Printf.sprintf "L%d" ctx.label_counter in
  ctx.label_counter <- ctx.label_counter + 1;
  name

(* Add function prototype *)
let add_prototype ctx proto =
  if not (List.mem proto ctx.function_protos) then
    ctx.function_protos <- proto :: ctx.function_protos

(* ============ TYPE MAPPING ============ *)

(* C type for Ferdek values *)
let value_type = "FerdekValue"

(* ============ EXPRESSION COMPILATION ============ *)

(* Compile arithmetic operator *)
let compile_arith_op = function
  | Plus -> "+"
  | Minus -> "-"
  | Multiply -> "*"
  | Divide -> "/"
  | Modulo -> "%"

(* Compile comparison operator *)
let compile_comparison_op = function
  | Equal -> "=="
  | NotEqual -> "!="
  | Greater -> ">"
  | Less -> "<"

(* Compile logical operator *)
let compile_logical_op = function
  | And -> "&&"
  | Or -> "||"

(* Compile bitwise operator *)
let compile_bitwise_op = function
  | BitAnd -> "&"
  | BitOr -> "|"
  | BitXor -> "^"
  | BitShiftLeft -> "<<"
  | BitShiftRight -> ">>"

(* Compile expression to C *)
let rec compile_expr ctx expr =
  match expr with
  | IntLiteral n ->
      Printf.sprintf "make_int(%d)" n

  | StringLiteral s ->
      let escaped = String.escaped s in
      Printf.sprintf "make_string(\"%s\")" escaped

  | BoolLiteral b ->
      Printf.sprintf "make_bool(%s)" (if b then "true" else "false")

  | NullLiteral ->
      "make_null()"

  | Identifier name ->
      name

  | BinaryOp (e1, op, e2) ->
      let v1 = compile_expr ctx e1 in
      let v2 = compile_expr ctx e2 in
      let c_op = compile_arith_op op in
      Printf.sprintf "make_int(to_int(%s) %s to_int(%s))" v1 c_op v2

  | ComparisonOp (e1, op, e2) ->
      let v1 = compile_expr ctx e1 in
      let v2 = compile_expr ctx e2 in
      let c_op = compile_comparison_op op in
      Printf.sprintf "make_bool(to_int(%s) %s to_int(%s))" v1 c_op v2

  | LogicalOp (e1, op, e2) ->
      let v1 = compile_expr ctx e1 in
      let v2 = compile_expr ctx e2 in
      let c_op = compile_logical_op op in
      Printf.sprintf "make_bool(to_bool(%s) %s to_bool(%s))" v1 c_op v2

  | BitwiseOp (e1, op, e2) ->
      let v1 = compile_expr ctx e1 in
      let v2 = compile_expr ctx e2 in
      let c_op = compile_bitwise_op op in
      Printf.sprintf "make_int(to_int(%s) %s to_int(%s))" v1 c_op v2

  | BitwiseNot e ->
      let v = compile_expr ctx e in
      Printf.sprintf "make_int(~to_int(%s))" v

  | ToFixed e ->
      (* Convert to fixed-point 16.16 *)
      let v = compile_expr ctx e in
      Printf.sprintf "make_int(to_int(%s) << 16)" v

  | FromFixed e ->
      (* Convert from fixed-point 16.16 *)
      let v = compile_expr ctx e in
      Printf.sprintf "make_int(to_int(%s) >> 16)" v

  | ArrayAccess (name, index_expr) ->
      let idx = compile_expr ctx index_expr in
      Printf.sprintf "array_get(%s, to_int(%s))" name idx

  | FunctionCall (name, args) ->
      let c_args = List.map (compile_expr ctx) args in
      Printf.sprintf "%s(%s)" name (String.concat ", " c_args)

  | NewObject (class_name, args) ->
      (* Simple object creation - allocate struct *)
      Printf.sprintf "/* new %s */ make_null()" class_name

  | NewStruct struct_name ->
      (* Struct instantiation *)
      Printf.sprintf "/* new struct %s */ make_null()" struct_name

  | NewUnion union_name ->
      (* Union instantiation *)
      Printf.sprintf "/* new union %s */ make_null()" union_name

  | Reference e ->
      (* Pointer reference *)
      Printf.sprintf "/* & */ &(%s)" (compile_expr ctx e)

  | Dereference e ->
      (* Pointer dereference *)
      Printf.sprintf "/* * */ *(%s)" (compile_expr ctx e)

  | AddressOf var ->
      (* Address of variable *)
      Printf.sprintf "&%s" var

  | PointerArithmetic (e1, op, e2) ->
      (* Pointer arithmetic *)
      let c_e1 = compile_expr ctx e1 in
      let c_e2 = compile_expr ctx e2 in
      let c_op = match op with
        | Plus -> "+"
        | Minus -> "-"
        | _ -> failwith "Unsupported pointer arithmetic operator"
      in
      Printf.sprintf "(%s %s %s)" c_e1 c_op c_e2

  | FunctionRef func_name ->
      (* Function pointer - just return the function name (in C, function names are pointers) *)
      func_name

  | Parenthesized e ->
      Printf.sprintf "(%s)" (compile_expr ctx e)

(* ============ STATEMENT COMPILATION ============ *)

(* Compile statement to C *)
let rec compile_stmt ctx indent stmt =
  let ind = String.make (indent * 4) ' ' in
  match stmt with
  | VarDecl (name, expr) ->
      let value = compile_expr ctx expr in
      Printf.sprintf "%s%s %s = %s;" ind value_type name value

  | ArrayDecl (name, exprs) ->
      let values = List.map (compile_expr ctx) exprs in
      let size = List.length values in
      let array_init = String.concat ", " values in
      Printf.sprintf "%s%s %s = make_array((FerdekValue[]){%s}, %d);"
        ind value_type name array_init size

  | Print expr ->
      let value = compile_expr ctx expr in
      Printf.sprintf "%sprint_value(%s);" ind value

  | Read name ->
      Printf.sprintf "%s%s = read_value();" ind name

  | Assign (name, expr) ->
      let value = compile_expr ctx expr in
      Printf.sprintf "%s%s = %s;" ind name value

  | ArrayAssign (name, idx_expr, value_expr) ->
      let idx = compile_expr ctx idx_expr in
      let value = compile_expr ctx value_expr in
      Printf.sprintf "%sarray_set(%s, %s, %s);" ind name idx value

  | If (cond, then_stmts, else_stmts_opt) ->
      let cond_code = compile_expr ctx cond in
      let then_code = String.concat "\n" (List.map (compile_stmt ctx (indent + 1)) then_stmts) in
      let else_code = match else_stmts_opt with
        | None -> ""
        | Some stmts ->
            let else_body = String.concat "\n" (List.map (compile_stmt ctx (indent + 1)) stmts) in
            Printf.sprintf " else {\n%s\n%s}" else_body ind
      in
      Printf.sprintf "%sif (to_bool(%s)) {\n%s\n%s}%s"
        ind cond_code then_code ind else_code

  | While (cond, body) ->
      let cond_code = compile_expr ctx cond in
      let body_code = String.concat "\n" (List.map (compile_stmt ctx (indent + 1)) body) in
      Printf.sprintf "%swhile (to_bool(%s)) {\n%s\n%s}"
        ind cond_code body_code ind

  | FunctionCallStmt (name, args) ->
      let c_args = List.map (compile_expr ctx) args in
      Printf.sprintf "%s%s(%s);" ind name (String.concat ", " c_args)

  | FunctionCallWithAssign (var, func, args) ->
      let c_args = List.map (compile_expr ctx) args in
      Printf.sprintf "%s%s = %s(%s);" ind var func (String.concat ", " c_args)

  | Return expr_opt ->
      (match expr_opt with
       | None -> Printf.sprintf "%sreturn make_null();" ind
       | Some expr ->
           let value = compile_expr ctx expr in
           Printf.sprintf "%sreturn %s;" ind value)

  | Try (try_stmts, catch_var, catch_stmts) ->
      (* Simple try-catch - not full exception support in C *)
      let try_code = String.concat "\n" (List.map (compile_stmt ctx indent) try_stmts) in
      Printf.sprintf "%s/* try-catch not fully supported */\n%s" ind try_code

  | Throw expr ->
      Printf.sprintf "%s/* throw not supported */" ind

  | Break ->
      Printf.sprintf "%sbreak;" ind

  | Continue ->
      Printf.sprintf "%scontinue;" ind

(* ============ FUNCTION COMPILATION ============ *)

(* Compile function declaration *)
let compile_function ctx fdecl =
  (* Generate function prototype *)
  let params = String.concat ", " (List.map (fun p -> value_type ^ " " ^ p) fdecl.params) in
  let proto = Printf.sprintf "%s %s(%s)" value_type fdecl.name params in
  add_prototype ctx proto;

  (* Generate function body *)
  let body = String.concat "\n" (List.map (compile_stmt ctx 1) fdecl.body) in

  (* If no explicit return, add default return *)
  let has_return = List.exists (function Return _ -> true | _ -> false) fdecl.body in
  let default_return = if has_return then "" else "    return make_null();\n" in

  Printf.sprintf "%s {\n%s\n%s}" proto body default_return

(* ============ TOP-LEVEL COMPILATION ============ *)

(* Compile top-level declaration *)
let compile_top_level ctx decl =
  match decl with
  | Import module_name ->
      Printf.sprintf "/* import %s - not implemented */" module_name

  | Statement stmt ->
      compile_stmt ctx 0 stmt

  | FunctionDecl fdecl ->
      compile_function ctx fdecl

  | ClassDecl cdecl ->
      Printf.sprintf "/* class %s - not implemented */" cdecl.name

  | StructDecl sdecl ->
      Printf.sprintf "/* struct %s - not implemented */" sdecl.name

  | UnionDecl udecl ->
      Printf.sprintf "/* union %s - not implemented */" udecl.name

  | EnumDecl edecl ->
      (* Generate C enum *)
      let enum_values = List.mapi (fun i (name, value_opt) ->
        match value_opt with
        | Some v -> Printf.sprintf "  %s = %d" name v
        | None -> Printf.sprintf "  %s" name
      ) edecl.values in
      Printf.sprintf "typedef enum {\n%s\n} %s;"
        (String.concat ",\n" enum_values)
        edecl.name

(* ============ RUNTIME LIBRARY ============ *)

(* Generate runtime library code *)
let runtime_library = {|
/* Ferdek Runtime Library */

typedef enum {
    TYPE_INT,
    TYPE_STRING,
    TYPE_BOOL,
    TYPE_NULL,
    TYPE_ARRAY
} ValueType;

typedef struct FerdekValue FerdekValue;

struct FerdekValue {
    ValueType type;
    union {
        int int_val;
        char* string_val;
        bool bool_val;
        struct {
            FerdekValue* data;
            int length;
        } array_val;
    } value;
};

/* Constructor functions */
FerdekValue make_int(int n) {
    FerdekValue v;
    v.type = TYPE_INT;
    v.value.int_val = n;
    return v;
}

FerdekValue make_string(const char* s) {
    FerdekValue v;
    v.type = TYPE_STRING;
    v.value.string_val = strdup(s);
    return v;
}

FerdekValue make_bool(bool b) {
    FerdekValue v;
    v.type = TYPE_BOOL;
    v.value.bool_val = b;
    return v;
}

FerdekValue make_null() {
    FerdekValue v;
    v.type = TYPE_NULL;
    return v;
}

FerdekValue make_array(FerdekValue* data, int length) {
    FerdekValue v;
    v.type = TYPE_ARRAY;
    v.value.array_val.data = malloc(sizeof(FerdekValue) * length);
    memcpy(v.value.array_val.data, data, sizeof(FerdekValue) * length);
    v.value.array_val.length = length;
    return v;
}

/* Type conversion functions */
int to_int(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: return v.value.int_val;
        case TYPE_BOOL: return v.value.bool_val ? 1 : 0;
        case TYPE_STRING: return atoi(v.value.string_val);
        default: return 0;
    }
}

bool to_bool(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: return v.value.int_val != 0;
        case TYPE_BOOL: return v.value.bool_val;
        case TYPE_STRING: return strlen(v.value.string_val) > 0;
        case TYPE_NULL: return false;
        default: return true;
    }
}

/* Array operations */
FerdekValue array_get(FerdekValue arr, int index) {
    if (arr.type != TYPE_ARRAY) {
        fprintf(stderr, "Error: Not an array\n");
        exit(1);
    }
    if (index < 0 || index >= arr.value.array_val.length) {
        fprintf(stderr, "Error: Array index out of bounds\n");
        exit(1);
    }
    return arr.value.array_val.data[index];
}

/* I/O functions */
void print_value(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT:
            printf("%d\n", v.value.int_val);
            break;
        case TYPE_STRING:
            printf("%s\n", v.value.string_val);
            break;
        case TYPE_BOOL:
            printf("%s\n", v.value.bool_val ? "true" : "false");
            break;
        case TYPE_NULL:
            printf("null\n");
            break;
        case TYPE_ARRAY:
            printf("[array]\n");
            break;
    }
}

FerdekValue read_value() {
    char buffer[1024];
    if (fgets(buffer, sizeof(buffer), stdin) != NULL) {
        buffer[strcspn(buffer, "\n")] = 0;
        int n;
        if (sscanf(buffer, "%d", &n) == 1) {
            return make_int(n);
        }
        return make_string(buffer);
    }
    return make_null();
}
|}

(* ============ PROGRAM COMPILATION ============ *)

(* Compile entire program to C *)
let compile_program prog =
  let ctx = create_context () in

  (* Separate functions from statements *)
  let functions = List.filter_map (function
    | FunctionDecl fdecl -> Some (compile_function ctx fdecl)
    | _ -> None
  ) prog.declarations in

  let main_stmts = List.filter_map (function
    | Statement stmt -> Some stmt
    | _ -> None
  ) prog.declarations in

  let main_body = String.concat "\n" (List.map (compile_stmt ctx 1) main_stmts) in

  (* Assemble complete C program *)
  let includes = String.concat "\n" ctx.includes in
  let prototypes = String.concat ";\n" (List.rev ctx.function_protos) in
  let proto_section = if prototypes = "" then "" else prototypes ^ ";\n\n" in
  let functions_section = String.concat "\n\n" functions in
  let funcs = if functions_section = "" then "" else functions_section ^ "\n\n" in

  Printf.sprintf "%s

%s

%s

%s

int main() {
%s
    return 0;
}
"
    includes
    runtime_library
    proto_section
    funcs
    main_body
