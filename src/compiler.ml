(* Compiler for Ferdek Programming Language - Compiles to C *)
(* Kompilator obsługuje rdzeń języka. Wszystko inne kończy się Compile_error
   z czytelnym komunikatem - nigdy po cichu zepsutym kodem C. *)

open Ast

exception Compile_error of string

(* Pozycja kompilowanej instrukcji - doklejana do komunikatu *)
let cur_loc = ref ("", 0)

let error msg =
  let suffix = match !cur_loc with
    | (_, 0) -> ""
    | ("", l) -> Printf.sprintf " (linia %d)" l
    | (f, l) -> Printf.sprintf " (%s, linia %d)" f l
  in
  raise (Compile_error (msg ^ suffix))
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
let wrap_c = mangle "w_"   (* wrapper (argc, argv) - funkcja jako wartość *)

(* Zmienne zadeklarowane (VarDecl/ArrayDecl/catch) i przypisane w bloku.
   Ferdek nie ma zasięgu blokowego: zmienna z pętli żyje w całej funkcji. *)
let rec stmt_names (decl, assigned) = function
  | VarDecl (n, _) | ArrayDecl (n, _) -> (n :: decl, assigned)
  | Read n | Assign (n, _) | FunctionCallWithAssign (n, _, _) -> (decl, n :: assigned)
  | If (_, a, b) -> block_names (block_names (decl, assigned) a) (Option.value b ~default:[])
  | While (_, b) -> block_names (decl, assigned) b
  | Try (a, v, b) -> block_names (block_names (v :: decl, assigned) a) b
  | Located (_, _, s) -> stmt_names (decl, assigned) s
  | _ -> (decl, assigned)
and block_names acc stmts = List.fold_left stmt_names acc stmts

let dedup l = List.sort_uniq compare l

(* ============ BUILTINS ============ *)

(* Builtiny interpretera, które zna kompilator: nazwy Ferdka -> funkcja C i liczba argumentów
   (None = dowolna). Funkcje C mają sygnaturę b_x(int argc, FerdekValue* argv). *)
let builtins = [
  ["USIĄDŹ NA KANAPIE"; "USIADZ NA KANAPIE"], ("b_kanapa_usiadz", None);
  ["ROZCIĄGNIJ KANAPĘ"], ("b_kanapa_rozciagnij", Some 2);
  ["POTNIJ KANAPĘ"], ("b_kanapa_potnij", Some 3);
  ["PRZESUŃ NA KANAPIE"], ("b_kanapa_przesun", Some 2);
  ["POSKŁADAJ KANAPĘ"], ("b_kanapa_poskladaj", Some 2);
  ["WYTRZEP KANAPĘ"], ("b_kanapa_wytrzep", Some 1);
  ["ZAMIEŃ NA KANAPIE"], ("b_kanapa_zamien", Some 3);
  ["ILE MIEJSCA NA KANAPIE"], ("b_kanapa_ile", Some 1);
  ["ILE NA WERSALCE"], ("b_wersalka_ile", Some 1);
  ["POŁÓŻ NA WERSALCE"], ("b_wersalka_poloz", Some 2);
  ["ZDEJMIJ Z WERSALKI"], ("b_wersalka_zdejmij", Some 1);
  ["CZY LEŻY NA WERSALCE"], ("b_wersalka_czy_lezy", Some 2);
  ["ZRÓB BAJCIK"; "ZROB BAJCIK"], ("b_zrob_bajcik", Some 1);
  ["ZRÓB KRÓTKI"; "ZROB KROTKI"], ("b_zrob_krotki", Some 1);
  ["ZRÓB DŁUGI"; "ZROB DLUGI"], ("b_zrob_dlugi", Some 1);
  ["ZRÓB UŁAMEK"; "ZROB ULAMEK"], ("b_zrob_ulamek", Some 1);
  ["CO TO ZA TYP"], ("b_co_to_za_typ", Some 1);
  ["TABLICA 2D"], ("b_tablica_2d", Some 2);
  ["TABLICA 3D"], ("b_tablica_3d", Some 3);
]

let find_builtin name =
  List.find_map (fun (names, b) -> if List.mem name names then Some b else None) builtins

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
  | Located (_, _, s) -> has_try [s]
  | _ -> false) stmts

