(* Compiler for Ferdek Programming Language - Compiles to C *)
(* Kompilator obsługuje rdzeń języka. Wszystko inne kończy się Compile_error
   z czytelnym komunikatem - nigdy po cichu zepsutym kodem C. *)

open Ast

exception Compile_error of string

let error msg = raise (Compile_error msg)
let unsupported what =
  error (Printf.sprintf "Kompilator nie obsługuje: %s. Odpal to interpreterem (ferdek plik.ferdek)." what)

(* ============ NAMES ============ *)

(* Nazwy Ferdka (spacje, polskie znaki) -> poprawne identyfikatory C.
   Prefiks chroni przed kolizją z nazwami z biblioteki C i runtime'u. *)
let mangle prefix name =
  let b = Buffer.create (String.length name + 2) in
  Buffer.add_string b prefix;
  String.iter (fun c -> match c with
    | 'a'..'z' | 'A'..'Z' | '0'..'9' | '_' -> Buffer.add_char b c
    | c -> Buffer.add_string b (Printf.sprintf "_%02x" (Char.code c))) name;
  Buffer.contents b

let var_c = mangle "v_"
let fun_c = mangle "f_"

(* Zmienne zadeklarowane (VarDecl/ArrayDecl/catch) i przypisane w bloku.
   Ferdek nie ma zasięgu blokowego: zmienna z pętli żyje w całej funkcji. *)
let rec stmt_names (decl, assigned) = function
  | VarDecl (n, _) | ArrayDecl (n, _) -> (n :: decl, assigned)
  | Read n | Assign (n, _) | FunctionCallWithAssign (n, _, _) -> (decl, n :: assigned)
  | If (_, a, b) -> block_names (block_names (decl, assigned) a) (Option.value b ~default:[])
  | While (_, b) -> block_names (decl, assigned) b
  | Try (a, v, b) -> block_names (block_names (v :: decl, assigned) a) b
  | _ -> (decl, assigned)
and block_names acc stmts = List.fold_left stmt_names acc stmts

let dedup l = List.sort_uniq compare l

(* ============ CODE GENERATION ============ *)

type codegen_context = {
  funcs: (string, function_decl) Hashtbl.t;   (* Funkcje użytkownika *)
  globals: (string, unit) Hashtbl.t;          (* Zmienne programu głównego *)
  mutable locals: string list;                (* Zmienne bieżącej funkcji *)
  mutable in_function: bool;
  mutable loop_handlers: string list;         (* Handler wyjątków z wejścia do pętli (break/continue) *)
  mutable counter: int;                       (* Unikalne nazwy pomocnicze *)
}

let fresh ctx prefix =
  ctx.counter <- ctx.counter + 1;
  Printf.sprintf "%s%d" prefix ctx.counter

let rec has_try stmts = List.exists (function
  | Try _ -> true
  | If (_, a, b) -> has_try a || has_try (Option.value b ~default:[])
  | While (_, b) -> has_try b
  | _ -> false) stmts

let is_var ctx name = List.mem name ctx.locals || Hashtbl.mem ctx.globals name

let comparison_c = function
  | Equal -> "==" | NotEqual -> "!=" | Greater -> ">" | Less -> "<"

let arith_c = function
  | Plus -> "op_add" | Minus -> "op_sub" | Multiply -> "op_mul"
  | Divide -> "op_div" | Modulo -> "op_mod"

let bitwise_c = function
  | BitAnd -> "&" | BitOr -> "|" | BitXor -> "^"
  | BitShiftLeft -> "<<" | BitShiftRight -> ">>"

let c_string_literal s =
  (* String.escaped daje dziesiętne \197, a C czyta ósemkowo - escapujemy sami *)
  let buf = Buffer.create (String.length s + 2) in
  Buffer.add_char buf '"';
  String.iter (fun c -> match c with
    | '"' -> Buffer.add_string buf "\\\""
    | '\\' -> Buffer.add_string buf "\\\\"
    | '\n' -> Buffer.add_string buf "\\n"
    | '\t' -> Buffer.add_string buf "\\t"
    | c when Char.code c < 32 -> Buffer.add_string buf (Printf.sprintf "\\%03o" (Char.code c))
    | c -> Buffer.add_char buf c) s;
  Buffer.add_char buf '"';
  Buffer.contents buf

let rec compile_expr ctx expr =
  match expr with
  | IntLiteral n -> Printf.sprintf "make_int(%dLL)" n
  | StringLiteral s -> Printf.sprintf "make_string(%s)" (c_string_literal s)
  | BoolLiteral b -> Printf.sprintf "make_bool(%s)" (if b then "true" else "false")
  | NullLiteral -> "make_null()"
  | Identifier name ->
      if is_var ctx name then var_c name
      else if Hashtbl.mem ctx.funcs name then unsupported "funkcje jako wartości (wskaźniki do funkcji)"
      else error (Printf.sprintf "Nieznana zmienna: %s" name)
  | BinaryOp (e1, op, e2) ->
      Printf.sprintf "%s(%s, %s)" (arith_c op) (compile_expr ctx e1) (compile_expr ctx e2)
  | ComparisonOp (e1, op, e2) ->
      Printf.sprintf "make_bool(compare_values(%s, %s) %s 0)"
        (compile_expr ctx e1) (compile_expr ctx e2) (comparison_c op)
  | LogicalOp (e1, op, e2) ->
      Printf.sprintf "%s(%s, %s)" (match op with And -> "logic_and" | Or -> "logic_or")
        (compile_expr ctx e1) (compile_expr ctx e2)
  | BitwiseOp (e1, op, e2) ->
      Printf.sprintf "make_int(to_int(%s) %s to_int(%s))"
        (compile_expr ctx e1) (bitwise_c op) (compile_expr ctx e2)
  | BitwiseNot e -> Printf.sprintf "make_int(~to_int(%s))" (compile_expr ctx e)
  | ToFixed e -> Printf.sprintf "make_int(to_int(%s) << 16)" (compile_expr ctx e)
  | FromFixed e -> Printf.sprintf "make_int(to_int(%s) >> 16)" (compile_expr ctx e)
  | ArrayAccess (arr, idx) ->
      Printf.sprintf "array_get(%s, to_int(%s))" (compile_expr ctx arr) (compile_expr ctx idx)
  | FunctionCall (name, args) -> compile_call ctx name args
  | Parenthesized e -> Printf.sprintf "(%s)" (compile_expr ctx e)
  | NewObject _ -> unsupported "klasy (DZIAD ZDZIADZIAŁY JEDEN)"
  | NewStruct _ -> unsupported "struktury (ZMONTUJ MEBEL)"
  | NewUnion _ -> unsupported "unie (WEJDŹ DO UNII)"
  | Reference _ | Dereference _ | AddressOf _ | PointerArithmetic _ -> unsupported "wskaźniki"
  | FunctionRef _ -> unsupported "funkcje jako wartości (wskaźniki do funkcji)"

and compile_call ctx name args =
  let c_args = List.map (compile_expr ctx) args in
  match Hashtbl.find_opt ctx.funcs name with
  | Some f ->
      if f.is_variadic then unsupported "funkcje wariadyczne";
      if List.length args <> List.length f.params then
        error (Printf.sprintf "Funkcja %s oczekuje %d argumentów, podano %d"
                 name (List.length f.params) (List.length args));
      Printf.sprintf "%s(%s)" (fun_c name) (String.concat ", " c_args)
  | None ->
      if is_var ctx name then unsupported "wywołania funkcji ze zmiennej (wskaźniki do funkcji)"
      else error (Printf.sprintf "Nieznana funkcja: %s (albo wbudowana, której kompilator nie zna)" name)

let rec compile_stmt ctx indent stmt =
  let ind = String.make (indent * 4) ' ' in
  let block stmts = String.concat "\n" (List.map (compile_stmt ctx (indent + 1)) stmts) in
  match stmt with
  | VarDecl (name, e) | Assign (name, e) ->
      Printf.sprintf "%s%s = %s;" ind (var_c name) (compile_expr ctx e)
  | ArrayDecl (name, []) ->
      Printf.sprintf "%s%s = make_array(NULL, 0);" ind (var_c name)
  | ArrayDecl (name, exprs) ->
      Printf.sprintf "%s%s = make_array((FerdekValue[]){%s}, %d);" ind (var_c name)
        (String.concat ", " (List.map (compile_expr ctx) exprs)) (List.length exprs)
  | Print e -> Printf.sprintf "%sprint_value(%s);" ind (compile_expr ctx e)
  | Read name -> Printf.sprintf "%s%s = read_value();" ind (var_c name)
  | ArrayAssign (ArrayAccess (arr, idx), value) ->
      Printf.sprintf "%sarray_set(%s, to_int(%s), %s);" ind
        (compile_expr ctx arr) (compile_expr ctx idx) (compile_expr ctx value)
  | ArrayAssign _ -> error "Przypisanie do tablicy bez indeksu"
  | If (cond, then_stmts, else_stmts) ->
      let else_code = match else_stmts with
        | None -> ""
        | Some stmts -> Printf.sprintf " else {\n%s\n%s}" (block stmts) ind
      in
      Printf.sprintf "%sif (to_bool(%s)) {\n%s\n%s}%s" ind (compile_expr ctx cond) (block then_stmts) ind else_code
  | While (cond, body) when has_try body ->
      (* break/continue z wnętrza try musi zdjąć handlery założone w pętli *)
      let h = fresh ctx "loop_handler" in
      ctx.loop_handlers <- h :: ctx.loop_handlers;
      let body_code = block body in
      ctx.loop_handlers <- List.tl ctx.loop_handlers;
      Printf.sprintf "%s{\n%s    Handler* %s = ferdek_handler;\n%s    while (to_bool(%s)) {\n%s\n%s    }\n%s}"
        ind ind h ind (compile_expr ctx cond) body_code ind ind
  | While (cond, body) ->
      let saved = ctx.loop_handlers in
      ctx.loop_handlers <- "" :: saved;
      let body_code = block body in
      ctx.loop_handlers <- saved;
      Printf.sprintf "%swhile (to_bool(%s)) {\n%s\n%s}" ind (compile_expr ctx cond) body_code ind
  | FunctionCallStmt (name, args) ->
      Printf.sprintf "%s%s;" ind (compile_call ctx name args)
  | FunctionCallWithAssign (var, func, args) ->
      Printf.sprintf "%s%s = %s;" ind (var_c var) (compile_call ctx func args)
  | Return e ->
      if not ctx.in_function then unsupported "return poza funkcją";
      let v = match e with None -> "make_null()" | Some e -> compile_expr ctx e in
      (* Wartość liczymy przed zdjęciem handlerów - może rzucić wyjątek *)
      Printf.sprintf "%s{ FerdekValue ret = %s; ferdek_handler = entry_handler; return ret; }" ind v
  | Try (try_stmts, var, catch_stmts) ->
      let h = fresh ctx "handler" in
      Printf.sprintf "%s{\n%s    Handler %s;\n%s    %s.prev = ferdek_handler;\n%s    ferdek_handler = &%s;\n%s    if (setjmp(%s.buf) == 0) {\n%s\n%s        ferdek_handler = %s.prev;\n%s    } else {\n%s        ferdek_handler = %s.prev;\n%s        %s = ferdek_exception;\n%s\n%s    }\n%s}"
        ind ind h ind h ind h ind h
        (String.concat "\n" (List.map (compile_stmt ctx (indent + 2)) try_stmts))
        ind h ind ind h ind (var_c var)
        (String.concat "\n" (List.map (compile_stmt ctx (indent + 2)) catch_stmts))
        ind ind
  | Throw e -> Printf.sprintf "%sferdek_throw(%s);" ind (compile_expr ctx e)
  | Break | Continue ->
      let kw = if stmt = Break then "break;" else "continue;" in
      (match ctx.loop_handlers with
       | h :: _ when h <> "" -> Printf.sprintf "%sferdek_handler = %s; %s" ind h kw
       | _ -> ind ^ kw)

(* ============ FUNCTIONS ============ *)

let fun_proto (f : function_decl) =
  let params = List.map (fun p -> "FerdekValue " ^ var_c p) f.params in
  Printf.sprintf "FerdekValue %s(%s)" (fun_c f.name)
    (if params = [] then "void" else String.concat ", " params)

let compile_function ctx (f : function_decl) =
  let decl, assigned = block_names ([], []) f.body in
  (* Przypisanie do istniejącej zmiennej globalnej zmienia globalną (jak set_var w interpreterze) *)
  let assigned_locals = List.filter (fun n -> not (Hashtbl.mem ctx.globals n)) assigned in
  let locals = dedup (decl @ assigned_locals)
               |> List.filter (fun n -> not (List.mem n f.params)) in
  ctx.locals <- f.params @ locals;
  ctx.in_function <- true;
  (* setjmp: lokalne zmieniane w try muszą być volatile, inaczej po longjmp mają śmieci.
     ponytail: parametry nie są volatile - przypisanie do parametru w try i odczyt w catch to UB *)
  let qual = if has_try f.body then "volatile " else "" in
  let decls = "    Handler* entry_handler = ferdek_handler;"
    :: List.map (fun n -> Printf.sprintf "    %sFerdekValue %s = make_null();" qual (var_c n)) locals in
  let body = List.map (compile_stmt ctx 1) f.body in
  ctx.locals <- [];
  ctx.in_function <- false;
  String.concat "\n" ([Printf.sprintf "%s {" (fun_proto f)] @ decls @ body
                      @ ["    ferdek_handler = entry_handler;"; "    return make_null();"; "}"])


(* ============ TOP-LEVEL ============ *)

let compile_top_level ctx decl =
  match decl with
  | Statement stmt -> compile_stmt ctx 1 stmt
  | FunctionDecl _ -> ""
  | EnumDecl e ->
      (* Jak w interpreterze: wartości enuma to zwykłe stałe, numerowane od poprzedniej + 1 *)
      let _, lines = List.fold_left (fun (next, acc) (name, v) ->
        let v = Option.value v ~default:next in
        (v + 1, Printf.sprintf "    %s = make_int(%dLL);" (var_c name) v :: acc)) (0, []) e.values in
      String.concat "\n" (List.rev lines)
  | Import _ -> ""  (* rozwinięte wcześniej przez expand_imports *)
  | ClassDecl _ -> unsupported "klasy (ALE JAJA)"
  | StructDecl _ -> unsupported "struktury (MEBEL)"
  | UnionDecl _ -> unsupported "unie (WCHODZIMY DO UNII)"

(* ============ RUNTIME LIBRARY ============ *)

let runtime_library = {|/* Ferdek Runtime Library */
/* Nie każdy program używa każdej funkcji runtime'u */
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
/* ponytail: brak GC - pamięć stringów i tablic nie jest zwalniana (programy są krótkie) */

typedef enum {
    TYPE_NULL = 0,   /* zero-inicjalizowane zmienne globalne = null */
    TYPE_INT,
    TYPE_STRING,
    TYPE_BOOL,
    TYPE_ARRAY
} ValueType;

typedef struct FerdekValue FerdekValue;
typedef struct { FerdekValue* data; int length; } FerdekArray;

struct FerdekValue {
    ValueType type;
    union {
        long long int_val;
        char* string_val;
        bool bool_val;
        FerdekArray* array_val;   /* wskaźnik: kopia wartości współdzieli tablicę, jak w interpreterze */
    } value;
};

static void ferdek_die(const char* fmt, ...) {
    va_list ap;
    fflush(stdout);
    fprintf(stderr, "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: Runtime error: ");
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fprintf(stderr, "\n");
    exit(1);
}

static FerdekValue make_int(long long n) { FerdekValue v; v.type = TYPE_INT; v.value.int_val = n; return v; }
static FerdekValue make_bool(bool b) { FerdekValue v; v.type = TYPE_BOOL; v.value.bool_val = b; return v; }
static FerdekValue make_null(void) { FerdekValue v; v.type = TYPE_NULL; return v; }

static FerdekValue make_string(const char* s) {
    FerdekValue v;
    v.type = TYPE_STRING;
    v.value.string_val = strdup(s);
    return v;
}

static FerdekValue make_array(FerdekValue* data, int length) {
    FerdekValue v;
    v.type = TYPE_ARRAY;
    v.value.array_val = malloc(sizeof(FerdekArray));
    v.value.array_val->data = malloc(sizeof(FerdekValue) * (length > 0 ? length : 1));
    if (length > 0) memcpy(v.value.array_val->data, data, sizeof(FerdekValue) * length);
    v.value.array_val->length = length;
    return v;
}

static long long to_int(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: return v.value.int_val;
        case TYPE_BOOL: return v.value.bool_val ? 1 : 0;
        case TYPE_STRING: {
            /* jak int_of_string w interpreterze: cały string musi być liczbą, inaczej 0 */
            char* end;
            long long n = strtoll(v.value.string_val, &end, 10);
            return (*v.value.string_val && !*end) ? n : 0;
        }
        case TYPE_NULL: return 0;
        default: ferdek_die("Cannot convert to integer"); return 0;
    }
}

static bool to_bool(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: return v.value.int_val != 0;
        case TYPE_BOOL: return v.value.bool_val;
        case TYPE_STRING: return v.value.string_val[0] != '\0';
        case TYPE_NULL: return false;
        default: return true;
    }
}

