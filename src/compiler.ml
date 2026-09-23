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
  | For (v, _, _, _, b) -> block_names (decl, v :: assigned) b
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
  ["ZNAK Z KANAPY"], ("b_kanapa_znak", Some 2);
  ["KANAPA DO GÓRY"], ("b_kanapa_do_gory", Some 1);
  ["KANAPA W DÓŁ"], ("b_kanapa_w_dol", Some 1);
  ["ILE NA WERSALCE"], ("b_wersalka_ile", Some 1);
  ["POŁÓŻ NA WERSALCE"], ("b_wersalka_poloz", Some 2);
  ["ZDEJMIJ Z WERSALKI"], ("b_wersalka_zdejmij", Some 1);
  ["CZY LEŻY NA WERSALCE"], ("b_wersalka_czy_lezy", Some 2);
  ["ZRÓB BAJCIK"; "ZROB BAJCIK"], ("b_zrob_bajcik", Some 1);
  ["ZRÓB KRÓTKI"; "ZROB KROTKI"], ("b_zrob_krotki", Some 1);
  ["ZRÓB DŁUGI"; "ZROB DLUGI"], ("b_zrob_dlugi", Some 1);
  ["ZRÓB UŁAMEK"; "ZROB ULAMEK"], ("b_zrob_ulamek", Some 1);
  ["CO TO ZA TYP"], ("b_co_to_za_typ", Some 1);
  ["KARTA LUBI DYM"], ("b_karta_lubi_dym", None);
  ["TABLICA 2D"], ("b_tablica_2d", Some 2);
  ["OTWÓRZ SZAFKĘ"], ("b_szafka_otworz", Some 0);
  ["WŁÓŻ DO SZAFKI"], ("b_szafka_wloz", Some 3);
  ["WYJMIJ Z SZAFKI"], ("b_szafka_wyjmij", Some 2);
  ["WYRZUĆ ZE SZAFKI"], ("b_szafka_wyrzuc", Some 2);
  ["CZY W SZAFCE"], ("b_szafka_czy_w", Some 2);
  ["WSZYSTKIE SZUFLADKI"], ("b_szafka_szufladki", Some 1);
  ["ILE W SZAFCE"], ("b_szafka_ile", Some 1);
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
  | While (_, b) | For (_, _, _, _, b) -> has_try b
  | Located (_, _, s) -> has_try [s]
  | _ -> false) stmts

let is_var ctx name = List.mem name ctx.locals || Hashtbl.mem ctx.globals name

(* Zmienna lokalna przesłania funkcję; funkcja wygrywa z globalną o tej samej nazwie *)
let is_function_name ctx name =
  Hashtbl.mem ctx.funcs name && not (List.mem name ctx.locals)


