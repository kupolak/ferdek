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
  ["POSKŁADAJ WERSALKĘ"], ("b_wersalka_posklada", None);
  ["ODWRÓĆ WERSALKĘ"], ("b_wersalka_odwroc", Some 1);
  ["PRZERABIAJ WERSALKĘ"], ("b_wersalka_przerabiaj", Some 2);
  ["PRZEFILTRUJ WERSALKĘ"], ("b_wersalka_przefiltruj", Some 2);
  ["ZRÓB BAJCIK"; "ZROB BAJCIK"], ("b_zrob_bajcik", Some 1);
  ["ZRÓB KRÓTKI"; "ZROB KROTKI"], ("b_zrob_krotki", Some 1);
  ["ZRÓB DŁUGI"; "ZROB DLUGI"], ("b_zrob_dlugi", Some 1);
  ["ZRÓB UŁAMEK"; "ZROB ULAMEK"], ("b_zrob_ulamek", Some 1);
  ["CO TO ZA TYP"], ("b_co_to_za_typ", Some 1);
  ["KARTA LUBI DYM"], ("b_karta_lubi_dym", None);
  ["TABLICA 2D"], ("b_tablica_2d", Some 2);
  ["OTWÓRZ KIBEL"], ("b_otworz_kibel", Some 1);
  ["OTWÓRZ KIBEL DO ZAPISU"], ("b_otworz_kibel_zapis", Some 1);
  ["ZAMKNIJ KIBEL"], ("b_zamknij_kibel", Some 1);
  ["SPUŚĆ WODĘ"], ("b_spusc_wode", Some 2);
  ["WYPOMPUJ"], ("b_wypompuj", Some 1);
  ["CZY KIBEL ZAJĘTY"], ("b_czy_kibel_zajety", Some 1);
  ["ZRÓB KIBEL"], ("b_zrob_kibel", Some 1);
  ["WYWAL KIBEL"], ("b_wywal_kibel", Some 1);
  ["CO W KIBLU"], ("b_co_w_kiblu", Some 1);
  ["CZY TO KIBEL"], ("b_czy_to_kibel", Some 1);
  ["PRZEKOPIUJ KIBEL"], ("b_przekopiuj_kibel", Some 2);
  ["PRZENIEŚ KIBEL"], ("b_przenies_kibel", Some 2);
  ["WYKOP WSZYSTKIE KIBLE"], ("b_wykop_kible", Some 1);
  ["SYSTEM"], ("b_system", Some 1);
  ["OPAKUJ W GAZETĘ"], ("b_opakuj", Some 1);
  ["DAJ MI HAJS"], ("b_daj_hajs", Some 2);
  ["ODDAJ WSZYSTKO"], ("b_oddaj_wszystko", Some 1);
  ["KOMORNICZY WINDYKACJA"], ("b_komornik", Some 2);
  ["ZAPISZ DO BLOKU"], ("b_zapisz_blok", Some 3);
  ["CZYTAJ Z BLOKU"], ("b_czytaj_blok", Some 2);
  ["ROZMIAR BLOKU"], ("b_rozmiar_bloku", Some 1);
  ["ILE KASY LECI"], ("b_ile_kasy", Some 0);
  ["TAG_TRWALE"], ("b_tag_trwale", Some 0);
  ["TAG_POZIOM"], ("b_tag_poziom", Some 0);
  ["TAG_SMIECIOWE"], ("b_tag_smieciowe", Some 0);
  ["PISZ BAJT"], ("b_pisz_bajt", Some 3);
  ["CZYTAJ BAJT"], ("b_czytaj_bajt", Some 2);
  ["KOPIUJ PAMIĘĆ"], ("b_kopiuj_pamiec", Some 3);
  ["WŁĄCZ TELEWIZOR"], ("b_wlacz_tv", Some 2);
  ["WYŁĄCZ TELEWIZOR"], ("b_wylacz_tv", Some 1);
  ["ZMIEŃ KANAŁ"], ("b_zmien_kanal", Some 4);
  ["CO LECI W TELEWIZORZE"], ("b_co_leci", Some 3);
  ["STWÓRZ TABELĘ"], ("b_stworz_tabele", Some 1);
  ["WPISZ DO TABELI"], ("b_wpisz_tabela", Some 3);
  ["SPRAWDŹ W TABELI"], ("b_sprawdz_tabela", Some 2);
  ["OTWORZ"], ("b_otworz", Some 2);
  ["ZAMKNIJ"], ("b_zamknij", Some 1);
  ["CZYTAJ"], ("b_czytaj", None);
  ["PISZ"], ("b_pisz", Some 2);
  ["SKOCZ"], ("b_skocz", None);
  ["POZYCJA"], ("b_pozycja", Some 1);
  ["POLAŁA SIĘ KREW"], ("b_polala_krew", None);
  ["GNIAZDKO_OTWORZ"; "GNIAZDKO OTWORZ"], ("b_gniazdko_otworz", Some 1);
  ["GNIAZDKO_WYSLIJ"; "GNIAZDKO WYSLIJ"], ("b_gniazdko_wyslij", Some 4);
  ["GNIAZDKO_ODBIERZ"; "GNIAZDKO ODBIERZ"], ("b_gniazdko_odbierz", Some 2);
  ["GNIAZDKO_ZAMKNIJ"; "GNIAZDKO ZAMKNIJ"], ("b_gniazdko_zamknij", Some 1);
  (* Grafika X11: prefiks gfx_ - program, który go używa, dostaje kod X11 i -lX11 *)
  ["OKNO_OTWORZ"; "OKNO OTWORZ"], ("gfx_okno_otworz", Some 3);
  ["OKNO_ZAMKNIJ"; "OKNO ZAMKNIJ"], ("gfx_okno_zamknij", Some 0);
  ["PALETA_USTAW"; "PALETA USTAW"], ("gfx_paleta_ustaw", Some 1);
  ["PIKSEL_MALUJ"; "PIKSEL MALUJ"], ("gfx_piksel_maluj", Some 3);
  ["EKRAN_ODŚWIEŹ"; "EKRAN_ODŚWIEŻ"; "EKRAN ODŚWIEŹ"; "EKRAN ODŚWIEŻ"; "EKRAN_ODSWIEZ"; "EKRAN ODSWIEZ"], ("gfx_ekran_odswiez", Some 0);
  ["EKRAN_CZYŚĆ"; "EKRAN CZYŚĆ"; "EKRAN_CZYSĆ"; "EKRAN CZYSĆ"; "EKRAN_CZYSC"; "EKRAN CZYSC"], ("gfx_ekran_czysc", Some 1);
  ["BUFOR_RAMKI_POBIERZ"; "BUFOR RAMKI POBIERZ"], ("gfx_bufor_pobierz", Some 2);
  ["ZDARZENIE_CZEKAJ"; "ZDARZENIE CZEKAJ"], ("gfx_zdarzenie", Some 0);
  ["TRZEBA SPAĆ"], ("b_trzeba_spac", Some 1);
  ["JEST TRZECIA W NOCY"], ("b_jest_trzecia", Some 0);
  ["PIERWIASTEK ZE SKRZYNKI"], ("b_pierwiastek", Some 1);
  ["SINUS ZE SKRZYNKI"], ("b_sinus", Some 1);
  ["COSINUS ZE SKRZYNKI"], ("b_cosinus", Some 1);
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
  classes: (string, class_decl) Hashtbl.t;
  records: (string, (string * expr) list) Hashtbl.t;  (* struktury i unie: pola do zainicjowania *)
  mutable members: string list;               (* Pola i metody obiektu w kompilowanej metodzie *)
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

(* W metodzie: pole/metoda obiektu, jeśli nie przesłania go zmienna lokalna *)
let is_member ctx name = List.mem name ctx.members && not (List.mem name ctx.locals)

(* Zmienna lokalna i pole obiektu przesłaniają funkcję; funkcja wygrywa z globalną o tej samej nazwie *)
let is_function_name ctx name =
  Hashtbl.mem ctx.funcs name && not (List.mem name ctx.locals) && not (is_member ctx name)

let is_type_name ctx name = Hashtbl.mem ctx.classes name || Hashtbl.mem ctx.records name