let is_var ctx name = List.mem name ctx.locals || Hashtbl.mem ctx.globals name

(* Zmienna lokalna przesłania funkcję; funkcja wygrywa z globalną o tej samej nazwie *)
let is_function_name ctx name =
  Hashtbl.mem ctx.funcs name && not (List.mem name ctx.locals)


let comparison_c = function
  | Equal -> "==" | NotEqual -> "!=" | Greater -> ">" | Less -> "<" | GreaterEqual -> ">="

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

let function_value ctx name =
  let f = Hashtbl.find ctx.funcs name in
  Printf.sprintf "make_function(%s, %s, %d, %s)" (wrap_c name) (c_string_literal name)
    (List.length f.params) (if f.is_variadic then "true" else "false")

(* Tablica argumentów dla wywołań (argc, argv) *)
let argv_c c_args = if c_args = [] then "(FerdekValue[]){make_null()}" else
  Printf.sprintf "(FerdekValue[]){%s}" (String.concat ", " c_args)

let rec compile_expr ctx expr =
  match expr with
  | IntLiteral n -> Printf.sprintf "make_int(%dLL)" n
  | StringLiteral s -> Printf.sprintf "make_string(%s)" (c_string_literal s)
  | BoolLiteral b -> Printf.sprintf "make_bool(%s)" (if b then "true" else "false")
  | NullLiteral -> "make_null()"
  | Identifier name | Reference (Identifier name) when is_function_name ctx name ->
      function_value ctx name
  | Identifier name ->
      if is_var ctx name then var_c name
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
  | LogicalNot e -> Printf.sprintf "make_bool(!to_bool(%s))" (compile_expr ctx e)
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
  | FunctionRef name when is_function_name ctx name -> function_value ctx name
  | FunctionRef name -> error (Printf.sprintf "Nieznana funkcja: %s" name)

and compile_call ctx name args =
  let c_args = List.map (compile_expr ctx) args in
  (* Builtiny mają pierwszeństwo przed funkcjami użytkownika - jak w interpreterze *)
  match find_builtin name, Hashtbl.find_opt ctx.funcs name with
  | Some (c_name, arity), _ ->
      (match arity with
       | Some n when n <> List.length args ->
           error (Printf.sprintf "%s oczekuje %d argumentów, podano %d" name n (List.length args))
       | _ -> ());
      Printf.sprintf "%s(%d, %s)" c_name (List.length args) (argv_c c_args)
  | None, Some f when is_function_name ctx name ->
      let n = List.length f.params in
      let given = List.length args in
      if f.is_variadic then begin
        if given < n then
          error (Printf.sprintf "Funkcja %s oczekuje co najmniej %d argumentów, podano %d" name n given);
        let fixed = List.filteri (fun i _ -> i < n) c_args in
        let rest = List.filteri (fun i _ -> i >= n) c_args in
        Printf.sprintf "%s(%s)" (fun_c name)
          (String.concat ", " (fixed @ [Printf.sprintf "make_array(%s, %d)" (argv_c rest) (List.length rest)]))
      end else begin
        if given <> n then
          error (Printf.sprintf "Funkcja %s oczekuje %d argumentów, podano %d" name n given);
        Printf.sprintf "%s(%s)" (fun_c name) (String.concat ", " c_args)
      end
  | None, _ when is_var ctx name ->
      (* Wywołanie funkcji trzymanej w zmiennej - sprawdzenie typu i arności w runtime *)
      Printf.sprintf "call_value(%s, %s, %d, %s)" (var_c name) (c_string_literal name)
        (List.length args) (argv_c c_args)
  | None, _ ->
      error (Printf.sprintf "Nieznana funkcja: %s (albo wbudowana, której kompilator nie zna)" name)

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
  | PrintInline e -> Printf.sprintf "%sprint_inline(%s);" ind (compile_expr ctx e)
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
      Printf.sprintf "%s{ FerdekValue ret = %s; ferdek_handler = entry_handler; FERDEK_AT(entry_file, entry_line); return ret; }" ind v
  | Try (try_stmts, var, catch_stmts) ->
      let h = fresh ctx "handler" in
      Printf.sprintf "%s{\n%s    Handler %s;\n%s    %s.prev = ferdek_handler;\n%s    ferdek_handler = &%s;\n%s    if (setjmp(%s.buf) == 0) {\n%s\n%s        ferdek_handler = %s.prev;\n%s    } else {\n%s        ferdek_handler = %s.prev;\n%s        %s = ferdek_exception;\n%s\n%s    }\n%s}"
        ind ind h ind h ind h ind h
        (String.concat "\n" (List.map (compile_stmt ctx (indent + 2)) try_stmts))
        ind h ind ind h ind (var_c var)
        (String.concat "\n" (List.map (compile_stmt ctx (indent + 2)) catch_stmts))
        ind ind
  | Throw e -> Printf.sprintf "%sferdek_throw(%s);" ind (compile_expr ctx e)
  | Located (file, line, s) ->
      cur_loc := (file, line);
      Printf.sprintf "%sFERDEK_AT(%s, %d);\n%s" ind (c_string_literal file) line (compile_stmt ctx indent s)
  | Break | Continue ->
      let kw = if stmt = Break then "break;" else "continue;" in
      (match ctx.loop_handlers with
       | h :: _ when h <> "" -> Printf.sprintf "%sferdek_handler = %s; %s" ind h kw
       | _ -> ind ^ kw)