let comparison_c = function
  | Equal -> "CMP_EQ" | NotEqual -> "CMP_NE" | Greater -> "CMP_GT" | Less -> "CMP_LT" | GreaterEqual -> "CMP_GE"

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
  | FloatLiteral f -> Printf.sprintf "make_float(%.17g)" f
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
      Printf.sprintf "compare_op(%s, %s, %s)"
        (compile_expr ctx e1) (compile_expr ctx e2) (comparison_c op)
  | LogicalOp (e1, op, e2) ->
      Printf.sprintf "%s(%s, %s)" (match op with And -> "logic_and" | Or -> "logic_or")
        (compile_expr ctx e1) (compile_expr ctx e2)
  | BitwiseOp (e1, op, e2) ->
      Printf.sprintf "make_int(to_int(%s) %s to_int(%s))"
        (compile_expr ctx e1) (bitwise_c op) (compile_expr ctx e2)
  | BitwiseNot e -> Printf.sprintf "make_int(~to_int(%s))" (compile_expr ctx e)
  | LogicalNot e -> Printf.sprintf "make_bool(!to_bool(%s))" (compile_expr ctx e)
  | ArrayLiteral [] -> "make_array(NULL, 0)"
  | ArrayLiteral es ->
      Printf.sprintf "make_array((FerdekValue[]){%s}, %d)"
        (String.concat ", " (List.map (compile_expr ctx) es)) (List.length es)
  | ToFixed e -> Printf.sprintf "to_fixed(%s)" (compile_expr ctx e)
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
           error (Printf.sprintf "%s oczekuje %s, podano %d" name (Errors.argumentow n) (List.length args))
       | _ -> ());
      Printf.sprintf "%s(%d, %s)" c_name (List.length args) (argv_c c_args)
  | None, Some f when is_function_name ctx name ->
      let n = List.length f.params in
      let given = List.length args in
      if f.is_variadic then begin
        if given < n then
          error (Printf.sprintf "Funkcja %s oczekuje co najmniej %s, podano %d" name (Errors.argumentow n) given);
        let fixed = List.filteri (fun i _ -> i < n) c_args in
        let rest = List.filteri (fun i _ -> i >= n) c_args in
        Printf.sprintf "%s(%s)" (fun_c name)
          (String.concat ", " (fixed @ [Printf.sprintf "make_array(%s, %d)" (argv_c rest) (List.length rest)]))
      end else begin
        if given <> n then
          error (Printf.sprintf "Funkcja %s oczekuje %s, podano %d" name (Errors.argumentow n) given);
        Printf.sprintf "%s(%s)" (fun_c name) (String.concat ", " c_args)
      end
  | None, _ when is_var ctx name ->
      (* Wywołanie funkcji trzymanej w zmiennej - sprawdzenie typu i arności w runtime *)
      Printf.sprintf "call_value(%s, %s, %d, %s)" (var_c name) (c_string_literal name)
        (List.length args) (argv_c c_args)
  | None, _ ->
      error (Printf.sprintf "Nieznana funkcja: %s (albo wbudowana, której kompilator nie zna)" name)

(* Ciało pętli; gdy w środku jest try, break/continue muszą zdjąć handlery założone w pętli *)
let rec loop_body ctx indent body =
  let h = if has_try body then fresh ctx "loop_handler" else "" in
  let saved = ctx.loop_handlers in
  ctx.loop_handlers <- h :: saved;
  let code = String.concat "\n" (List.map (compile_stmt ctx (indent + 1)) body) in
  ctx.loop_handlers <- saved;
  let setup = if h = "" then "" else Printf.sprintf "%s    Handler* %s = ferdek_handler;\n" (String.make (indent * 4) ' ') h in
  (setup, code)

and compile_stmt ctx indent stmt =
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
  | While (cond, body) ->
      let setup, body_code = loop_body ctx indent body in
      Printf.sprintf "%s{\n%s%swhile (to_bool(%s)) {\n%s\n%s}\n%s}"
        ind setup ind (compile_expr ctx cond) body_code ind ind
  | For (var, from_e, to_e, step_e, body) ->
      (* Kolejność jak w interpreterze: od, do, krok; C-owe for robi krok także po continue *)
      let n = fresh ctx "" in
      let v = var_c var in
      let step = match step_e with None -> "1" | Some e -> Printf.sprintf "to_int(%s)" (compile_expr ctx e) in
      let setup, body_code = loop_body ctx indent body in
      String.concat "\n" [
        ind ^ "{";
        Printf.sprintf "%s    long long for_start%s = to_int(%s);" ind n (compile_expr ctx from_e);
        Printf.sprintf "%s    long long for_stop%s = to_int(%s);" ind n (compile_expr ctx to_e);
        Printf.sprintf "%s    long long for_step%s = %s;" ind n step;
        Printf.sprintf "%s    if (for_step%s == 0) ferdek_die(\"KRĘCI CEMENT BETONIARA: krok nie może być zerem\");" ind n;
        setup ^ Printf.sprintf "%sfor (%s = make_int(for_start%s); for_step%s > 0 ? to_int(%s) <= for_stop%s : to_int(%s) >= for_stop%s; %s = make_int(to_int(%s) + for_step%s)) {"
          ind v n n v n v n v v n;
        body_code;
        ind ^ "}";
        ind ^ "}" ]
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
#pragma GCC diagnostic ignored "-Wunused-variable"
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
    TYPE_FUNCTION,
    TYPE_MAP,
    TYPE_FLOAT
} ValueType;