let class_c cls = mangle "nc_" cls                       (* konstruktor obiektu klasy / struktury / unii *)
let method_c cls m = mangle "m_" (cls ^ "__" ^ m)
let method_wrap_c cls m = mangle "wm_" (cls ^ "__" ^ m)


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
  | Identifier name when is_member ctx name -> Printf.sprintf "field_get(self, %s)" (c_string_literal name)
  | Identifier name | Reference (Identifier name) when is_function_name ctx name ->
      function_value ctx name
  | Identifier name ->
      if is_var ctx name then var_c name
      else if is_type_name ctx name then unsupported "nazwa klasy/struktury jako wartość"
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
      Printf.sprintf "index_get(%s, %s)" (compile_expr ctx arr) (compile_expr ctx idx)
  | FunctionCall (name, args) -> compile_call ctx name args
  | Parenthesized e -> Printf.sprintf "(%s)" (compile_expr ctx e)
  (* Argumenty konstruktora interpreter ignoruje (nawet ich nie liczy) - tu też *)
  | NewObject (cls, _) ->
      if not (Hashtbl.mem ctx.classes cls) then error (Printf.sprintf "Nieznana klasa: %s" cls);
      class_c cls ^ "()"
  | NewStruct name | NewUnion name ->
      if not (Hashtbl.mem ctx.records name) then error (Printf.sprintf "Nieznany typ: %s" name);
      class_c name ^ "()"
  | Reference e -> Printf.sprintf "make_pointer(%s)" (compile_expr ctx e)
  | AddressOf name -> Printf.sprintf "make_pointer(%s)" (compile_expr ctx (Identifier name))
  | Dereference e -> Printf.sprintf "deref(%s)" (compile_expr ctx e)
  | PointerArithmetic (e1, op, e2) ->
      Printf.sprintf "pointer_step(%s, %s, %s)" (compile_expr ctx e1) (compile_expr ctx e2)
        (if op = Minus then "-1" else "1")
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
  | None, _ when List.mem name ctx.locals || (Hashtbl.mem ctx.globals name && not (is_member ctx name)
                                               && not (Hashtbl.mem ctx.funcs name)) ->
      (* Wywołanie funkcji trzymanej w zmiennej - sprawdzenie typu i arności w runtime *)
      Printf.sprintf "call_value(%s, %s, %d, %s)" (var_c name) (c_string_literal name)
        (List.length args) (argv_c c_args)
  | None, _ when is_member ctx name ->
      (* Metoda (albo pole z funkcją) bieżącego obiektu *)
      Printf.sprintf "call_value(field_get(self, %s), %s, %d, %s)" (c_string_literal name)
        (c_string_literal name) (List.length args) (argv_c c_args)
  | None, _ ->
      error (Printf.sprintf "Nieznana funkcja: %s (albo wbudowana, której kompilator nie zna)" name)

(* Przypisanie: zmienna lokalna/globalna albo - w metodzie - pole obiektu *)
let assign ctx name value =
  if is_member ctx name then Printf.sprintf "field_set(self, %s, %s);" (c_string_literal name) value
  else Printf.sprintf "%s = %s;" (var_c name) value

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
  | VarDecl (name, e) | Assign (name, e) -> ind ^ assign ctx name (compile_expr ctx e)
  | ArrayDecl (name, []) ->
      Printf.sprintf "%s%s = make_array(NULL, 0);" ind (var_c name)
  | ArrayDecl (name, exprs) ->
      Printf.sprintf "%s%s = make_array((FerdekValue[]){%s}, %d);" ind (var_c name)
        (String.concat ", " (List.map (compile_expr ctx) exprs)) (List.length exprs)
  | Print e -> Printf.sprintf "%sprint_value(%s);" ind (compile_expr ctx e)
  | PrintInline e -> Printf.sprintf "%sprint_inline(%s);" ind (compile_expr ctx e)
  | Read name -> ind ^ assign ctx name "read_value()"
  | ArrayAssign (ArrayAccess (arr, idx), value) ->
      Printf.sprintf "%sindex_set(%s, %s, %s);" ind
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
      if is_member ctx var then unsupported "pole obiektu jako licznik pętli";
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
  | FunctionCallWithAssign (var, func, args) -> ind ^ assign ctx var (compile_call ctx func args)
  | Return e ->
      if not ctx.in_function then ind ^ "ferdek_die(\"I JA INFORMUJĘ ŻE WYCHODZĘ poza funkcją\");" else
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
       | [] ->   (* jak w interpreterze: błąd wykonania, nie wyskok z funkcji *)
           Printf.sprintf "%sferdek_die(\"%s poza pętlą\");" ind
             (if stmt = Break then "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ" else "AKUKARACZA")
       | h :: _ when h <> "" -> Printf.sprintf "%sferdek_handler = %s; %s" ind h kw
       | _ -> ind ^ kw)

(* ============ FUNCTIONS ============ *)

let all_params (f : function_decl) = f.params @ (if f.is_variadic then ["varargs"] else [])

let fun_proto (f : function_decl) =
  let params = List.map (fun p -> "FerdekValue " ^ var_c p) (all_params f) in
  Printf.sprintf "FerdekValue %s(%s)" (fun_c f.name)
    (if params = [] then "void" else String.concat ", " params)

(* Ciało funkcji albo metody. members <> [] = metoda: nazwy pól i metod obiektu (self) *)
let compile_body ctx ~proto ~members (f : function_decl) =
  let decl, assigned = block_names ([], []) f.body in
  (* Funkcja: przypisanie do istniejącej globalnej zmienia globalną (set_var w interpreterze).
     Metoda: przypisanie do czegoś, co nie jest polem, tworzy lokalną - set_var sprawdza
     tylko obiekt (jeden poziom wyżej), do globalnych nie sięga. *)
  let assigned_locals =
    if members <> [] then List.filter (fun n -> not (List.mem n members)) assigned
    else List.filter (fun n -> not (Hashtbl.mem ctx.globals n)) assigned in
  let locals = dedup (decl @ assigned_locals)
               |> List.filter (fun n -> not (List.mem n (all_params f))) in
  ctx.locals <- all_params f @ locals;
  ctx.members <- members;
  ctx.in_function <- true;
  (* setjmp: lokalne zmieniane w try muszą być volatile, inaczej po longjmp mają śmieci.
     ponytail: parametry nie są volatile - przypisanie do parametru w try i odczyt w catch to UB *)
  let qual = if has_try f.body then "volatile " else "" in
  let decls = "    Handler* entry_handler = ferdek_handler;"
    :: "    const char* entry_file = ferdek_file; int entry_line = ferdek_line;"
    :: List.map (fun n -> Printf.sprintf "    %sFerdekValue %s = make_null();" qual (var_c n)) locals in
  let body = List.map (compile_stmt ctx 1) f.body in
  ctx.locals <- [];
  ctx.members <- [];
  ctx.in_function <- false;
  String.concat "\n" ([Printf.sprintf "%s {" proto] @ decls @ body
                      @ ["    ferdek_handler = entry_handler;"; "    FERDEK_AT(entry_file, entry_line);";
                         "    return make_null();"; "}"])


let compile_function ctx (f : function_decl) = compile_body ctx ~proto:(fun_proto f) ~members:[] f

(* Metoda: jak funkcja, z obiektem (self) jako pierwszym parametrem *)
let method_proto cls (m : function_decl) =
  let params = List.map (fun p -> "FerdekValue " ^ var_c p) (all_params m) in
  Printf.sprintf "FerdekValue %s(%s)" (method_c cls m.name) (String.concat ", " ("FerdekMap* self" :: params))

(* Pola i metody widoczne w metodach klasy: własne i bezpośredniego rodzica (tylko tyle kopiuje interpreter) *)
let class_members ctx (c : class_decl) =
  let own (c : class_decl) = List.map fst c.fields @ List.map (fun (m : function_decl) -> m.name) c.methods in
  own c @ (match c.parent_class with
           | Some p when Hashtbl.mem ctx.classes p -> own (Hashtbl.find ctx.classes p)
           | _ -> [])

let compile_method ctx (c : class_decl) (m : function_decl) =
  compile_body ctx ~proto:(method_proto c.name m) ~members:(class_members ctx c) m

(* Wrapper (self, argc, argv) dla funkcji i metod jako wartości; arność sprawdza call_value *)
let wrap_args (f : function_decl) =
  let n = List.length f.params in
  List.init n (Printf.sprintf "argv[%d]")
  @ (if f.is_variadic then [Printf.sprintf "make_array(argv + %d, argc - %d)" n n] else [])

let wrap_proto (f : function_decl) =
  Printf.sprintf "static FerdekValue %s(void* self, int argc, FerdekValue* argv)" (wrap_c f.name)

let compile_wrapper (f : function_decl) =
  String.concat "\n" [wrap_proto f ^ " {";
                      Printf.sprintf "    return %s(%s);" (fun_c f.name) (String.concat ", " (wrap_args f)); "}"]

let method_wrap_proto cls (m : function_decl) =
  Printf.sprintf "static FerdekValue %s(void* self, int argc, FerdekValue* argv)" (method_wrap_c cls m.name)