(* ============ FUNCTIONS ============ *)

let all_params (f : function_decl) = f.params @ (if f.is_variadic then ["varargs"] else [])

let fun_proto (f : function_decl) =
  let params = List.map (fun p -> "FerdekValue " ^ var_c p) (all_params f) in
  Printf.sprintf "FerdekValue %s(%s)" (fun_c f.name)
    (if params = [] then "void" else String.concat ", " params)

let compile_function ctx (f : function_decl) =
  let decl, assigned = block_names ([], []) f.body in
  (* Przypisanie do istniejącej zmiennej globalnej zmienia globalną (jak set_var w interpreterze) *)
  let assigned_locals = List.filter (fun n -> not (Hashtbl.mem ctx.globals n)) assigned in
  let locals = dedup (decl @ assigned_locals)
               |> List.filter (fun n -> not (List.mem n (all_params f))) in
  ctx.locals <- all_params f @ locals;
  ctx.in_function <- true;
  (* setjmp: lokalne zmieniane w try muszą być volatile, inaczej po longjmp mają śmieci.
     ponytail: parametry nie są volatile - przypisanie do parametru w try i odczyt w catch to UB *)
  let qual = if has_try f.body then "volatile " else "" in
  let decls = "    Handler* entry_handler = ferdek_handler;"
    :: "    const char* entry_file = ferdek_file; int entry_line = ferdek_line;"
    :: List.map (fun n -> Printf.sprintf "    %sFerdekValue %s = make_null();" qual (var_c n)) locals in
  let body = List.map (compile_stmt ctx 1) f.body in
  ctx.locals <- [];
  ctx.in_function <- false;
  String.concat "\n" ([Printf.sprintf "%s {" (fun_proto f)] @ decls @ body
                      @ ["    ferdek_handler = entry_handler;"; "    FERDEK_AT(entry_file, entry_line);";
                         "    return make_null();"; "}"])


(* Wrapper (argc, argv) dla funkcji jako wartości; arność sprawdza call_value *)
let wrap_proto (f : function_decl) =
  Printf.sprintf "static FerdekValue %s(int argc, FerdekValue* argv)" (wrap_c f.name)

let compile_wrapper (f : function_decl) =
  let n = List.length f.params in
  let args = List.init n (Printf.sprintf "argv[%d]")
             @ (if f.is_variadic then [Printf.sprintf "make_array(argv + %d, argc - %d)" n n] else []) in
  String.concat "\n" [wrap_proto f ^ " {";
                      Printf.sprintf "    return %s(%s);" (fun_c f.name) (String.concat ", " args); "}"]

(* ============ TOP-LEVEL ============ *)

let compile_top_level ctx decl =
  (* Deklaracje (klasy, struktury...) nie mają pozycji - lepiej żadna niż cudza *)
  (match decl with Statement _ -> () | _ -> cur_loc := ("", 0));
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
#pragma GCC diagnostic ignored "-Wunused-parameter"
/* ponytail: brak GC - pamięć stringów i tablic nie jest zwalniana (programy są krótkie) */