typedef struct FerdekValue FerdekValue;
typedef struct { FerdekValue* data; int length; } FerdekArray;
/* ponytail: mapa jako tablica par z wyszukiwaniem liniowym; hash, gdy mapy urosną do tysięcy kluczy */
typedef struct { char** keys; FerdekValue* vals; int len, cap; } FerdekMap;

struct FerdekValue {
    ValueType type;
    union {
        long long int_val;
        double float_val;
        char* string_val;
        bool bool_val;
        FerdekArray* array_val;   /* wskaźnik: kopia wartości współdzieli tablicę, jak w interpreterze */
        struct { FerdekValue (*call)(int, FerdekValue*); const char* name; int arity; bool variadic; } fn_val;
        FerdekMap* map_val;       /* wskaźnik: kopia wartości współdzieli mapę, jak w interpreterze */
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
    fprintf(stderr, "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: ");
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    print_loc();
    fprintf(stderr, "\n");
    exit(1);
}

static FerdekValue make_int(long long n) { FerdekValue v; v.type = TYPE_INT; v.value.int_val = n; return v; }
static FerdekValue make_float(double f) { FerdekValue v; v.type = TYPE_FLOAT; v.value.float_val = f; return v; }
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

static bool is_decimal(const char* s) {
    if (*s == '-') s++;
    if (!*s) return false;
    for (; *s; s++) if (*s < '0' || *s > '9') return false;
    return true;
}

static bool is_numeric(FerdekValue v) { return v.type != TYPE_STRING || is_decimal(v.value.string_val); }

static long long to_int(FerdekValue v);
static double to_float(FerdekValue v) { return v.type == TYPE_FLOAT ? v.value.float_val : (double)to_int(v); }

static long long to_int(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED: return v.value.int_val;
        case TYPE_BOOL: return v.value.bool_val ? 1 : 0;
        case TYPE_STRING:
            /* tylko zapis dziesiętny - jak decimal_of_string w interpreterze */
            if (!is_decimal(v.value.string_val)) ferdek_die("Tekst \"%s\" to nie liczba", v.value.string_val);
            return strtoll(v.value.string_val, NULL, 10);
        case TYPE_NULL: return 0;
        case TYPE_FLOAT: ferdek_die("Liczba z przecinkiem tam, gdzie trzeba całkowitej (użyj ZRÓB DŁUGI)"); return 0;
        default: ferdek_die("Tego nie da się zamienić na liczbę"); return 0;
    }
}