/* Prosty bufor do sklejania stringów */
typedef struct { char* s; size_t len, cap; } StrBuf;

static void buf_add(StrBuf* b, const char* t) {
    size_t n = strlen(t);
    if (b->len + n + 1 > b->cap) {
        b->cap = (b->len + n + 1) * 2;
        b->s = realloc(b->s, b->cap);
    }
    memcpy(b->s + b->len, t, n + 1);
    b->len += n;
}

/* Tekstowa postać wartości - identyczna jak string_of_value w interpreterze */
static char* to_str(FerdekValue v) {
    char num[32];
    switch (v.type) {
        case TYPE_INT: snprintf(num, sizeof num, "%lld", v.value.int_val); return strdup(num);
        case TYPE_STRING: return strdup(v.value.string_val);
        case TYPE_BOOL: return strdup(v.value.bool_val ? "true" : "false");
        case TYPE_NULL: return strdup("null");
        case TYPE_ARRAY: {
            StrBuf b = {0};
            buf_add(&b, "[");
            for (int i = 0; i < v.value.array_val->length; i++) {
                char* item = to_str(v.value.array_val->data[i]);
                if (i > 0) buf_add(&b, ", ");
                buf_add(&b, item);
                free(item);
            }
            buf_add(&b, "]");
            return b.s;
        }
    }
    return strdup("?");
}