typedef enum {
    TYPE_NULL = 0,   /* zero-inicjalizowane zmienne globalne = null */
    TYPE_INT,
    TYPE_STRING,
    TYPE_BOOL,
    TYPE_ARRAY,
    TYPE_BYTE,       /* ZRÓB BAJCIK/KRÓTKI/UŁAMEK - liczby z własnym typem dla CO TO ZA TYP */
    TYPE_SHORT,
    TYPE_FIXED,
    TYPE_FUNCTION
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
        struct { FerdekValue (*call)(int, FerdekValue*); const char* name; int arity; bool variadic; } fn_val;
    } value;
};

/* Plik i linia wykonywanej instrukcji - jak w interpreterze */
static const char* ferdek_file = "";
static int ferdek_line = 0;
#define FERDEK_AT(f, l) (ferdek_file = (f), ferdek_line = (l))

static void print_loc(void) {
    if (ferdek_line == 0) return;
    if (ferdek_file[0]) fprintf(stderr, " (%s, linia %d)", ferdek_file, ferdek_line);
    else fprintf(stderr, " (linia %d)", ferdek_line);
}

static void ferdek_die(const char* fmt, ...) {
    va_list ap;
    fflush(stdout);
    fprintf(stderr, "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: Runtime error: ");
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    print_loc();
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
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED: return v.value.int_val;
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
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED: return v.value.int_val != 0;
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
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED:
            snprintf(num, sizeof num, "%lld", v.value.int_val);
            return strdup(num);
        case TYPE_STRING: return strdup(v.value.string_val);
        case TYPE_BOOL: return strdup(v.value.bool_val ? "true" : "false");
        case TYPE_NULL: return strdup("null");
        case TYPE_FUNCTION: {
            StrBuf b = {0};
            buf_add(&b, "<function ");
            buf_add(&b, v.value.fn_val.name);
            buf_add(&b, ">");
            return b.s;
        }
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

static FerdekValue make_function(FerdekValue (*call)(int, FerdekValue*), const char* name, int arity, bool variadic) {
    FerdekValue v;
    v.type = TYPE_FUNCTION;
    v.value.fn_val.call = call;
    v.value.fn_val.name = name;
    v.value.fn_val.arity = arity;
    v.value.fn_val.variadic = variadic;
    return v;
}

/* name = nazwa użyta w wywołaniu (jak w komunikatach interpretera) */
static FerdekValue call_value(FerdekValue f, const char* name, int argc, FerdekValue* argv) {
    if (f.type != TYPE_FUNCTION) ferdek_die("%s is not a function", name);
    if (f.value.fn_val.variadic && argc < f.value.fn_val.arity)
        ferdek_die("Function %s expects at least %d arguments, got %d", name, f.value.fn_val.arity, argc);
    if (!f.value.fn_val.variadic && argc != f.value.fn_val.arity)
        ferdek_die("Function %s expects %d arguments, got %d", name, f.value.fn_val.arity, argc);
    return f.value.fn_val.call(argc, argv);
}

static FerdekArray* as_array(FerdekValue a) {
    if (a.type != TYPE_ARRAY) ferdek_die("Not an array");
    return a.value.array_val;
}

static FerdekValue array_get(FerdekValue a, long long i) {
    FerdekArray* arr = as_array(a);
    if (i < 0 || i >= arr->length) ferdek_die("Array index out of bounds");
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
        fprintf(stderr, "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: Uncaught exception: %s", s);
        print_loc();
        fprintf(stderr, "\n");
        exit(1);
    }
    ferdek_exception = v;
    longjmp(ferdek_handler->buf, 1);
}

/* ---- Builtiny (semantyka jak w interpreterze) ---- */

static FerdekValue make_typed(ValueType t, long long n) { FerdekValue v = make_int(n); v.type = t; return v; }

static FerdekValue own_string(char* s) {   /* bez kopiowania - s już zaalokowany */
    FerdekValue v;
    v.type = TYPE_STRING;
    v.value.string_val = s;
    return v;
}

static FerdekValue b_kanapa_usiadz(int argc, FerdekValue* argv) {
    StrBuf b = {0};
    buf_add(&b, "");
    for (int i = 0; i < argc; i++) {
        char* s = to_str(argv[i]);
        buf_add(&b, s);
        free(s);
    }
    return own_string(b.s);
}