static bool to_bool(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED: return v.value.int_val != 0;
        case TYPE_BOOL: return v.value.bool_val;
        case TYPE_STRING: return v.value.string_val[0] != '\0';
        case TYPE_FLOAT: return v.value.float_val != 0.0;
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

static int map_find(FerdekMap* m, const char* key) {
    for (int i = 0; i < m->len; i++) if (strcmp(m->keys[i], key) == 0) return i;
    return -1;
}

static int cmp_key_ptr(const void* a, const void* b) { return strcmp(*(char* const*)a, *(char* const*)b); }

/* Klucze posortowane - jak w interpreterze; zwraca nową tablicę wskaźników */
static char** map_sorted_keys(FerdekMap* m) {
    char** keys = malloc(sizeof(char*) * (m->len > 0 ? m->len : 1));
    memcpy(keys, m->keys, sizeof(char*) * m->len);
    qsort(keys, m->len, sizeof(char*), cmp_key_ptr);
    return keys;
}

/* Tekstowa postać wartości - identyczna jak string_of_value w interpreterze */
static char* to_str(FerdekValue v) {
    char num[32];
    switch (v.type) {
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED:
            snprintf(num, sizeof num, "%lld", v.value.int_val);
            return strdup(num);
        case TYPE_STRING: return strdup(v.value.string_val);
        case TYPE_FLOAT:
            /* jak string_of_float_ferdek: %.15g i ".0" dla całych */
            snprintf(num, sizeof num - 2, "%.15g", v.value.float_val);
            if (!strpbrk(num, ".en")) strcat(num, ".0");
            return strdup(num);
        case TYPE_BOOL: return strdup(v.value.bool_val ? "true" : "false");
        case TYPE_NULL: return strdup("null");
        case TYPE_MAP: {
            FerdekMap* m = v.value.map_val;
            char** keys = map_sorted_keys(m);
            StrBuf b = {0};
            buf_add(&b, "{");
            for (int i = 0; i < m->len; i++) {
                char* item = to_str(m->vals[map_find(m, keys[i])]);
                if (i > 0) buf_add(&b, ", ");
                buf_add(&b, keys[i]);
                buf_add(&b, ": ");
                buf_add(&b, item);
                free(item);
            }
            buf_add(&b, "}");
            free(keys);
            return b.s;
        }
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

/* + z tekstem po którejkolwiek stronie skleja - jak w interpreterze */
static FerdekValue op_add(FerdekValue a, FerdekValue b) {
    if (a.type == TYPE_STRING || b.type == TYPE_STRING) {
        StrBuf buf = {0};
        char* x = to_str(a);
        char* y = to_str(b);
        buf_add(&buf, x);
        buf_add(&buf, y);
        free(x);
        free(y);
        FerdekValue v;
        v.type = TYPE_STRING;
        v.value.string_val = buf.s;
        return v;
    }
    if (a.type == TYPE_FLOAT || b.type == TYPE_FLOAT) return make_float(to_float(a) + to_float(b));
    return make_int(to_int(a) + to_int(b));
}
#define ANY_FLOAT(a, b) ((a).type == TYPE_FLOAT || (b).type == TYPE_FLOAT)

static FerdekValue op_sub(FerdekValue a, FerdekValue b) {
    return ANY_FLOAT(a, b) ? make_float(to_float(a) - to_float(b)) : make_int(to_int(a) - to_int(b));
}

static FerdekValue op_mul(FerdekValue a, FerdekValue b) {
    return ANY_FLOAT(a, b) ? make_float(to_float(a) * to_float(b)) : make_int(to_int(a) * to_int(b));
}

static FerdekValue op_div(FerdekValue a, FerdekValue b) {
    if (ANY_FLOAT(a, b)) {
        double d = to_float(b);
        if (d == 0.0) ferdek_die("Dzielenie przez zero");
        return make_float(to_float(a) / d);
    }
    long long d = to_int(b);
    if (d == 0) ferdek_die("Dzielenie przez zero");
    return make_int(to_int(a) / d);
}

static FerdekValue op_mod(FerdekValue a, FerdekValue b) {
    if (ANY_FLOAT(a, b)) {
        double d = to_float(b);
        if (d == 0.0) ferdek_die("Reszta z dzielenia przez zero");
        return make_float(fmod(to_float(a), d));
    }
    long long d = to_int(b);
    if (d == 0) ferdek_die("Reszta z dzielenia przez zero");
    return make_int(to_int(a) % d);
}

/* Jak w interpreterze: tekst z tekstem porównujemy jako tekst; tekst z liczbą
   przy ==/!= jest różny, przy >/< to błąd (chyba że tekst jest liczbą) */
enum { CMP_EQ, CMP_NE, CMP_GT, CMP_LT, CMP_GE };

static FerdekValue compare_op(FerdekValue a, FerdekValue b, int op) {
    int c;
    if (a.type == TYPE_STRING && b.type == TYPE_STRING) {
        c = strcmp(a.value.string_val, b.value.string_val);
        c = (c > 0) - (c < 0);
    } else if (is_numeric(a) && is_numeric(b) && ANY_FLOAT(a, b)) {
        double x = to_float(a), y = to_float(b);
        c = (x > y) - (x < y);
    } else if (is_numeric(a) && is_numeric(b)) {
        long long x = to_int(a), y = to_int(b);
        c = (x > y) - (x < y);
    } else if (op == CMP_EQ || op == CMP_NE) {
        c = 1;
    } else {
        ferdek_die("Nie można porównać tekstu z liczbą");
        c = 0;
    }
    switch (op) {
        case CMP_EQ: return make_bool(c == 0);
        case CMP_NE: return make_bool(c != 0);
        case CMP_GT: return make_bool(c > 0);
        case CMP_LT: return make_bool(c < 0);
        default: return make_bool(c >= 0);
    }
}

/* Interpreter liczy obie strony (bez short-circuit) - funkcja robi to samo */
static FerdekValue logic_and(FerdekValue a, FerdekValue b) { return make_bool(to_bool(a) && to_bool(b)); }
static FerdekValue logic_or(FerdekValue a, FerdekValue b) { return make_bool(to_bool(a) || to_bool(b)); }

/* "1 argumentu", "2 argumentów" - jak Errors.argumentow */
#define ARGUMENTOW(n) ((n) == 1 ? "argumentu" : "argumentów")

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
    if (f.type != TYPE_FUNCTION) ferdek_die("%s to nie funkcja", name);
    if (f.value.fn_val.variadic && argc < f.value.fn_val.arity)
        ferdek_die("Funkcja %s oczekuje co najmniej %d %s, podano %d", name, f.value.fn_val.arity, ARGUMENTOW(f.value.fn_val.arity), argc);
    if (!f.value.fn_val.variadic && argc != f.value.fn_val.arity)
        ferdek_die("Funkcja %s oczekuje %d %s, podano %d", name, f.value.fn_val.arity, ARGUMENTOW(f.value.fn_val.arity), argc);
    return f.value.fn_val.call(argc, argv);
}

static FerdekArray* as_array(FerdekValue a) {
    if (a.type != TYPE_ARRAY) ferdek_die("To nie jest tablica");
    return a.value.array_val;
}

static FerdekValue array_get(FerdekValue a, long long i) {
    FerdekArray* arr = as_array(a);
    if (i < 0 || i >= arr->length) ferdek_die("Array indeks poza zakresem");
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
        fprintf(stderr, "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: Nikt nie złapał wyjątku: %s", s);
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
    if (start < 0 || start >= len) ferdek_die("POTNIJ KANAPĘ: początek poza zakresem");
    if (end < start || end > len) ferdek_die("POTNIJ KANAPĘ: koniec poza zakresem");
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
    if (argv[0].type != TYPE_ARRAY) ferdek_die("POSKŁADAJ KANAPĘ: pierwszy argument musi być tablicą");
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

static FerdekValue b_kanapa_znak(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    long long i = to_int(argv[1]);
    if (i < 0 || i >= (long long)strlen(s)) ferdek_die("ZNAK Z KANAPY: indeks poza zakresem");
    char c[2] = { s[i], '\0' };
    free(s);
    return make_string(c);
}

/* Polskie litery w UTF-8: drugi bajt małej i wielkiej, pierwszy wspólny */
static const unsigned char polskie[][3] = {
    {0xC4, 0x85, 0x84}, {0xC4, 0x87, 0x86}, {0xC4, 0x99, 0x98}, {0xC5, 0x82, 0x81}, {0xC5, 0x84, 0x83},
    {0xC3, 0xB3, 0x93}, {0xC5, 0x9B, 0x9A}, {0xC5, 0xBA, 0xB9}, {0xC5, 0xBC, 0xBB},
};

static FerdekValue change_case(FerdekValue v, bool upper) {
    unsigned char* s = (unsigned char*)to_str(v);
    for (size_t i = 0; s[i]; i++) {
        if (s[i] < 0x80) { s[i] = upper ? toupper(s[i]) : tolower(s[i]); continue; }
        for (size_t k = 0; k < sizeof polskie / sizeof polskie[0] && s[i + 1]; k++) {
            if (s[i] == polskie[k][0] && s[i + 1] == polskie[k][upper ? 1 : 2]) {
                s[i + 1] = polskie[k][upper ? 2 : 1];
                break;
            }
        }
    }
    return own_string((char*)s);
}

static FerdekValue b_kanapa_do_gory(int argc, FerdekValue* argv) { return change_case(argv[0], true); }
static FerdekValue b_kanapa_w_dol(int argc, FerdekValue* argv) { return change_case(argv[0], false); }

static FerdekArray* list_arg(FerdekValue v, const char* msg) {
    if (v.type != TYPE_ARRAY) ferdek_die("%s", msg);
    return v.value.array_val;
}

static FerdekValue b_wersalka_ile(int argc, FerdekValue* argv) {
    return make_int(list_arg(argv[0], "ILE NA WERSALCE: argument musi być tablicą")->length);
}

/* Jak w interpreterze: zwraca nową tablicę, oryginał bez zmian */
static FerdekValue b_wersalka_poloz(int argc, FerdekValue* argv) {
    FerdekArray* arr = list_arg(argv[0], "POŁÓŻ NA WERSALCE: pierwszy argument musi być tablicą");
    FerdekValue out = make_array(arr->data, arr->length + 1);
    out.value.array_val->data[arr->length] = argv[1];
    return out;
}

static FerdekValue b_wersalka_zdejmij(int argc, FerdekValue* argv) {
    FerdekArray* arr = list_arg(argv[0], "ZDEJMIJ Z WERSALKI: argument musi być tablicą");
    if (arr->length == 0) ferdek_die("ZDEJMIJ Z WERSALKI: lista jest pusta");
    return arr->data[arr->length - 1];
}

static FerdekValue b_wersalka_czy_lezy(int argc, FerdekValue* argv) {
    FerdekArray* arr = list_arg(argv[0], "CZY LEŻY NA WERSALCE: pierwszy argument musi być tablicą");
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
/* Jawne obcięcie liczby z przecinkiem - jak int_of_float */
static FerdekValue b_zrob_dlugi(int argc, FerdekValue* argv) {
    return argv[0].type == TYPE_FLOAT ? make_int((long long)argv[0].value.float_val) : make_int(to_int(argv[0]));
}

static FerdekValue to_fixed(FerdekValue v) {
    return v.type == TYPE_FLOAT ? make_int((long long)(v.value.float_val * 65536.0)) : make_int(to_int(v) << 16);
}
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
        case TYPE_MAP: return make_string("SZAFKA");
        case TYPE_FLOAT: return make_string("PRZECINEK");
    }
    return make_string("?");
}

/* Ten sam LCG co w interpreterze - ten sam ziarno daje ten sam ciąg */
static long long ferdek_rng = -1;

static FerdekValue b_karta_lubi_dym(int argc, FerdekValue* argv) {
    if (argc == 1) { ferdek_rng = to_int(argv[0]) & 0x7FFFFFFF; return make_null(); }
    if (argc != 2) ferdek_die("KARTA LUBI DYM oczekuje 1 argumentu (ziarno) albo 2 (min, max)");
    long long lo = to_int(argv[0]), hi = to_int(argv[1]);
    if (lo > hi) ferdek_die("KARTA LUBI DYM: min większe niż max");
    if (ferdek_rng < 0) ferdek_rng = ((long long)time(NULL) * 1000 + clock()) & 0x7FFFFFFF;
    ferdek_rng = (ferdek_rng * 1103515245 + 12345) & 0x7FFFFFFF;
    return make_int(lo + ferdek_rng % (hi - lo + 1));
}

/* ---- SZAFKA (mapy; klucze to tekstowa postać argumentu, jak w interpreterze) ---- */

static FerdekMap* map_arg(FerdekValue v, const char* msg) {
    if (v.type != TYPE_MAP) ferdek_die("%s", msg);
    return v.value.map_val;
}

static FerdekValue b_szafka_otworz(int argc, FerdekValue* argv) {
    FerdekValue v;
    v.type = TYPE_MAP;
    v.value.map_val = calloc(1, sizeof(FerdekMap));
    return v;
}

static FerdekValue b_szafka_wloz(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "WŁÓŻ DO SZAFKI: pierwszy argument musi być szafką (mapą)");
    char* key = to_str(argv[1]);
    int i = map_find(m, key);
    if (i >= 0) { m->vals[i] = argv[2]; free(key); return make_null(); }
    if (m->len == m->cap) {
        m->cap = m->cap ? m->cap * 2 : 8;
        m->keys = realloc(m->keys, sizeof(char*) * m->cap);
        m->vals = realloc(m->vals, sizeof(FerdekValue) * m->cap);
    }
    m->keys[m->len] = key;
    m->vals[m->len++] = argv[2];
    return make_null();
}

static FerdekValue b_szafka_wyjmij(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "WYJMIJ Z SZAFKI: pierwszy argument musi być szafką (mapą)");
    char* key = to_str(argv[1]);
    int i = map_find(m, key);
    free(key);
    return i >= 0 ? m->vals[i] : make_null();
}