let compile_method_wrapper cls (m : function_decl) =
  String.concat "\n" [method_wrap_proto cls m ^ " {";
                      Printf.sprintf "    return %s(%s);" (method_c cls m.name)
                        (String.concat ", " ("(FerdekMap*)self" :: wrap_args m)); "}"]

(* Konstruktor obiektu - kolejność jak eval_new_object: pola i metody rodzica, potem własne *)
let constructor_proto name = Printf.sprintf "static FerdekValue %s(void)" (class_c name)

let compile_class_constructor ctx (c : class_decl) =
  let field (cls_fields : (string * expr) list) =
    List.map (fun (n, e) -> Printf.sprintf "    map_put(obj, %s, %s);" (c_string_literal n) (compile_expr ctx e)) cls_fields in
  let meths cls (ms : function_decl list) = List.map (fun (m : function_decl) ->
    Printf.sprintf "    map_put(obj, %s, make_method(%s, %s, %d, %s, obj));" (c_string_literal m.name)
      (method_wrap_c cls m.name) (c_string_literal m.name) (List.length m.params)
      (if m.is_variadic then "true" else "false")) ms in
  let parent = match c.parent_class with
    | None -> []
    | Some p ->
        (match Hashtbl.find_opt ctx.classes p with
         | Some pc -> field pc.fields @ meths pc.name pc.methods
         | None -> error (Printf.sprintf "Nieznana klasa bazowa: %s" p)) in
  String.concat "\n" ([constructor_proto c.name ^ " {";
                       "    FerdekValue o = make_object();";
                       "    FerdekMap* obj = o.value.map_val;"]
                      @ parent @ field c.fields @ meths c.name c.methods @ ["    return o;"; "}"])