static FerdekValue b_kanapa_rozciagnij(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    long long target = to_int(argv[1]);
    size_t len = strlen(s);
    if ((long long)len >= target) return own_string(s);
    s = realloc(s, target + 1);
    memset(s + len, ' ', target - len);
    s[target] = '\0';
    return own_string(s);
}

static FerdekValue b_kanapa_potnij(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    long long len = strlen(s), start = to_int(argv[1]), end = to_int(argv[2]);
    if (start < 0 || start >= len) ferdek_die("POTNIJ KANAPĘ: start index out of bounds");
    if (end < start || end > len) ferdek_die("POTNIJ KANAPĘ: end index out of bounds");
    s[end] = '\0';
    return make_string(s + start);
}

static FerdekValue b_kanapa_przesun(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    char* sep = to_str(argv[1]);
    size_t seplen = strlen(sep);
    FerdekValue parts = make_array(NULL, 0);
    FerdekArray* arr = parts.value.array_val;
    char* p = s;
    for (;;) {
        char* hit = seplen ? strstr(p, sep) : NULL;
        if (hit) *hit = '\0';
        arr->data = realloc(arr->data, sizeof(FerdekValue) * (arr->length + 1));
        arr->data[arr->length++] = make_string(p);
        if (!hit) break;
        p = hit + seplen;
    }
    return parts;
}

static FerdekValue b_kanapa_poskladaj(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_ARRAY) ferdek_die("POSKŁADAJ KANAPĘ expects an array as first argument");
    FerdekArray* arr = argv[0].value.array_val;
    char* sep = to_str(argv[1]);
    StrBuf b = {0};
    buf_add(&b, "");
    for (int i = 0; i < arr->length; i++) {
        char* item = to_str(arr->data[i]);
        if (i > 0) buf_add(&b, sep);
        buf_add(&b, item);
        free(item);
    }
    return own_string(b.s);
}