static FerdekValue b_szafka_wyrzuc(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "WYRZUĆ ZE SZAFKI: pierwszy argument musi być szafką (mapą)");
    char* key = to_str(argv[1]);
    int i = map_find(m, key);
    free(key);
    if (i >= 0) {
        free(m->keys[i]);
        m->keys[i] = m->keys[m->len - 1];   /* kolejność w środku bez znaczenia - wypisujemy posortowane */
        m->vals[i] = m->vals[m->len - 1];
        m->len--;
    }
    return make_null();
}

static FerdekValue b_szafka_czy_w(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "CZY W SZAFCE: pierwszy argument musi być szafką (mapą)");
    char* key = to_str(argv[1]);
    bool found = map_find(m, key) >= 0;
    free(key);
    return make_bool(found);
}

static FerdekValue b_szafka_szufladki(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "WSZYSTKIE SZUFLADKI: argument musi być szafką (mapą)");
    char** keys = map_sorted_keys(m);
    FerdekValue out = make_array(NULL, 0);
    out.value.array_val->data = malloc(sizeof(FerdekValue) * (m->len > 0 ? m->len : 1));
    for (int i = 0; i < m->len; i++) out.value.array_val->data[i] = make_string(keys[i]);
    out.value.array_val->length = m->len;
    free(keys);
    return out;
}

static FerdekValue b_szafka_ile(int argc, FerdekValue* argv) {
    return make_int(map_arg(argv[0], "ILE W SZAFCE: argument musi być szafką (mapą)")->len);
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
    if (rows <= 0 || cols <= 0) ferdek_die("TABLICA 2D: wymiary muszą być dodatnie");
    FerdekValue t = zeros(rows);
    for (long long i = 0; i < rows; i++) t.value.array_val->data[i] = zeros(cols);
    return t;
}

static FerdekValue b_tablica_3d(int argc, FerdekValue* argv) {
    long long x = to_int(argv[0]), y = to_int(argv[1]), z = to_int(argv[2]);
    if (x <= 0 || y <= 0 || z <= 0) ferdek_die("TABLICA 3D: wymiary muszą być dodatnie");
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
    return is_decimal(buffer) ? make_int(strtoll(buffer, NULL, 10)) : make_string(buffer);
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
    "#include <time.h>";
    "#include <ctype.h>";
    "#include <math.h>";
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