let compile_record_constructor ctx name fields =
  String.concat "\n" ([constructor_proto name ^ " {";
                       "    FerdekValue o = make_object();";
                       "    FerdekMap* obj = o.value.map_val;"]
                      @ List.map (fun (n, e) -> Printf.sprintf "    map_put(obj, %s, %s);" (c_string_literal n) (compile_expr ctx e)) fields
                      @ ["    return o;"; "}"])

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
  | ClassDecl _ | StructDecl _ | UnionDecl _ -> ""  (* konstruktory generuje compile_program *)

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
    TYPE_FLOAT,
    TYPE_OBJECT,     /* obiekt klasy / struktury / unii: pola w FerdekMap */
    TYPE_POINTER,
    TYPE_FILE
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
        /* self: obiekt, z którym związana jest metoda (NULL dla zwykłej funkcji) */
        struct { FerdekValue (*call)(void*, int, FerdekValue*); const char* name; int arity; bool variadic; void* self; } fn_val;
        FerdekValue* ptr_val;     /* wskaźnik: kopia wartości na stercie, jak ref w interpreterze */
        struct { FILE* f; bool input; } file_val;
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
        case TYPE_OBJECT: return strdup("<object>");
        case TYPE_FILE: return strdup("<file handle>");
        case TYPE_POINTER: {
            StrBuf b = {0};
            char* inner = to_str(*v.value.ptr_val);
            buf_add(&b, "<pointer to ");
            buf_add(&b, inner);
            buf_add(&b, ">");
            free(inner);
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

/* Trójwartościowe porównanie - jak compare_values w interpreterze */
static int compare3(FerdekValue a, FerdekValue b, bool equality) {
    if (a.type == TYPE_STRING && b.type == TYPE_STRING) {
        int c = strcmp(a.value.string_val, b.value.string_val);
        return (c > 0) - (c < 0);
    }
    if (is_numeric(a) && is_numeric(b) && ANY_FLOAT(a, b)) {
        double x = to_float(a), y = to_float(b);
        return (x > y) - (x < y);
    }
    if (is_numeric(a) && is_numeric(b)) {
        long long x = to_int(a), y = to_int(b);
        return (x > y) - (x < y);
    }
    if (equality) return 1;
    ferdek_die("Nie można porównać tekstu z liczbą");
    return 0;
}

static FerdekValue compare_op(FerdekValue a, FerdekValue b, int op) {
    int c = compare3(a, b, op == CMP_EQ || op == CMP_NE);
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

static FerdekValue make_method(FerdekValue (*call)(void*, int, FerdekValue*), const char* name, int arity, bool variadic, void* self) {
    FerdekValue v;
    v.type = TYPE_FUNCTION;
    v.value.fn_val.call = call;
    v.value.fn_val.name = name;
    v.value.fn_val.arity = arity;
    v.value.fn_val.variadic = variadic;
    v.value.fn_val.self = self;
    return v;
}

static FerdekValue make_function(FerdekValue (*call)(void*, int, FerdekValue*), const char* name, int arity, bool variadic) {
    return make_method(call, name, arity, variadic, NULL);
}

/* name = nazwa użyta w wywołaniu (jak w komunikatach interpretera) */
static FerdekValue call_value(FerdekValue f, const char* name, int argc, FerdekValue* argv) {
    if (f.type != TYPE_FUNCTION) ferdek_die("%s to nie funkcja", name);
    if (f.value.fn_val.variadic && argc < f.value.fn_val.arity)
        ferdek_die("Funkcja %s oczekuje co najmniej %d %s, podano %d", name, f.value.fn_val.arity, ARGUMENTOW(f.value.fn_val.arity), argc);
    if (!f.value.fn_val.variadic && argc != f.value.fn_val.arity)
        ferdek_die("Funkcja %s oczekuje %d %s, podano %d", name, f.value.fn_val.arity, ARGUMENTOW(f.value.fn_val.arity), argc);
    return f.value.fn_val.call(f.value.fn_val.self, argc, argv);
}

/* ---- Obiekty (pola w FerdekMap) i wskaźniki ---- */

static void map_put(FerdekMap* m, const char* key, FerdekValue v) {
    int i = map_find(m, key);
    if (i >= 0) { m->vals[i] = v; return; }
    if (m->len == m->cap) {
        m->cap = m->cap ? m->cap * 2 : 8;
        m->keys = realloc(m->keys, sizeof(char*) * m->cap);
        m->vals = realloc(m->vals, sizeof(FerdekValue) * m->cap);
    }
    m->keys[m->len] = strdup(key);
    m->vals[m->len++] = v;
}

static FerdekValue make_object(void) {
    FerdekValue v;
    v.type = TYPE_OBJECT;
    v.value.map_val = calloc(1, sizeof(FerdekMap));
    return v;
}

/* Pole obiektu w metodzie (nazwa znana z deklaracji klasy) */
static FerdekValue field_get(FerdekMap* self, const char* name) {
    int i = map_find(self, name);
    if (i < 0) ferdek_die("Nieznana zmienna: %s", name);
    return self->vals[i];
}

static void field_set(FerdekMap* self, const char* name, FerdekValue v) { map_put(self, name, v); }

/* Klucz pola: tekst albo liczba (obj["x"], obj[1]) */
static char* field_key(FerdekValue key) {
    char num[32];
    if (key.type == TYPE_STRING) return key.value.string_val;
    if (key.type == TYPE_INT) { snprintf(num, sizeof num, "%lld", key.value.int_val); return strdup(num); }
    ferdek_die("Nazwa pola obiektu musi być tekstem, a jest: %s", to_str(key));
    return NULL;
}

/* t[i] i obj["pole"] - jak ArrayAccess w interpreterze */
static FerdekValue index_get(FerdekValue c, FerdekValue key) {
    if (c.type == TYPE_ARRAY) {
        long long i = to_int(key);
        if (i < 0 || i >= c.value.array_val->length) ferdek_die("Indeks tablicy poza zakresem");
        return c.value.array_val->data[i];
    }
    if (c.type == TYPE_OBJECT) {
        char* k = field_key(key);
        int i = map_find(c.value.map_val, k);
        if (i < 0) ferdek_die("Obiekt nie ma pola: %s", k);
        return c.value.map_val->vals[i];
    }
    ferdek_die("To nie jest tablica ani obiekt");
    return make_null();
}

/* t[i] = v i obj["pole"] = v - jak ArrayAssign w interpreterze (indeks tablicy tylko DŁUGI) */
static void index_set(FerdekValue c, FerdekValue key, FerdekValue v) {
    if (c.type == TYPE_ARRAY && key.type == TYPE_INT) {
        long long i = key.value.int_val;
        if (i < 0 || i >= c.value.array_val->length) ferdek_die("Indeks poza zakresem: %lld", i);
        c.value.array_val->data[i] = v;
    } else if (c.type == TYPE_OBJECT && (key.type == TYPE_STRING || key.type == TYPE_INT)) {
        map_put(c.value.map_val, field_key(key), v);
    } else if (key.type == TYPE_INT) {
        ferdek_die("To nie jest tablica ani obiekt");
    } else {
        ferdek_die("Indeks tablicy musi być liczbą całkowitą");
    }
}

static FerdekValue make_pointer(FerdekValue target) {
    FerdekValue v;
    v.type = TYPE_POINTER;
    v.value.ptr_val = malloc(sizeof(FerdekValue));
    *v.value.ptr_val = target;
    return v;
}

static FerdekValue deref(FerdekValue p) {
    if (p.type != TYPE_POINTER) ferdek_die("CO TAM JEST: to nie jest wskaźnik");
    return *p.value.ptr_val;
}

/* KROK DALEJ / WSTECZ - jak w interpreterze: wskaźnik się nie przesuwa, liczby się dodają */
static FerdekValue pointer_step(FerdekValue a, FerdekValue b, int dir) {
    if (a.type == TYPE_POINTER && b.type == TYPE_INT) return a;
    if (a.type == TYPE_INT && b.type == TYPE_INT) return make_int(a.value.int_val + dir * b.value.int_val);
    ferdek_die("Nieprawidłowe działanie na wskaźniku");
    return make_null();
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

/* Znaki UTF-8 jak utf8_chars w interpreterze: długość znaku z bajtu wiodącego */
static int utf8_char_len(const char* s) {
    unsigned char c = (unsigned char)s[0];
    int len = c < 0x80 ? 1 : (c & 0xE0) == 0xC0 ? 2 : (c & 0xF0) == 0xE0 ? 3 : (c & 0xF8) == 0xF0 ? 4 : 1;
    for (int k = 1; k < len; k++) if (!s[k]) return 1;   /* ucięty znak: bajt po bajcie */
    return len;
}

/* Liczba znaków; offsets (jeśli podane) dostaje bajtowy początek każdego znaku + koniec */
static long long utf8_index(const char* s, long long** offsets) {
    long long n = 0, cap = 16;
    long long* off = offsets ? malloc(sizeof(long long) * cap) : NULL;
    const char* p = s;
    while (*p) {
        if (off) { if (n + 1 >= cap) { cap *= 2; off = realloc(off, sizeof(long long) * cap); } off[n] = p - s; }
        p += utf8_char_len(p);
        n++;
    }
    if (off) { off[n] = p - s; *offsets = off; }
    return n;
}

static FerdekValue b_kanapa_rozciagnij(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    long long target = to_int(argv[1]);
    long long chars = utf8_index(s, NULL);
    if (chars >= target) return own_string(s);
    size_t len = strlen(s);
    s = realloc(s, len + (target - chars) + 1);
    memset(s + len, ' ', target - chars);
    s[len + (target - chars)] = '\0';
    return own_string(s);
}

static FerdekValue b_kanapa_potnij(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    long long* off;
    long long len = utf8_index(s, &off), start = to_int(argv[1]), end = to_int(argv[2]);
    if (start < 0 || start >= len) ferdek_die("POTNIJ KANAPĘ: początek poza zakresem");
    if (end < start || end > len) ferdek_die("POTNIJ KANAPĘ: koniec poza zakresem");
    s[off[end]] = '\0';
    return make_string(s + off[start]);
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
    FerdekValue n = make_int(utf8_index(s, NULL));
    free(s);
    return n;
}

static FerdekValue b_kanapa_znak(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    long long i = to_int(argv[1]);
    long long* off;
    long long n = utf8_index(s, &off);
    if (i < 0 || i >= n) ferdek_die("ZNAK Z KANAPY: indeks poza zakresem");
    s[off[i + 1]] = '\0';
    return make_string(s + off[i]);
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

/* Funkcja przekazana builtinowi - jak function_arg w interpreterze */
static FerdekValue function_arg(const char* builtin, FerdekValue f) {
    if (f.type != TYPE_FUNCTION) ferdek_die("%s: drugi argument musi być funkcją", builtin);
    return f;
}

static FerdekValue sort_fn;   /* komparator użytkownika albo TYPE_NULL = domyślne porównanie */

static int sort_cmp(FerdekValue x, FerdekValue y) {
    if (sort_fn.type == TYPE_NULL) return compare3(x, y, false);
    FerdekValue args[2] = { x, y };
    double r = to_float(call_value(sort_fn, sort_fn.value.fn_val.name, 2, args));
    return (r > 0) - (r < 0);
}

/* Stabilny merge sort - jak List.stable_sort, więc remisy zostają w tej samej kolejności */
static void merge_sort(FerdekValue* a, FerdekValue* tmp, int n) {
    if (n < 2) return;
    int m = n / 2;
    merge_sort(a, tmp, m);
    merge_sort(a + m, tmp, n - m);
    int i = 0, j = m, k = 0;
    while (i < m && j < n) tmp[k++] = sort_cmp(a[j], a[i]) < 0 ? a[j++] : a[i++];
    while (i < m) tmp[k++] = a[i++];
    while (j < n) tmp[k++] = a[j++];
    memcpy(a, tmp, sizeof(FerdekValue) * n);
}

static FerdekValue b_wersalka_posklada(int argc, FerdekValue* argv) {
    if (argc != 1 && argc != 2) ferdek_die("POSKŁADAJ WERSALKĘ oczekuje 1 albo 2 argumentów");
    FerdekArray* arr = list_arg(argv[0], "POSKŁADAJ WERSALKĘ: pierwszy argument musi być tablicą");
    sort_fn = argc == 2 ? function_arg("POSKŁADAJ WERSALKĘ", argv[1]) : make_null();
    FerdekValue out = make_array(arr->data, arr->length);
    FerdekValue* tmp = malloc(sizeof(FerdekValue) * (arr->length > 0 ? arr->length : 1));
    merge_sort(out.value.array_val->data, tmp, arr->length);
    free(tmp);
    return out;
}

static FerdekValue b_wersalka_odwroc(int argc, FerdekValue* argv) {
    FerdekArray* arr = list_arg(argv[0], "ODWRÓĆ WERSALKĘ: argument musi być tablicą");
    FerdekValue out = make_array(arr->data, arr->length);
    for (int i = 0; i < arr->length; i++) out.value.array_val->data[i] = arr->data[arr->length - 1 - i];
    return out;
}

static FerdekValue b_wersalka_przerabiaj(int argc, FerdekValue* argv) {
    FerdekArray* arr = list_arg(argv[0], "PRZERABIAJ WERSALKĘ: pierwszy argument musi być tablicą");
    FerdekValue f = function_arg("PRZERABIAJ WERSALKĘ", argv[1]);
    FerdekValue out = make_array(arr->data, arr->length);
    for (int i = 0; i < arr->length; i++)
        out.value.array_val->data[i] = call_value(f, f.value.fn_val.name, 1, &arr->data[i]);
    return out;
}

static FerdekValue b_wersalka_przefiltruj(int argc, FerdekValue* argv) {
    FerdekArray* arr = list_arg(argv[0], "PRZEFILTRUJ WERSALKĘ: pierwszy argument musi być tablicą");
    FerdekValue f = function_arg("PRZEFILTRUJ WERSALKĘ", argv[1]);
    FerdekValue out = make_array(NULL, 0);
    out.value.array_val->data = malloc(sizeof(FerdekValue) * (arr->length > 0 ? arr->length : 1));
    for (int i = 0; i < arr->length; i++)
        if (to_bool(call_value(f, f.value.fn_val.name, 1, &arr->data[i])))
            out.value.array_val->data[out.value.array_val->length++] = arr->data[i];
    return out;
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
        case TYPE_OBJECT: return make_string("OBIEKT");
        case TYPE_POINTER: return make_string("WSKAŹNIK");
        case TYPE_FILE: return make_string("KIBEL");
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

static FerdekValue b_pierwiastek(int argc, FerdekValue* argv) {
    double x = to_float(argv[0]);
    if (x < 0.0) ferdek_die("PIERWIASTEK ZE SKRZYNKI: pierwiastek z liczby ujemnej");
    return make_float(sqrt(x));
}
static FerdekValue b_sinus(int argc, FerdekValue* argv) { return make_float(sin(to_float(argv[0]))); }
static FerdekValue b_cosinus(int argc, FerdekValue* argv) { return make_float(cos(to_float(argv[0]))); }

/* Czas - jak w interpreterze */
static struct timespec program_start;

static double ms_since_start(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (now.tv_sec - program_start.tv_sec) * 1000.0 + (now.tv_nsec - program_start.tv_nsec) / 1e6;
}

static FerdekValue b_trzeba_spac(int argc, FerdekValue* argv) {
    double ms = to_float(argv[0]);
    if (ms < 0.0) ferdek_die("TRZEBA SPAĆ: czas nie może być ujemny");
    fflush(stdout);
    struct timespec t = { (time_t)(ms / 1000.0), (long)(fmod(ms, 1000.0) * 1e6) };
    nanosleep(&t, NULL);
    return make_null();
}

static FerdekValue b_jest_trzecia(int argc, FerdekValue* argv) { return make_int((long long)ms_since_start()); }

/* ---- KIBEL: pliki i katalogi (komunikaty jak Sys_error w interpreterze: "ścieżka: strerror") ---- */

static FerdekValue make_file(FILE* f, bool input) {
    FerdekValue v;
    v.type = TYPE_FILE;
    v.value.file_val.f = f;
    v.value.file_val.input = input;
    return v;
}

static FerdekValue b_otworz_kibel(int argc, FerdekValue* argv) {
    char* path = to_str(argv[0]);
    FILE* f = fopen(path, "r");
    if (!f) ferdek_die("OTWÓRZ KIBEL: %s: %s", path, strerror(errno));
    return make_file(f, true);
}

static FerdekValue b_otworz_kibel_zapis(int argc, FerdekValue* argv) {
    char* path = to_str(argv[0]);
    FILE* f = fopen(path, "w");
    if (!f) ferdek_die("OTWÓRZ_KIBEL_DO_ZAPISU: %s: %s", path, strerror(errno));
    return make_file(f, false);
}

static FerdekValue b_zamknij_kibel(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_FILE) ferdek_die("ZAMKNIJ_KIBEL: argument musi być uchwytem pliku");
    fclose(argv[0].value.file_val.f);
    return make_null();
}

static FerdekValue b_spusc_wode(int argc, FerdekValue* argv) {
    char* data = to_str(argv[1]);
    if (argv[0].type != TYPE_FILE) ferdek_die("SPUŚĆ_WODĘ: pierwszy argument musi być uchwytem pliku");
    if (argv[0].value.file_val.input) ferdek_die("SPUŚĆ_WODĘ: nie można pisać do pliku otwartego do odczytu");
    fputs(data, argv[0].value.file_val.f);
    fflush(argv[0].value.file_val.f);
    return make_null();
}

/* Wszystkie linie pliku (bez końców linii), jak input_line */
static FerdekValue b_wypompuj(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_FILE) ferdek_die("WYPOMPUJ: argument musi być uchwytem pliku");
    if (!argv[0].value.file_val.input) ferdek_die("WYPOMPUJ: nie można czytać z pliku otwartego do zapisu");
    FerdekValue out = make_array(NULL, 0);
    FerdekArray* arr = out.value.array_val;
    char* line = NULL;
    size_t cap = 0;
    ssize_t n;
    while ((n = getline(&line, &cap, argv[0].value.file_val.f)) != -1) {
        if (n > 0 && line[n - 1] == '\n') line[n - 1] = '\0';
        arr->data = realloc(arr->data, sizeof(FerdekValue) * (arr->length + 1));
        arr->data[arr->length++] = make_string(line);
    }
    free(line);
    return out;
}

static FerdekValue b_czy_kibel_zajety(int argc, FerdekValue* argv) {
    struct stat st;
    return make_bool(stat(to_str(argv[0]), &st) == 0);
}

static FerdekValue b_zrob_kibel(int argc, FerdekValue* argv) { return make_bool(mkdir(to_str(argv[0]), 0755) == 0); }
static FerdekValue b_wywal_kibel(int argc, FerdekValue* argv) { return make_bool(rmdir(to_str(argv[0])) == 0); }

static bool is_dir(const char* path) {
    struct stat st;
    return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

static FerdekValue b_czy_to_kibel(int argc, FerdekValue* argv) { return make_bool(is_dir(to_str(argv[0]))); }

/* Wpisy katalogu w kolejności readdir (jak w interpreterze), bez . i .. */
static FerdekValue b_co_w_kiblu(int argc, FerdekValue* argv) {
    FerdekValue out = make_array(NULL, 0);
    FerdekArray* arr = out.value.array_val;
    DIR* d = opendir(to_str(argv[0]));
    if (!d) return out;
    struct dirent* e;
    while ((e = readdir(d)) != NULL) {
        if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
        arr->data = realloc(arr->data, sizeof(FerdekValue) * (arr->length + 1));
        arr->data[arr->length++] = make_string(e->d_name);
    }
    closedir(d);
    return out;
}

static FerdekValue b_przekopiuj_kibel(int argc, FerdekValue* argv) {
    FILE* in = fopen(to_str(argv[0]), "rb");
    if (!in) return make_bool(false);
    FILE* out = fopen(to_str(argv[1]), "wb");
    if (!out) { fclose(in); return make_bool(false); }
    char buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, in)) > 0) fwrite(buf, 1, n, out);
    fclose(in);
    fclose(out);
    return make_bool(true);
}

static FerdekValue b_przenies_kibel(int argc, FerdekValue* argv) {
    return make_bool(rename(to_str(argv[0]), to_str(argv[1])) == 0);
}

static void wykop(const char* path) {
    if (is_dir(path)) {
        DIR* d = opendir(path);
        if (d) {
            struct dirent* e;
            while ((e = readdir(d)) != NULL) {
                if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
                char* full = malloc(strlen(path) + strlen(e->d_name) + 2);
                sprintf(full, "%s/%s", path, e->d_name);
                wykop(full);
                free(full);
            }
            closedir(d);
        }
        rmdir(path);
    } else {
        remove(path);
    }
}

static FerdekValue b_wykop_kible(int argc, FerdekValue* argv) { wykop(to_str(argv[0])); return make_null(); }

static FerdekValue b_system(int argc, FerdekValue* argv) {
    fflush(stdout);
    FILE* p = popen(to_str(argv[0]), "r");
    if (!p) ferdek_die("SYSTEM: błąd: %s", strerror(errno));
    StrBuf b = {0};
    buf_add(&b, "");
    char chunk[4096];
    size_t n;
    while ((n = fread(chunk, 1, sizeof chunk - 1, p)) > 0) { chunk[n] = '\0'; buf_add(&b, chunk); }
    pclose(p);
    return own_string(b.s);
}

/* Jak Filename.quote: '...' z ' zamienionym na '\'' */
static FerdekValue b_opakuj(int argc, FerdekValue* argv) {
    char* s = to_str(argv[0]);
    StrBuf b = {0};
    buf_add(&b, "'");
    for (char* p = s; *p; p++) {
        if (*p == '\'') buf_add(&b, "'\\''");
        else { char c[2] = { *p, '\0' }; buf_add(&b, c); }
    }
    buf_add(&b, "'");
    return own_string(b.s);
}

/* ---- Alokator strefowy (DAJ MI HAJS): bloki wartości, wskaźnik = wskaźnik na numer bloku ---- */

typedef struct { long long size; int tag; FerdekValue* data; bool alive; } ZoneBlock;
static ZoneBlock* zone = NULL;
static long long zone_count = 0, zone_allocated = 0, zone_freed = 0;

static int int_to_tag(long long n) { return n <= 1 ? 1 : (n <= 50 ? 50 : 100); }

/* Blok spod wskaźnika; komunikaty zależą od funkcji, jak w interpreterze */
static ZoneBlock* block_arg(FerdekValue p, const char* not_ptr, const char* bad_ptr, const char* no_block) {
    if (p.type != TYPE_POINTER) ferdek_die("%s", not_ptr);
    if (p.value.ptr_val->type != TYPE_INT) ferdek_die("%s", bad_ptr);
    long long id = p.value.ptr_val->value.int_val;
    if (id < 0 || id >= zone_count || !zone[id].alive) ferdek_die("%s", no_block);
    return &zone[id];
}

static FerdekValue b_daj_hajs(int argc, FerdekValue* argv) {
    long long size = to_int(argv[0]), tag = to_int(argv[1]);
    if (size <= 0) ferdek_die("DAJ MI HAJS: rozmiar musi być dodatni");
    zone = realloc(zone, sizeof(ZoneBlock) * (zone_count + 1));
    ZoneBlock* b = &zone[zone_count];
    b->size = size;
    b->tag = int_to_tag(tag);
    b->data = malloc(sizeof(FerdekValue) * size);
    for (long long i = 0; i < size; i++) b->data[i] = make_null();
    b->alive = true;
    zone_allocated += size;
    return make_pointer(make_int(zone_count++));
}

static FerdekValue b_oddaj_wszystko(int argc, FerdekValue* argv) {
    ZoneBlock* b = block_arg(argv[0], "ODDAJ WSZYSTKO: argument musi być wskaźnikiem",
                             "ODDAJ WSZYSTKO: nieprawidłowy wskaźnik", "ODDAJ WSZYSTKO: blok nie istnieje");
    zone_freed += b->size;
    b->alive = false;
    return make_null();
}

static FerdekValue b_komornik(int argc, FerdekValue* argv) {
    long long lo = to_int(argv[0]), hi = to_int(argv[1]), freed = 0;
    for (long long i = 0; i < zone_count; i++)
        if (zone[i].alive && zone[i].tag >= lo && zone[i].tag <= hi) {
            zone_freed += zone[i].size;
            zone[i].alive = false;
            freed++;
        }
    return make_int(freed);
}

static FerdekValue b_zapisz_blok(int argc, FerdekValue* argv) {
    long long i = to_int(argv[1]);
    ZoneBlock* b = block_arg(argv[0], "ZAPISZ DO BLOKU: pierwszy argument musi być wskaźnikiem",
                             "ZAPISZ DO BLOKU: nieprawidłowy wskaźnik", "ZAPISZ DO BLOKU: blok nie istnieje");
    if (i < 0 || i >= b->size) ferdek_die("ZAPISZ DO BLOKU: indeks %lld poza zakresem (rozmiar: %lld)", i, b->size);
    b->data[i] = argv[2];
    return make_null();
}

static FerdekValue b_czytaj_blok(int argc, FerdekValue* argv) {
    long long i = to_int(argv[1]);
    ZoneBlock* b = block_arg(argv[0], "CZYTAJ Z BLOKU: pierwszy argument musi być wskaźnikiem",
                             "CZYTAJ Z BLOKU: nieprawidłowy wskaźnik", "CZYTAJ Z BLOKU: blok nie istnieje");
    if (i < 0 || i >= b->size) ferdek_die("CZYTAJ Z BLOKU: indeks %lld poza zakresem (rozmiar: %lld)", i, b->size);
    return b->data[i];
}

static FerdekValue b_rozmiar_bloku(int argc, FerdekValue* argv) {
    return make_int(block_arg(argv[0], "ROZMIAR BLOKU: argument musi być wskaźnikiem",
                              "ROZMIAR BLOKU: nieprawidłowy wskaźnik", "ROZMIAR BLOKU: blok nie istnieje")->size);
}

static FerdekValue b_ile_kasy(int argc, FerdekValue* argv) {
    long long blocks = 0;
    for (long long i = 0; i < zone_count; i++) blocks += zone[i].alive;
    FerdekValue m = b_szafka_otworz(0, NULL);
    map_put(m.value.map_val, "allocated", make_int(zone_allocated));
    map_put(m.value.map_val, "freed", make_int(zone_freed));
    map_put(m.value.map_val, "current", make_int(zone_allocated - zone_freed));
    map_put(m.value.map_val, "blocks", make_int(blocks));
    return m;
}

static FerdekValue b_tag_trwale(int argc, FerdekValue* argv) { return make_int(1); }
static FerdekValue b_tag_poziom(int argc, FerdekValue* argv) { return make_int(50); }
static FerdekValue b_tag_smieciowe(int argc, FerdekValue* argv) { return make_int(100); }

static FerdekValue b_pisz_bajt(int argc, FerdekValue* argv) {
    long long off = to_int(argv[1]), val = to_int(argv[2]);
    ZoneBlock* b = block_arg(argv[0], "PISZ BAJT: pierwszy argument musi być wskaźnikiem",
                             "PISZ BAJT: pierwszy argument musi być wskaźnikiem", "PISZ BAJT: nieprawidłowy blok pamięci");
    if (off < 0 || off >= b->size) ferdek_die("PISZ BAJT: przesunięcie poza zakresem");
    b->data[off] = make_int(val);
    return make_null();
}

static FerdekValue b_czytaj_bajt(int argc, FerdekValue* argv) {
    long long off = to_int(argv[1]);
    ZoneBlock* b = block_arg(argv[0], "CZYTAJ BAJT: pierwszy argument musi być wskaźnikiem",
                             "CZYTAJ BAJT: pierwszy argument musi być wskaźnikiem", "CZYTAJ BAJT: nieprawidłowy blok pamięci");
    if (off < 0 || off >= b->size) ferdek_die("CZYTAJ BAJT: przesunięcie poza zakresem");
    return b->data[off];
}

static FerdekValue b_kopiuj_pamiec(int argc, FerdekValue* argv) {
    long long size = to_int(argv[2]);
    if (argv[0].type != TYPE_POINTER || argv[1].type != TYPE_POINTER ||
        argv[0].value.ptr_val->type != TYPE_INT || argv[1].value.ptr_val->type != TYPE_INT)
        ferdek_die("KOPIUJ PAMIĘĆ: argumenty muszą być wskaźnikami");
    long long s = argv[0].value.ptr_val->value.int_val, d = argv[1].value.ptr_val->value.int_val;
    if (s < 0 || s >= zone_count || !zone[s].alive || d < 0 || d >= zone_count || !zone[d].alive)
        ferdek_die("KOPIUJ PAMIĘĆ: nieprawidłowe bloki pamięci");
    if (size > zone[s].size || size > zone[d].size) ferdek_die("KOPIUJ PAMIĘĆ: rozmiar większy niż blok");
    memmove(zone[d].data, zone[s].data, sizeof(FerdekValue) * size);
    return make_null();
}

/* ---- TELEWIZOR (framebuffer w pamięci) i tablice wyszukiwania ---- */

typedef struct { long long w, h; long long* px; bool alive; } FerdekScreen;
static FerdekScreen* screens = NULL;
static long long screen_count = 0;

static FerdekScreen* screen_arg(FerdekValue p, const char* not_ptr, const char* bad) {
    if (p.type != TYPE_POINTER || p.value.ptr_val->type != TYPE_INT) ferdek_die("%s", not_ptr);
    long long id = p.value.ptr_val->value.int_val;
    if (id < 0 || id >= screen_count || !screens[id].alive) ferdek_die("%s", bad);
    return &screens[id];
}

static FerdekValue b_wlacz_tv(int argc, FerdekValue* argv) {
    long long w = to_int(argv[0]), h = to_int(argv[1]);
    if (w <= 0 || h <= 0) ferdek_die("WŁĄCZ TELEWIZOR: szerokość i wysokość muszą być dodatnie");
    screens = realloc(screens, sizeof(FerdekScreen) * (screen_count + 1));
    screens[screen_count] = (FerdekScreen){ w, h, calloc(w * h, sizeof(long long)), true };
    return make_pointer(make_int(screen_count++));
}

static FerdekValue b_wylacz_tv(int argc, FerdekValue* argv) {
    screen_arg(argv[0], "WYŁĄCZ TELEWIZOR: argument musi być wskaźnikiem na ekran",
               "WYŁĄCZ TELEWIZOR: nieprawidłowy ekran")->alive = false;
    return make_null();
}

static FerdekValue b_zmien_kanal(int argc, FerdekValue* argv) {
    long long x = to_int(argv[1]), y = to_int(argv[2]), c = to_int(argv[3]);
    FerdekScreen* s = screen_arg(argv[0], "ZMIEŃ KANAŁ: pierwszy argument musi być wskaźnikiem na ekran",
                           "ZMIEŃ KANAŁ: nieprawidłowy ekran");
    if (x < 0 || x >= s->w || y < 0 || y >= s->h) ferdek_die("ZMIEŃ KANAŁ: piksel poza ekranem");
    s->px[y * s->w + x] = c;
    return make_null();
}

static FerdekValue b_co_leci(int argc, FerdekValue* argv) {
    long long x = to_int(argv[1]), y = to_int(argv[2]);
    FerdekScreen* s = screen_arg(argv[0], "CO LECI W TELEWIZORZE: pierwszy argument musi być wskaźnikiem na ekran",
                           "CO LECI W TELEWIZORZE: nieprawidłowy ekran");
    if (x < 0 || x >= s->w || y < 0 || y >= s->h) ferdek_die("CO LECI W TELEWIZORZE: piksel poza ekranem");
    return make_int(s->px[y * s->w + x]);
}

typedef struct { long long size; long long* data; } Lookup;
static Lookup* lookups = NULL;
static long long lookup_count = 0;

static Lookup* lookup_arg(FerdekValue p, const char* not_ptr, const char* bad) {
    if (p.type != TYPE_POINTER || p.value.ptr_val->type != TYPE_INT) ferdek_die("%s", not_ptr);
    long long id = p.value.ptr_val->value.int_val;
    if (id < 0 || id >= lookup_count) ferdek_die("%s", bad);
    return &lookups[id];
}

static FerdekValue b_stworz_tabele(int argc, FerdekValue* argv) {
    long long size = to_int(argv[0]);
    if (size <= 0) ferdek_die("STWÓRZ TABELĘ: rozmiar musi być dodatni");
    lookups = realloc(lookups, sizeof(Lookup) * (lookup_count + 1));
    lookups[lookup_count] = (Lookup){ size, calloc(size, sizeof(long long)) };
    return make_pointer(make_int(lookup_count++));
}

static FerdekValue b_wpisz_tabela(int argc, FerdekValue* argv) {
    long long i = to_int(argv[1]), v = to_int(argv[2]);
    Lookup* t = lookup_arg(argv[0], "WPISZ DO TABELI: pierwszy argument musi być wskaźnikiem na tabelę",
                           "WPISZ DO TABELI: nieprawidłowa tabela");
    if (i < 0 || i >= t->size) ferdek_die("WPISZ DO TABELI: indeks poza zakresem");
    t->data[i] = v;
    return make_null();
}

static FerdekValue b_sprawdz_tabela(int argc, FerdekValue* argv) {
    long long i = to_int(argv[1]);
    Lookup* t = lookup_arg(argv[0], "SPRAWDŹ W TABELI: pierwszy argument musi być wskaźnikiem na tabelę",
                           "SPRAWDŹ W TABELI: nieprawidłowa tabela");
    if (i < 0 || i >= t->size) ferdek_die("SPRAWDŹ W TABELI: indeks poza zakresem");
    return make_int(t->data[i]);
}

/* ---- Niskopoziomowe I/O (OTWORZ / CZYTAJ / PISZ / SKOCZ / POZYCJA / ZAMKNIJ) ---- */

static FerdekValue b_otworz(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_STRING) ferdek_die("OTWORZ: nazwa pliku musi być tekstem");
    if (argv[1].type != TYPE_STRING) ferdek_die("OTWORZ: tryb musi być tekstem");
    const char* name = argv[0].value.string_val;
    const char* mode = argv[1].value.string_val;
    bool input = strcmp(mode, "r") == 0 || strcmp(mode, "rb") == 0;
    const char* cmode = input ? "rb"
        : (strcmp(mode, "w") == 0 || strcmp(mode, "wb") == 0) ? "wb"
        : (strcmp(mode, "a") == 0 || strcmp(mode, "ab") == 0) ? "ab" : NULL;
    if (!cmode) ferdek_die("Nieprawidłowy tryb pliku: %s (dozwolone: 'r', 'w', 'a')", mode);
    FILE* f = fopen(name, cmode);
    if (!f) ferdek_die("Nie można otworzyć pliku '%s': %s: %s", name, name, strerror(errno));
    return make_file(f, input);
}