static bool is_trim_space(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f'; }

static FerdekValue b_kanapa_wytrzep(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    char* start = s;
    while (*start && is_trim_space(*start)) start++;
    char* end = start + strlen(start);
    while (end > start && is_trim_space(end[-1])) end--;
    *end = '\0';
    return make_string(start);
}

static FerdekValue b_kanapa_zamien(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    char* old = to_str(argv[1]);
    char* new = to_str(argv[2]);
    if (!*old) return own_string(s);
    StrBuf b = {0};
    buf_add(&b, "");
    char* p = s;
    char* hit;
    while ((hit = strstr(p, old)) != NULL) {
        *hit = '\0';
        buf_add(&b, p);
        buf_add(&b, new);
        p = hit + strlen(old);
    }
    buf_add(&b, p);
    return own_string(b.s);
}

static FerdekValue b_kanapa_ile(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    FerdekValue n = make_int((long long)strlen(s));
    free(s);
    return n;
}

static FerdekArray* list_arg(FerdekValue v, const char* msg) {
    if (v.type != TYPE_ARRAY) ferdek_die("%s", msg);
    return v.value.array_val;
}

static FerdekValue b_wersalka_ile(int argc, FerdekValue* argv) {
    return make_int(list_arg(argv[0], "ILE NA WERSALCE: argument must be an array")->length);
}

/* Jak w interpreterze: zwraca nową tablicę, oryginał bez zmian */
static FerdekValue b_wersalka_poloz(int argc, FerdekValue* argv) {
    FerdekArray* arr = list_arg(argv[0], "POŁÓŻ NA WERSALCE: first argument must be an array");
    FerdekValue out = make_array(arr->data, arr->length + 1);
    out.value.array_val->data[arr->length] = argv[1];
    return out;
}

static FerdekValue b_wersalka_zdejmij(int argc, FerdekValue* argv) {
    FerdekArray* arr = list_arg(argv[0], "ZDEJMIJ Z WERSALKI: argument must be an array");
    if (arr->length == 0) ferdek_die("ZDEJMIJ Z WERSALKI: lista jest pusta");
    return arr->data[arr->length - 1];
}

static FerdekValue b_wersalka_czy_lezy(int argc, FerdekValue* argv) {
    FerdekArray* arr = list_arg(argv[0], "CZY LEŻY NA WERSALCE: first argument must be an array");
    FerdekValue x = argv[1];
    for (int i = 0; i < arr->length; i++) {
        FerdekValue a = arr->data[i];
        if (a.type != x.type) continue;
        if ((a.type == TYPE_INT && a.value.int_val == x.value.int_val) ||
            (a.type == TYPE_STRING && strcmp(a.value.string_val, x.value.string_val) == 0) ||
            (a.type == TYPE_BOOL && a.value.bool_val == x.value.bool_val))
            return make_bool(true);
    }
    return make_bool(false);
}

static FerdekValue b_zrob_bajcik(int argc, FerdekValue* argv) { return make_typed(TYPE_BYTE, to_int(argv[0]) & 0xFF); }
static FerdekValue b_zrob_dlugi(int argc, FerdekValue* argv) { return make_int(to_int(argv[0])); }
static FerdekValue b_zrob_ulamek(int argc, FerdekValue* argv) { return make_typed(TYPE_FIXED, to_int(argv[0]) * 65536); }

static FerdekValue b_zrob_krotki(int argc, FerdekValue* argv) {
    long long m = to_int(argv[0]) & 0xFFFF;
    return make_typed(TYPE_SHORT, m > 0x7FFF ? m - 0x10000 : m);
}

static FerdekValue b_co_to_za_typ(int argc, FerdekValue* argv) {
    switch (argv[0].type) {
        case TYPE_BYTE: return make_string("BAJCIK");
        case TYPE_SHORT: return make_string("KRÓTKI");
        case TYPE_INT: return make_string("DŁUGI");
        case TYPE_FIXED: return make_string("UŁAMEK");
        case TYPE_STRING: return make_string("TEKST");
        case TYPE_BOOL: return make_string("PRAWDA/FAŁSZ");
        case TYPE_NULL: return make_string("NIC");
        case TYPE_ARRAY: return make_string("TABLICA");
        case TYPE_FUNCTION: return make_string("FUNKCJA");
    }
    return make_string("?");
}

static FerdekValue zeros(long long n) {
    FerdekValue v = make_array(NULL, 0);
    v.value.array_val->data = malloc(sizeof(FerdekValue) * n);
    for (long long i = 0; i < n; i++) v.value.array_val->data[i] = make_int(0);
    v.value.array_val->length = (int)n;
    return v;
}

static FerdekValue b_tablica_2d(int argc, FerdekValue* argv) {
    long long rows = to_int(argv[0]), cols = to_int(argv[1]);
    if (rows <= 0 || cols <= 0) ferdek_die("TABLICA 2D: dimensions must be positive");
    FerdekValue t = zeros(rows);
    for (long long i = 0; i < rows; i++) t.value.array_val->data[i] = zeros(cols);
    return t;
}

static FerdekValue b_tablica_3d(int argc, FerdekValue* argv) {
    long long x = to_int(argv[0]), y = to_int(argv[1]), z = to_int(argv[2]);
    if (x <= 0 || y <= 0 || z <= 0) ferdek_die("TABLICA 3D: dimensions must be positive");
    FerdekValue t = zeros(x);
    for (long long i = 0; i < x; i++) {
        FerdekValue plane = zeros(y);
        for (long long j = 0; j < y; j++) plane.value.array_val->data[j] = zeros(z);
        t.value.array_val->data[i] = plane;
    }
    return t;
}

static void print_value(FerdekValue v) {
    char* s = to_str(v);
    puts(s);
    free(s);
}

static void print_inline(FerdekValue v) {
    char* s = to_str(v);
    fputs(s, stdout);
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
  cur_loc := ("", 0);
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
  let protos = Hashtbl.fold (fun _ f acc -> (fun_proto f ^ ";") :: (wrap_proto f ^ ";") :: acc) ctx.funcs [] |> dedup in
  let wrappers = Hashtbl.fold (fun _ f acc -> compile_wrapper f :: acc) ctx.funcs [] |> dedup in

  String.concat "\n" ([
    "#include <stdio.h>";
    "#include <stdlib.h>";
    "#include <string.h>";
    "#include <stdbool.h>";
    "#include <stdarg.h>";
    "#include <setjmp.h>";
    "";
    runtime_library;
  ] @ globals @ [""] @ protos @ [""] @ functions @ [""] @ wrappers @ [
    "";
    "int main(void) {";
  ] @ main_body @ [
    "    return 0;";
    "}";
    "";
  ])