static FerdekValue op_add(FerdekValue a, FerdekValue b) { return make_int(to_int(a) + to_int(b)); }
static FerdekValue op_sub(FerdekValue a, FerdekValue b) { return make_int(to_int(a) - to_int(b)); }
static FerdekValue op_mul(FerdekValue a, FerdekValue b) { return make_int(to_int(a) * to_int(b)); }

static FerdekValue op_div(FerdekValue a, FerdekValue b) {
    long long d = to_int(b);
    if (d == 0) ferdek_die("Division by zero");
    return make_int(to_int(a) / d);
}

static FerdekValue op_mod(FerdekValue a, FerdekValue b) {
    long long d = to_int(b);
    if (d == 0) ferdek_die("Modulo by zero");
    return make_int(to_int(a) % d);
}

/* Stringi porównujemy jako tekst, resztę jako liczby (jak interpreter) */
static int compare_values(FerdekValue a, FerdekValue b) {
    if (a.type == TYPE_STRING && b.type == TYPE_STRING) {
        int c = strcmp(a.value.string_val, b.value.string_val);
        return (c > 0) - (c < 0);
    }
    long long x = to_int(a), y = to_int(b);
    return (x > y) - (x < y);
}

/* Interpreter liczy obie strony (bez short-circuit) - funkcja robi to samo */
static FerdekValue logic_and(FerdekValue a, FerdekValue b) { return make_bool(to_bool(a) && to_bool(b)); }
static FerdekValue logic_or(FerdekValue a, FerdekValue b) { return make_bool(to_bool(a) || to_bool(b)); }