static FerdekValue b_zamknij(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_FILE) ferdek_die("ZAMKNIJ: argument musi być uchwytem pliku");
    fclose(argv[0].value.file_val.f);
    return make_null();
}

static FerdekValue b_czytaj(int argc, FerdekValue* argv) {
    if (argc == 2) {
        long long size = to_int(argv[1]);
        if (argv[0].type != TYPE_FILE || !argv[0].value.file_val.input)
            ferdek_die("CZYTAJ GAZETĘ: pierwszy argument musi być uchwytem pliku do odczytu");
        unsigned char* buf = malloc(size > 0 ? size : 1);
        size_t n = fread(buf, 1, size, argv[0].value.file_val.f);
        FerdekValue out = make_array(NULL, 0);
        out.value.array_val->data = malloc(sizeof(FerdekValue) * (n > 0 ? n : 1));
        for (size_t i = 0; i < n; i++) out.value.array_val->data[i] = make_typed(TYPE_BYTE, buf[i]);
        out.value.array_val->length = (int)n;
        free(buf);
        return out;
    }
    if (argc == 1) {
        if (argv[0].type != TYPE_FILE || !argv[0].value.file_val.input)
            ferdek_die("CZYTAJ: argument musi być uchwytem pliku do odczytu");
        int c = fgetc(argv[0].value.file_val.f);
        return c == EOF ? make_int(-1) : make_typed(TYPE_BYTE, c);
    }
    ferdek_die("CZYTAJ oczekuje 1 albo 2 argumentów");
    return make_null();
}

static FerdekValue b_pisz(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_FILE || argv[0].value.file_val.input)
        ferdek_die("PISZ: pierwszy argument musi być uchwytem pliku do zapisu");
    FILE* f = argv[0].value.file_val.f;
    FerdekValue d = argv[1];
    if (d.type == TYPE_ARRAY) {
        for (int i = 0; i < d.value.array_val->length; i++) fputc((int)(to_int(d.value.array_val->data[i]) & 0xFF), f);
        return make_int(d.value.array_val->length);
    }
    if (d.type == TYPE_STRING) { fputs(d.value.string_val, f); return make_int((long long)strlen(d.value.string_val)); }
    if (d.type == TYPE_BYTE || d.type == TYPE_INT || d.type == TYPE_SHORT) { fputc((int)(d.value.int_val & 0xFF), f); return make_int(1); }
    ferdek_die("PISZ: dane muszą być tablicą, tekstem albo bajtem");
    return make_null();
}

static FerdekValue b_skocz(int argc, FerdekValue* argv) {
    if (argc != 2 && argc != 3) ferdek_die("SKOCZ oczekuje 2 albo 3 argumentów (file_handle, offset, [mode])");
    long long off = to_int(argv[1]);
    long long mode = argc == 3 ? to_int(argv[2]) : 0;
    if (argv[0].type != TYPE_FILE) ferdek_die("SKOCZ: pierwszy argument musi być uchwytem pliku");
    FILE* f = argv[0].value.file_val.f;
    long long pos;
    if (mode == 0) pos = off;
    else if (mode == 1) pos = ftell(f) + off;
    else if (mode == -1) { pos = ftell(f) - off; if (pos < 0) pos = 0; }
    else { ferdek_die("SKOCZ: tryb musi być 0 (od początku), 1 (do przodu) albo -1 (do tyłu)"); pos = 0; }
    fseek(f, pos, SEEK_SET);
    return make_int(pos);
}