static FerdekArray* as_array(FerdekValue a) {
    if (a.type != TYPE_ARRAY) ferdek_die("Not an array");
    return a.value.array_val;
}

static FerdekValue array_get(FerdekValue a, long long i) {
    FerdekArray* arr = as_array(a);
    if (i < 0 || i >= arr->length) ferdek_die("Array index out of bounds: %lld", i);
    return arr->data[i];
}

static void array_set(FerdekValue a, long long i, FerdekValue v) {
    FerdekArray* arr = as_array(a);
    if (i < 0 || i >= arr->length) ferdek_die("Indeks poza zakresem: %lld", i);
    arr->data[i] = v;
}

/* Wyjątki: stos handlerów na setjmp/longjmp */
typedef struct Handler { jmp_buf buf; struct Handler* prev; } Handler;
static Handler* ferdek_handler = NULL;
static FerdekValue ferdek_exception;

static void ferdek_throw(FerdekValue v) {
    if (ferdek_handler == NULL) {
        char* s = to_str(v);
        fflush(stdout);
        fprintf(stderr, "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: Uncaught exception: %s\n", s);
        exit(1);
    }
    ferdek_exception = v;
    longjmp(ferdek_handler->buf, 1);
}

static void print_value(FerdekValue v) {
    char* s = to_str(v);
    puts(s);
    free(s);
}