static FerdekValue b_pozycja(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_FILE) ferdek_die("POZYCJA: argument musi być uchwytem pliku");
    return make_int(ftell(argv[0].value.file_val.f));
}

/* POLAŁA SIĘ KREW(format, ...) - I_Error z DOOM-a; formatowanie jak w interpreterze */
static FerdekValue b_polala_krew(int argc, FerdekValue* argv) {
    if (argc == 0) ferdek_die("POLAŁA SIĘ KREW: potrzeba co najmniej jednego argumentu");
    char* fmt = to_str(argv[0]);
    StrBuf b = {0};
    buf_add(&b, "");
    int next = 1;
    for (char* p = fmt; *p; ) {
        if (p[0] == '%' && p[1]) {
            char spec = p[1];
            char num[32];
            if ((spec == 'd' || spec == 'i') && next < argc) {
                snprintf(num, sizeof num, "%lld", to_int(argv[next++])); buf_add(&b, num); p += 2; continue;
            }
            if (spec == 's' && next < argc) { char* s = to_str(argv[next++]); buf_add(&b, s); free(s); p += 2; continue; }
            if (spec == '%') { buf_add(&b, "%"); p += 2; continue; }
            if (next >= argc) { buf_add(&b, "%"); p += 1; continue; }   /* brak argumentów: zostaw samo % */
            char keep[3] = { '%', spec, '\0' };
            buf_add(&b, keep);
            p += 2;
            continue;
        }
        char c[2] = { *p, '\0' };
        buf_add(&b, c);
        p++;
    }
    ferdek_die("I_Error: %s", b.s);
    return make_null();
}

/* ---- UDP (GNIAZDKO_*), jak w interpreterze: nieblokujące, SO_REUSEADDR ---- */

static FerdekValue b_gniazdko_otworz(int argc, FerdekValue* argv) {
    long long port = to_int(argv[0]);
    int one = 1;
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) ferdek_die("GNIAZDKO_OTWORZ: socket: %s", strerror(errno));
    if (fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0) ferdek_die("GNIAZDKO_OTWORZ: fcntl: %s", strerror(errno));
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one) < 0) ferdek_die("GNIAZDKO_OTWORZ: setsockopt: %s", strerror(errno));
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof addr);
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons((unsigned short)port);
    if (bind(fd, (struct sockaddr*)&addr, sizeof addr) < 0) ferdek_die("GNIAZDKO_OTWORZ: bind: %s", strerror(errno));
    printf("Gniazdko UDP otwarte na porcie %lld\n", port);
    fflush(stdout);
    return make_int(fd);
}

static FerdekValue b_gniazdko_wyslij(int argc, FerdekValue* argv) {
    int fd = (int)to_int(argv[0]);
    char* host = to_str(argv[1]);
    long long port = to_int(argv[2]);
    FerdekValue d = argv[3];
    char* data;
    size_t len;
    if (d.type == TYPE_STRING) { data = d.value.string_val; len = strlen(data); }
    else if (d.type == TYPE_ARRAY) {
        len = d.value.array_val->length;
        data = malloc(len > 0 ? len : 1);
        for (size_t i = 0; i < len; i++) data[i] = (char)(to_int(d.value.array_val->data[i]) & 0xFF);
    } else { ferdek_die("GNIAZDKO_WYSLIJ: dane muszą być tekstem albo tablicą bajtów"); return make_null(); }
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons((unsigned short)port);
    /* Unix.inet_addr_of_string rzuca Failure - interpreter wypisuje to jako poważną awarię */
    if (inet_pton(AF_INET, host, &addr.sin_addr) != 1) ferdek_die("Poważna awaria: inet_addr_of_string");
    ssize_t sent = sendto(fd, data, len, 0, (struct sockaddr*)&addr, sizeof addr);
    if (sent < 0) ferdek_die("GNIAZDKO_WYSLIJ: sendto: %s", strerror(errno));
    return make_int(sent);
}

/* 0 gdy nic nie przyszło, inaczej [dane, host, port] */
static FerdekValue b_gniazdko_odbierz(int argc, FerdekValue* argv) {
    int fd = (int)to_int(argv[0]);
    long long size = to_int(argv[1]);
    char* buf = malloc(size + 1);
    struct sockaddr_in from;
    socklen_t flen = sizeof from;
    ssize_t n = recvfrom(fd, buf, size, 0, (struct sockaddr*)&from, &flen);
    if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) return make_int(0);
        ferdek_die("GNIAZDKO_ODBIERZ: recvfrom: %s", strerror(errno));
    }
    if (n == 0) return make_int(0);
    buf[n] = '\0';
    char host[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &from.sin_addr, host, sizeof host);
    return make_array((FerdekValue[]){ own_string(buf), make_string(host), make_int(ntohs(from.sin_port)) }, 3);
}

static FerdekValue b_gniazdko_zamknij(int argc, FerdekValue* argv) {
    if (close((int)to_int(argv[0])) < 0) ferdek_die("GNIAZDKO_ZAMKNIJ: close: %s", strerror(errno));
    printf("Gniazdko UDP zamknięte\n");
    fflush(stdout);
    return make_null();
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

(* Nakładki na graphics_x11.c (Graphics_source) - dołączane tylko do programów z grafiką *)
let graphics_runtime = {|
static FerdekValue gfx_okno_otworz(int argc, FerdekValue* argv) {
    int r = ferdek_window_open((int)to_int(argv[0]), (int)to_int(argv[1]), to_str(argv[2]));
    if (r == 0) ferdek_die("OKNO_OTWORZ: nie udało się otworzyć okna");
    return make_int(r);
}
static FerdekValue gfx_okno_zamknij(int argc, FerdekValue* argv) { ferdek_window_close(); return make_null(); }
static FerdekValue gfx_paleta_ustaw(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_ARRAY) ferdek_die("PALETA_USTAW: argument musi być tablicą");
    FerdekArray* a = argv[0].value.array_val;
    if (a->length != 768) ferdek_die("PALETA_USTAW: paleta musi mieć 768 bajtów (256 kolorów * RGB)");
    unsigned char pal[768];
    for (int i = 0; i < 768; i++) pal[i] = (unsigned char)(to_int(a->data[i]) & 0xFF);
    ferdek_palette_set(pal);
    return make_null();
}
static FerdekValue gfx_piksel_maluj(int argc, FerdekValue* argv) {
    ferdek_pixel_draw((int)to_int(argv[0]), (int)to_int(argv[1]), (unsigned char)(to_int(argv[2]) & 0xFF));
    return make_null();
}
static FerdekValue gfx_ekran_odswiez(int argc, FerdekValue* argv) { ferdek_screen_refresh(); return make_null(); }
static FerdekValue gfx_ekran_czysc(int argc, FerdekValue* argv) {
    ferdek_screen_clear((unsigned char)(to_int(argv[0]) & 0xFF));
    return make_null();
}
static FerdekValue gfx_bufor_pobierz(int argc, FerdekValue* argv) {
    return make_int(ferdek_framebuffer_get((int)to_int(argv[0]), (int)to_int(argv[1])));
}
static FerdekValue gfx_zdarzenie(int argc, FerdekValue* argv) {
    ferdek_event_t e = ferdek_event_poll();
    return make_array((FerdekValue[]){ make_int(e.type), make_int(e.key), make_int(e.x), make_int(e.y) }, 4);
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
              in_function = false; loop_handlers = []; counter = 0;
              classes = Hashtbl.create 8; records = Hashtbl.create 8; members = [] } in
  List.iter (function
    | FunctionDecl f -> Hashtbl.replace ctx.funcs f.name f
    | ClassDecl c -> Hashtbl.replace ctx.classes c.name c
    | StructDecl s -> Hashtbl.replace ctx.records s.name s.fields
    (* Unia: interpreter inicjuje tylko pierwsze pole *)
    | UnionDecl u -> Hashtbl.replace ctx.records u.name (match u.fields with f :: _ -> [f] | [] -> [])
    | EnumDecl e -> List.iter (fun (n, _) -> Hashtbl.replace ctx.globals n ()) e.values
    | Statement s ->
        let decl, assigned = stmt_names ([], []) s in
        List.iter (fun n -> Hashtbl.replace ctx.globals n ()) (decl @ assigned)
    | _ -> ()) prog.declarations;

  let functions = List.filter_map (function
    | FunctionDecl f -> Some (compile_function ctx f)
    | _ -> None) prog.declarations in
  let classes = Hashtbl.fold (fun _ c acc -> c :: acc) ctx.classes []
                |> List.sort (fun (a : class_decl) b -> compare a.name b.name) in
  let methods = List.concat_map (fun (c : class_decl) ->
    List.map (fun m -> (c, m)) c.methods) classes in
  let method_code = List.map (fun (c, m) -> compile_method ctx c m) methods in
  let method_wrappers = List.map (fun ((c : class_decl), m) -> compile_method_wrapper c.name m) methods in
  let constructors = List.map (compile_class_constructor ctx) classes
                     @ (Hashtbl.fold (fun n fs acc -> (n, fs) :: acc) ctx.records [] |> List.sort compare
                        |> List.map (fun (n, fs) -> compile_record_constructor ctx n fs)) in
  let object_protos = List.map (fun ((c : class_decl), m) -> method_proto c.name m ^ ";") methods
                      @ List.map (fun ((c : class_decl), m) -> method_wrap_proto c.name m ^ ";") methods
                      @ List.map (fun (c : class_decl) -> constructor_proto c.name ^ ";") classes
                      @ Hashtbl.fold (fun n _ acc -> (constructor_proto n ^ ";") :: acc) ctx.records [] in
  let main_body = List.map (compile_top_level ctx) prog.declarations
                  |> List.filter (fun s -> s <> "") in
  let globals = Hashtbl.fold (fun n () acc -> n :: acc) ctx.globals [] |> dedup
                |> List.map (fun n -> Printf.sprintf "static FerdekValue %s;" (var_c n)) in
  let protos = Hashtbl.fold (fun _ f acc -> (fun_proto f ^ ";") :: (wrap_proto f ^ ";") :: acc) ctx.funcs [] |> dedup in
  let wrappers = Hashtbl.fold (fun _ f acc -> compile_wrapper f :: acc) ctx.funcs [] |> dedup in

  let program_code = String.concat "\n" (functions @ method_code @ main_body @ constructors) in
  let graphics =
    if Str.string_match (Str.regexp ".*gfx_") (String.map (fun c -> if c = '\n' then ' ' else c) program_code) 0
    then [Graphics_source.code; graphics_runtime] else [] in  (* code ma własne deklaracje - bez nagłówka *)
  String.concat "\n" ([
    "#define _POSIX_C_SOURCE 200809L  /* strdup, nanosleep, clock_gettime przy -std=c99 */";
    "#include <stdio.h>";
    "#include <stdlib.h>";
    "#include <string.h>";
    "#include <stdbool.h>";
    "#include <stdarg.h>";
    "#include <setjmp.h>";
    "#include <time.h>";
    "#include <ctype.h>";
    "#include <math.h>";
    "#include <errno.h>";
    "#include <dirent.h>";
    "#include <unistd.h>";
    "#include <sys/stat.h>";
    "#include <sys/socket.h>";
    "#include <netinet/in.h>";
    "#include <arpa/inet.h>";
    "#include <fcntl.h>";
    "";
    runtime_library;
  ] @ graphics @ globals @ [""] @ protos @ object_protos @ [""] @ functions @ method_code @ [""] @ wrappers
    @ method_wrappers @ [""] @ constructors @ [
    "";
    "int main(void) {";
    "    clock_gettime(CLOCK_MONOTONIC, &program_start);";
  ] @ main_body @ [
    "    return 0;";
    "}";
    "";
  ])