static FerdekValue read_value(void) {
    char buffer[1024];
    if (fgets(buffer, sizeof(buffer), stdin) == NULL) return make_null();
    buffer[strcspn(buffer, "\n")] = 0;
    FerdekValue s = make_string(buffer);
    return (to_int(s) != 0 || strcmp(buffer, "0") == 0) ? make_int(to_int(s)) : s;
}
|}

(* ============ PROGRAM ============ *)

(* Import = wklejenie deklaracji modułu w miejscu importu (jak wykonanie w interpreterze).
   Każdy moduł raz - ponowny import niczego nie zmienia. *)
let expand_imports load_module decls =
  let seen = Hashtbl.create 8 in
  let rec expand decls = List.concat_map (function
    | Import name when Hashtbl.mem seen name -> []
    | Import name ->
        Hashtbl.add seen name ();
        (match load_module name with
         | Some m -> expand m.declarations
         | None -> error (Printf.sprintf "Nie ma takiego modułu: %s" name))
    | d -> [d]) decls
  in
  expand decls

let compile_program ?(load_module = fun _ -> None) prog =
  let prog = { declarations = expand_imports load_module prog.declarations } in
  let ctx = { funcs = Hashtbl.create 16; globals = Hashtbl.create 64; locals = [];
              in_function = false; loop_handlers = []; counter = 0 } in
  List.iter (function
    | FunctionDecl f -> Hashtbl.replace ctx.funcs f.name f
    | EnumDecl e -> List.iter (fun (n, _) -> Hashtbl.replace ctx.globals n ()) e.values
    | Statement s ->
        let decl, assigned = stmt_names ([], []) s in
        List.iter (fun n -> Hashtbl.replace ctx.globals n ()) (decl @ assigned)
    | _ -> ()) prog.declarations;

  let functions = List.filter_map (function
    | FunctionDecl f -> Some (compile_function ctx f)
    | _ -> None) prog.declarations in
  let main_body = List.map (compile_top_level ctx) prog.declarations
                  |> List.filter (fun s -> s <> "") in
  let globals = Hashtbl.fold (fun n () acc -> n :: acc) ctx.globals [] |> dedup
                |> List.map (fun n -> Printf.sprintf "static FerdekValue %s;" (var_c n)) in
  let protos = Hashtbl.fold (fun _ f acc -> (fun_proto f ^ ";") :: acc) ctx.funcs [] |> dedup in

  String.concat "\n" ([
    "#include <stdio.h>";
    "#include <stdlib.h>";
    "#include <string.h>";
    "#include <stdbool.h>";
    "#include <stdarg.h>";
    "#include <setjmp.h>";
    "";
    runtime_library;
  ] @ globals @ [""] @ protos @ [""] @ functions @ [
    "";
    "int main(void) {";
  ] @ main_body @ [
    "    return 0;";
    "}";
    "";
  ])
