(* Compiler for Ferdek Programming Language - Compiles to C *)
(* Kompilator obsługuje rdzeń języka. Wszystko inne kończy się Compile_error
   z czytelnym komunikatem - nigdy po cichu zepsutym kodem C. *)

open Ast
open Infer

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
  ["PO PIERWSZE PRIMO"], ("b_po_pierwsze_primo", Some 2);
  ["ZAPAKUJ DO SŁOIKA"], ("b_zapakuj", Some 1);
  ["WYJMIJ ZE SŁOIKA"], ("b_wyjmij_ze_sloika", Some 1);
  ["WYTNIJ Z WERSALKI"], ("b_wytnij", Some 3);
  ["GDZIE LEŻY NA WERSALCE"], ("b_gdzie_lezy", Some 2);
  ["ZESTAW WERSALKI"], ("b_zestaw", Some 2);
  ["ZSUMUJ WERSALKĘ"], ("b_zsumuj", Some 1);
  ["NAJMNIEJSZY NA WERSALCE"], ("b_najmniejszy", Some 1);
  ["NAJWIĘKSZY NA WERSALCE"], ("b_najwiekszy", Some 1);
  ["ZWIŃ WERSALKĘ"], ("b_zwin", Some 3);
  ["BEZ POWTÓREK"], ("b_bez_powtorek", Some 1);
  ["ZRÓB KOLEJKĘ"], ("b_kolejka", Some 2);
  ["WYLOSUJ Z WERSALKI"], ("b_wylosuj", Some 1);
  ["POWTÓRZ NA KANAPIE"], ("b_powtorz", Some 2);
  ["CZY SIEDZI NA KANAPIE"], ("b_czy_siedzi", Some 2);
  ["GDZIE SIEDZI NA KANAPIE"], ("b_gdzie_siedzi", Some 2);
  ["ZACZYNA SIĘ OD"], ("b_zaczyna", Some 2);
  ["KOŃCZY SIĘ NA"], ("b_konczy", Some 2);
  ["ODWRÓĆ KANAPĘ"], ("b_odwroc_kanape", Some 1);
  ["ROZCIĄGNIJ Z LEWEJ"], ("b_rozciagnij_lewo", Some 2);
  ["WSZYSTKIE RZECZY"], ("b_wszystkie_rzeczy", Some 1);
  ["DOŁÓŻ SZAFKĘ"], ("b_doloz_szafke", Some 2);
  ["JAKI DZIŚ DZIEŃ"], ("b_dzis", Some 0);
  ["KTÓRA GODZINA"], ("b_godzina", Some 0);
  ["DZIEŃ TYGODNIA"], ("b_dzien_tygodnia", Some 1);
  ["DODAJ DNI"], ("b_dodaj_dni", Some 2);
  ["ILE DNI MIĘDZY"], ("b_ile_dni", Some 2);
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
  ["CO PAN PRZYNIÓSŁ"], ("b_co_pan_przyniosl", Some 0);
  ["CO MÓWI SĄSIAD"], ("b_co_mowi_sasiad", Some 1);
  ["ZAMYKAM INTERES"], ("b_zamykam_interes", Some 1);
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
  ["OTWÓRZ SZAFKĘ"], ("b_szafka_otworz", None);
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

(* Co trzeba zrobić, wychodząc z bloku przez return/break/continue: posprzątać (finally,
   z handlerem danego try) albo nic, bo to pętla, do której skaczemy *)
type unwind = Fin of string * stmt list | LoopMark

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
  mutable lambdas: string list;               (* Kod funkcji z lambd, od ostatniej *)
  (* Liczby całkowite bez opakowania (infer_ints) *)
  mutable ints: string list;                  (* zmienne long long widoczne w bieżącym miejscu *)
  mutable ret_int: bool;                      (* bieżąca funkcja zwraca long long *)
  sigs: (string, bool list * bool) Hashtbl.t; (* funkcje z parametrami/wynikiem long long *)
  int_globals: (string, unit) Hashtbl.t;
  int_locals: (string, string list) Hashtbl.t; (* funkcja -> jej zmienne i parametry long long *)
  mutable floats: string list;                (* zmienne double widoczne w bieżącym miejscu *)
  mutable fn_has_try: bool;                   (* bieżąca funkcja ma try - tylko wtedy pilnuje handlera *)
  mutable unwind: unwind list;                (* otaczające bloki sprzątania i pętle, od najbliższego *)
  float_globals: (string, unit) Hashtbl.t;
  float_locals: (string, string list) Hashtbl.t;
}

let fresh ctx prefix =
  ctx.counter <- ctx.counter + 1;
  Printf.sprintf "%s%d" prefix ctx.counter

let rec has_try stmts = List.exists (function
  | Try _ -> true
  | If (_, a, b) -> has_try a || has_try (Option.value b ~default:[])
  | While (_, b) | For (_, _, _, _, b) | ForEach (_, _, b) -> has_try b
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

(* Ile argumentów trzeba podać (bez parametrów z wartością domyślną) *)
let required_args (f : function_decl) = List.length f.params - List.length f.defaults

let with_required (f : function_decl) code =
  if f.defaults = [] then code else Printf.sprintf "with_required(%s, %d)" code (required_args f)

let function_value ctx name =
  let f = Hashtbl.find ctx.funcs name in
  with_required f (Printf.sprintf "make_function(%s, %s, %d, %s)" (wrap_c name) (c_string_literal name)
    (List.length f.params) (if f.is_variadic then "true" else "false"))

(* Tablica argumentów dla wywołań (argc, argv) *)
let argv_c c_args = if c_args = [] then "(FerdekValue[]){make_null()}" else
  Printf.sprintf "(FerdekValue[]){%s}" (String.concat ", " c_args)

(* Literał double zawsze z kropką albo wykładnikiem - inaczej 3 / 2 w C to dzielenie całkowite *)
let float_lit f =
  let s = Printf.sprintf "%.17g" f in
  if String.exists (fun c -> c = '.' || c = 'e' || c = 'n' || c = 'i') s then s else s ^ ".0"

let global_ints ctx = Hashtbl.fold (fun n () acc -> n :: acc) ctx.int_globals []
let global_floats ctx = Hashtbl.fold (fun n () acc -> n :: acc) ctx.float_globals []

let tenv ctx = {
  ivar = (fun n -> List.mem n ctx.ints && not (is_function_name ctx n));
  fvar = (fun n -> List.mem n ctx.floats && not (is_function_name ctx n));
  ifun = (fun n -> if is_function_name ctx n && find_builtin n = None then Hashtbl.find_opt ctx.sigs n else None);
}

(* Kilka obliczeń od lewej do prawej, jak w interpreterze. C nie ustala kolejności liczenia
   operandów, argumentów funkcji ani elementów inicjalizatora - a części mogą mieć skutki uboczne
   (funkcja zmieniająca zmienną, wypisywanie, błąd). Gdy więcej niż jedna część nie jest stałą,
   liczymy je po kolei do zmiennych tymczasowych w wyrażeniu blokowym ({ ... }) (gcc i clang).
   parts: (wyrażenie Ferdka, typ C, kod C); k dostaje kody albo nazwy zmiennych tymczasowych. *)
let is_literal = function
  | IntLiteral _ | FloatLiteral _ | StringLiteral _ | BoolLiteral _ | NullLiteral -> true
  | _ -> false

let in_order ctx parts k =
  if List.length (List.filter (fun (e, _, _) -> not (is_literal e)) parts) <= 1 then
    k (List.map (fun (_, _, c) -> c) parts)
  else
    let decls, names = List.split (List.map (fun (e, ty, c) ->
      if is_literal e then ("", c)
      else let n = fresh ctx "ord_" in (Printf.sprintf "%s %s = %s; " ty n c, n)) parts) in
    Printf.sprintf "({ %s%s; })" (String.concat "" decls) (k names)

let fv = "FerdekValue"

(* Kod C lambdy: ctx, nazwa, parametry, złapane nazwy, ciało. Ustawiane niżej, przy compile_body *)
let compile_lambda : (codegen_context -> string -> string list -> string list -> stmt list -> string) ref =
  ref (fun _ _ _ _ _ -> "")

let type_tag = function
  | TInt -> "TYPE_INT" | TFloat -> "TYPE_FLOAT" | TString -> "TYPE_STRING" | TBool -> "TYPE_BOOL"
  | TArray -> "TYPE_ARRAY" | TMap -> "TYPE_MAP" | TFunction -> "TYPE_FUNCTION"

let rec compile_expr ctx expr =
  match expr with
  | (Identifier _ | BinaryOp _ | FunctionCall _ | Parenthesized _) when is_int (tenv ctx) expr ->
      Printf.sprintf "make_int(%s)" (compile_int ctx expr)
  | (Identifier _ | BinaryOp _ | FunctionCall _ | Parenthesized _) when is_float (tenv ctx) expr ->
      Printf.sprintf "make_float(%s)" (compile_float ctx expr)
  | ComparisonOp (a, _, b) when num_type (tenv ctx) a <> Other && num_type (tenv ctx) b <> Other ->
      Printf.sprintf "make_bool(%s)" (compile_cond ctx expr)
  | ArrayAccess (arr, idx) when is_int (tenv ctx) idx ->
      in_order ctx [arr, fv, compile_expr ctx arr; idx, "long long", compile_int ctx idx]
        (fun c -> Printf.sprintf "index_get_i(%s, %s)" (List.nth c 0) (List.nth c 1))
  | IntLiteral n -> Printf.sprintf "make_int(%dLL)" n
  | FloatLiteral f -> Printf.sprintf "make_float(%.17g)" f
  | StringLiteral s -> Printf.sprintf "make_lit(%s)" (c_string_literal s)
  | BoolLiteral b -> Printf.sprintf "make_bool(%s)" (if b then "true" else "false")
  | NullLiteral -> "make_null()"
  | Identifier name when is_member ctx name -> Printf.sprintf "field_get(self, %s)" (c_string_literal name)
  | Identifier name | Reference (Identifier name) when is_function_name ctx name ->
      function_value ctx name
  | Identifier name ->
      if is_var ctx name then var_c name
      else if is_type_name ctx name then unsupported "nazwa klasy/struktury jako wartość"
      else error (Errors.unknown "zmienna" name
                    (ctx.locals @ ctx.members @ Hashtbl.fold (fun n () acc -> n :: acc) ctx.globals []))
  | BinaryOp (e1, op, e2) ->
      in_order ctx [e1, fv, compile_expr ctx e1; e2, fv, compile_expr ctx e2]
        (fun c -> Printf.sprintf "%s(%s, %s)" (arith_c op) (List.nth c 0) (List.nth c 1))
  | ComparisonOp (e1, op, e2) ->
      in_order ctx [e1, fv, compile_expr ctx e1; e2, fv, compile_expr ctx e2]
        (fun c -> Printf.sprintf "compare_op(%s, %s, %s)" (List.nth c 0) (List.nth c 1) (comparison_c op))
  | LogicalOp (e1, op, e2) ->
      in_order ctx [e1, fv, compile_expr ctx e1; e2, fv, compile_expr ctx e2]
        (fun c -> Printf.sprintf "%s(%s, %s)" (match op with And -> "logic_and" | Or -> "logic_or")
                    (List.nth c 0) (List.nth c 1))
  | BitwiseOp _ -> Printf.sprintf "make_int(%s)" (compile_int ctx expr)
  | BitwiseNot e -> Printf.sprintf "make_int(~to_int(%s))" (compile_expr ctx e)
  | LogicalNot e -> Printf.sprintf "make_bool(!to_bool(%s))" (compile_expr ctx e)
  | ArrayLiteral [] -> "make_array(NULL, 0)"
  | ArrayLiteral es ->
      in_order ctx (List.map (fun e -> e, fv, compile_expr ctx e) es)
        (fun c -> Printf.sprintf "make_array((FerdekValue[]){%s}, %d)" (String.concat ", " c) (List.length es))
  | ToFixed e -> Printf.sprintf "to_fixed(%s)" (compile_expr ctx e)
  | FromFixed e -> Printf.sprintf "make_int(ishr(to_int(%s), 16))" (compile_expr ctx e)
  | ArrayAccess (arr, idx) ->
      in_order ctx [arr, fv, compile_expr ctx arr; idx, fv, compile_expr ctx idx]
        (fun c -> Printf.sprintf "index_get(%s, %s)" (List.nth c 0) (List.nth c 1))
  | FunctionCall (name, args) -> compile_call ctx name args
  | Parenthesized e -> Printf.sprintf "(%s)" (compile_expr ctx e)
  | Checked (e, t, what) ->
      Printf.sprintf "check_type(%s, %s, %s)" (compile_expr ctx e) (type_tag t) (c_string_literal what)
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
      in_order ctx [e1, fv, compile_expr ctx e1; e2, fv, compile_expr ctx e2]
        (fun c -> Printf.sprintf "pointer_step(%s, %s, %s)" (List.nth c 0) (List.nth c 1)
                    (if op = Minus then "-1" else "1"))
  | FunctionRef name when is_function_name ctx name -> function_value ctx name
  | FunctionRef name -> error (Printf.sprintf "Nieznana funkcja: %s" name)
  | Lambda (params, body) ->
      (* Osobna funkcja C; złapane zmienne lokalne i pola obiektu (kopie wartości z chwili
         utworzenia) siedzą w self; każde wywołanie zaczyna od tych kopii *)
      let caps = expr_names (Lambda (params, body))
                 |> List.filter (fun n -> List.mem n ctx.locals || is_member ctx n)
                 |> List.sort_uniq compare in
      let cap_values = List.map (fun n -> compile_expr ctx (Identifier n)) caps in
      let name = fresh ctx "lambda_" in
      let saved = (ctx.locals, ctx.members, ctx.in_function, ctx.loop_handlers, ctx.ints, ctx.ret_int, ctx.floats, ctx.fn_has_try) in
      ctx.loop_handlers <- [];
      let code = !compile_lambda ctx name params caps body in
      let (l, m, f, h, i, r, fl, t) = saved in
      ctx.locals <- l; ctx.members <- m; ctx.in_function <- f; ctx.loop_handlers <- h;
      ctx.ints <- i; ctx.ret_int <- r; ctx.floats <- fl; ctx.fn_has_try <- t;
      ctx.lambdas <- code :: ctx.lambdas;
      Printf.sprintf "make_method(%s, \"anonimowa\", %d, false, %s)" name (List.length params)
        (if caps = [] then "NULL"
         else Printf.sprintf "copy_values(%d, %s)" (List.length caps) (argv_c cap_values))

(* Wyrażenie, o którym is_int wie, że jest liczbą -> wyrażenie C typu long long *)
and compile_int ctx e =
  let env = tenv ctx in
  let arg a = if is_int env a then compile_int ctx a else Printf.sprintf "to_int(%s)" (compile_expr ctx a) in
  let two a b f = in_order ctx [a, "long long", arg a; b, "long long", arg b] (fun c -> f (List.nth c 0) (List.nth c 1)) in
  match e with
  | IntLiteral n -> Printf.sprintf "%dLL" n
  | Identifier n when env.ivar n -> var_c n
  | Parenthesized e -> Printf.sprintf "(%s)" (compile_int ctx e)
  | BinaryOp (a, op, b) when is_int env e ->
      let f = match op with
        | Plus -> "iadd" | Minus -> "isub" | Multiply -> "imul" | Divide -> "int_div" | Modulo -> "int_mod" in
      two a b (Printf.sprintf "%s(%s, %s)" f)
  | BitwiseOp (a, BitShiftLeft, b) -> two a b (Printf.sprintf "ishl(%s, %s)")
  | BitwiseOp (a, BitShiftRight, b) -> two a b (Printf.sprintf "ishr(%s, %s)")
  | BitwiseOp (a, op, b) -> two a b (fun x y -> Printf.sprintf "(%s %s %s)" x (bitwise_c op) y)
  | BitwiseNot a -> Printf.sprintf "(~%s)" (arg a)
  (* sprawdzenie niepotrzebne, gdy kompilator i tak wie, że to liczba *)
  | Checked (inner, TInt, _) when is_int env inner -> compile_int ctx inner
  | FunctionCall (f, args) when List.mem f int_builtins -> compile_call_generic ctx f args ^ ".value.int_val"
  | FunctionCall (f, args) when is_int env e -> specialized_call ctx f args
  | e -> Printf.sprintf "to_int(%s)" (compile_expr ctx e)

(* Wyrażenie liczbowe (całkowite albo z przecinkiem) -> double; to samo, co op_* dla FLOAT *)
and compile_float ctx e =
  let env = tenv ctx in
  match e with
  | FloatLiteral f -> float_lit f
  | e when is_int env e -> Printf.sprintf "((double)%s)" (compile_int ctx e)
  | Identifier n when env.fvar n -> var_c n
  | Parenthesized e -> Printf.sprintf "(%s)" (compile_float ctx e)
  | BinaryOp (a, op, b) when is_float env e ->
      in_order ctx [a, "double", compile_float ctx a; b, "double", compile_float ctx b] (fun c ->
        let a = List.nth c 0 and b = List.nth c 1 in
        match op with
        | Plus -> Printf.sprintf "(%s + %s)" a b
        | Minus -> Printf.sprintf "(%s - %s)" a b
        | Multiply -> Printf.sprintf "(%s * %s)" a b
        | Divide -> Printf.sprintf "float_div(%s, %s)" a b
        | Modulo -> Printf.sprintf "float_mod(%s, %s)" a b)
  | Checked (inner, TFloat, _) when is_float env inner -> compile_float ctx inner
  | FunctionCall (f, args) when List.mem f float_builtins -> compile_call_generic ctx f args ^ ".value.float_val"
  | e -> Printf.sprintf "to_float(%s)" (compile_expr ctx e)

(* Warunek w if/while: porównanie liczb wprost w C, reszta przez to_bool *)
and compile_cond ctx e =
  let env = tenv ctx in
  match e with
  | ComparisonOp (a, op, b) when is_int env a && is_int env b ->
      let c = match op with Equal -> "==" | NotEqual -> "!=" | Greater -> ">" | Less -> "<" | GreaterEqual -> ">=" in
      in_order ctx [a, "long long", compile_int ctx a; b, "long long", compile_int ctx b]
        (fun x -> Printf.sprintf "%s %s %s" (List.nth x 0) c (List.nth x 1))
  | ComparisonOp (a, op, b) when num_type env a <> Other && num_type env b <> Other ->
      (* jak compare3: (x > y) - (x < y), więc NaN wychodzi "równe" - tak samo jak w interpreterze *)
      let c = match op with Equal -> "==" | NotEqual -> "!=" | Greater -> ">" | Less -> "<" | GreaterEqual -> ">=" in
      in_order ctx [a, "double", compile_float ctx a; b, "double", compile_float ctx b]
        (fun x -> Printf.sprintf "fcmp(%s, %s) %s 0" (List.nth x 0) (List.nth x 1) c)
  | ComparisonOp (a, op, b) ->
      in_order ctx [a, fv, compile_expr ctx a; b, fv, compile_expr ctx b]
        (fun x -> Printf.sprintf "compare_bool(%s, %s, %s)" (List.nth x 0) (List.nth x 1) (comparison_c op))
  | Parenthesized e -> compile_cond ctx e
  | e -> Printf.sprintf "to_bool(%s)" (compile_expr ctx e)

(* Wywołanie funkcji wyspecjalizowanej: argumenty long long tam, gdzie trzeba; wynik surowy *)
and specialized_call ctx name args =
  let ps, _ = Hashtbl.find ctx.sigs name in
  if List.length ps <> List.length args then
    error (Printf.sprintf "Funkcja %s oczekuje %s, podano %d" name (Errors.argumentow (List.length ps)) (List.length args));
  in_order ctx (List.map2 (fun is_i a ->
      if is_i then (a, "long long", compile_int ctx a) else (a, fv, compile_expr ctx a)) ps args)
    (fun c -> Printf.sprintf "%s(%s)" (fun_c name) (String.concat ", " c))

and compile_call ctx name args =
  match (tenv ctx).ifun name with
  | Some (_, r) -> let call = specialized_call ctx name args in if r then Printf.sprintf "make_int(%s)" call else call
  | None -> compile_call_generic ctx name args

and compile_call_generic ctx name args =
  in_order ctx (List.map (fun a -> a, fv, compile_expr ctx a) args) (fun c_args -> call_with_args ctx name args c_args)

and call_with_args ctx name args c_args =
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
        let lo = required_args f in
        if given < lo || given > n then
          error (Printf.sprintf "Funkcja %s oczekuje %s, podano %d" name
                   (if lo = n then Errors.argumentow n else Errors.range_args lo n) given);
        (* z wartościami domyślnymi: ile podano + puste miejsca na resztę (uzupełnia funkcja) *)
        let args = if f.defaults = [] then c_args
          else string_of_int given :: c_args @ List.init (n - given) (fun _ -> "make_null()") in
        Printf.sprintf "%s(%s)" (fun_c name) (String.concat ", " args)
      end
  | None, _ when List.mem name ctx.locals || (Hashtbl.mem ctx.globals name && not (is_member ctx name)
                                               && not (Hashtbl.mem ctx.funcs name)) ->
      (* Wywołanie funkcji trzymanej w zmiennej - sprawdzenie typu i arności w runtime *)
      Printf.sprintf "call_value(%s, %s, %d, %s)" (compile_expr ctx (Identifier name)) (c_string_literal name)
        (List.length args) (argv_c c_args)
  | None, _ when is_member ctx name ->
      (* Metoda (albo pole z funkcją) bieżącego obiektu *)
      Printf.sprintf "call_value(field_get(self, %s), %s, %d, %s)" (c_string_literal name)
        (c_string_literal name) (List.length args) (argv_c c_args)
  | None, _ ->
      error (Errors.unknown "funkcja" name
               (ctx.locals @ ctx.members @ Hashtbl.fold (fun n _ acc -> n :: acc) ctx.funcs []
                @ List.concat_map fst builtins))

(* Przypisanie: zmienna lokalna/globalna albo - w metodzie - pole obiektu *)
let assign ctx name value =
  if is_member ctx name then Printf.sprintf "field_set(self, %s, %s);" (c_string_literal name) value
  else if List.mem name ctx.ints then Printf.sprintf "%s = to_int(%s);" (var_c name) value
  else if List.mem name ctx.floats then Printf.sprintf "%s = to_float(%s);" (var_c name) value
  else Printf.sprintf "%s = %s;" (var_c name) value

(* Ciało pętli; gdy w środku jest try, break/continue muszą zdjąć handlery założone w pętli *)
let rec loop_body ctx indent body =
  let h = if has_try body then fresh ctx "loop_handler" else "" in
  let saved = ctx.loop_handlers and saved_unwind = ctx.unwind in
  ctx.loop_handlers <- h :: saved;
  ctx.unwind <- LoopMark :: saved_unwind;
  let code = String.concat "\n" (List.map (compile_stmt ctx (indent + 1)) body) in
  ctx.loop_handlers <- saved;
  ctx.unwind <- saved_unwind;
  let setup = if h = "" then "" else Printf.sprintf "%s    Handler* %s = ferdek_handler;\n" (String.make (indent * 4) ' ') h in
  (setup, code)

(* Kod bloków sprzątania od najbliższego, przy wyjściu z nich przez return (wszystkie w funkcji)
   albo break/continue (do najbliższej pętli). Każdy wykonuje się z handlerem i ścieżką wywołań
   sprzed swojego try, a sam jest kompilowany bez siebie na liście - return w nim nie zapętli. *)
and run_finallies ctx indent ~to_loop =
  let rec go = function
    | [] | LoopMark :: _ when to_loop -> []
    | LoopMark :: rest -> go rest
    | Fin (h, stmts) :: rest ->
        let saved = ctx.unwind in
        ctx.unwind <- rest;
        let code = Printf.sprintf "ferdek_handler = %s.prev; ferdek_top = %s.top;\n%s\n" h h
                     (String.concat "\n" (List.map (compile_stmt ctx indent) stmts)) in
        ctx.unwind <- saved;
        code :: go rest
    | [] -> [] in
  String.concat "" (go ctx.unwind)

and compile_stmt ctx indent stmt =
  let ind = String.make (indent * 4) ' ' in
  let block stmts = String.concat "\n" (List.map (compile_stmt ctx (indent + 1)) stmts) in
  match stmt with
  | ConstDecl (name, e) -> compile_stmt ctx indent (VarDecl (name, e))
  | VarDecl (name, e) | Assign (name, e) when List.mem name ctx.ints && not (is_member ctx name) ->
      Printf.sprintf "%s%s = %s;" ind (var_c name) (compile_int ctx e)
  | VarDecl (name, e) | Assign (name, e) when List.mem name ctx.floats && not (is_member ctx name) ->
      Printf.sprintf "%s%s = %s;" ind (var_c name) (compile_float ctx e)
  | VarDecl (name, e) | Assign (name, e) -> ind ^ assign ctx name (compile_expr ctx e)
  | ArrayDecl (name, []) ->
      Printf.sprintf "%s%s = make_array(NULL, 0);" ind (var_c name)
  | ArrayDecl (name, exprs) ->
      Printf.sprintf "%s%s = %s;" ind (var_c name) (compile_expr ctx (ArrayLiteral exprs))
  | Print e -> Printf.sprintf "%sprint_value(%s);" ind (compile_expr ctx e)
  | PrintInline e -> Printf.sprintf "%sprint_inline(%s);" ind (compile_expr ctx e)
  | Read name -> ind ^ assign ctx name "read_value()"
  (* Jak interpreter: najpierw wartość, potem tablica, potem indeks *)
  | ArrayAssign (ArrayAccess (arr, idx), value) when is_int (tenv ctx) idx ->
      ind ^ in_order ctx [value, fv, compile_expr ctx value; arr, fv, compile_expr ctx arr;
                          idx, "long long", compile_int ctx idx]
        (fun c -> Printf.sprintf "index_set_i(%s, %s, %s)" (List.nth c 1) (List.nth c 2) (List.nth c 0)) ^ ";"
  | ArrayAssign (ArrayAccess (arr, idx), value) ->
      ind ^ in_order ctx [value, fv, compile_expr ctx value; arr, fv, compile_expr ctx arr;
                          idx, fv, compile_expr ctx idx]
        (fun c -> Printf.sprintf "index_set(%s, %s, %s)" (List.nth c 1) (List.nth c 2) (List.nth c 0)) ^ ";"
  | ArrayAssign _ -> error "Przypisanie do tablicy bez indeksu"
  | If (cond, then_stmts, else_stmts) ->
      let else_code = match else_stmts with
        | None -> ""
        | Some stmts -> Printf.sprintf " else {\n%s\n%s}" (block stmts) ind
      in
      Printf.sprintf "%sif (%s) {\n%s\n%s}%s" ind (compile_cond ctx cond) (block then_stmts) ind else_code
  | While (cond, body) ->
      let setup, body_code = loop_body ctx indent body in
      Printf.sprintf "%s{\n%s%swhile (%s) {\n%s\n%s}\n%s}"
        ind setup ind (compile_cond ctx cond) body_code ind ind
  | For (var, from_e, to_e, step_e, body) ->
      (* Kolejność jak w interpreterze: od, do, krok; C-owe for robi krok także po continue *)
      let n = fresh ctx "" in
      if is_member ctx var then unsupported "pole obiektu jako licznik pętli";
      let v = var_c var in
      let int_of e = if is_int (tenv ctx) e then compile_int ctx e else Printf.sprintf "to_int(%s)" (compile_expr ctx e) in
      let step = match step_e with None -> "1" | Some e -> int_of e in
      let setup, body_code = loop_body ctx indent body in
      let loop =
        if List.mem var ctx.ints then
          Printf.sprintf "%sfor (%s = for_start%s; for_step%s > 0 ? %s <= for_stop%s : %s >= for_stop%s; %s = iadd(%s, for_step%s)) {"
            ind v n n v n v n v v n
        else
          Printf.sprintf "%sfor (%s = make_int(for_start%s); for_step%s > 0 ? to_int(%s) <= for_stop%s : to_int(%s) >= for_stop%s; %s = make_int(iadd(to_int(%s), for_step%s))) {"
            ind v n n v n v n v v n in
      String.concat "\n" [
        ind ^ "{";
        Printf.sprintf "%s    long long for_start%s = %s;" ind n (int_of from_e);
        Printf.sprintf "%s    long long for_stop%s = %s;" ind n (int_of to_e);
        Printf.sprintf "%s    long long for_step%s = %s;" ind n step;
        Printf.sprintf "%s    if (for_step%s == 0) ferdek_die(\"KRĘCI CEMENT BETONIARA: krok nie może być zerem\");" ind n;
        setup ^ loop;
        body_code;
        ind ^ "}";
        ind ^ "}" ]
  | ForEach (var, coll, body) ->
      let n = fresh ctx "" in
      if is_member ctx var then unsupported "pole obiektu jako zmienna pętli";
      let setup, body_code = loop_body ctx indent body in
      String.concat "\n" [
        ind ^ "{";
        Printf.sprintf "%s    FerdekArray* each%s = foreach_items(%s);" ind n (compile_expr ctx coll);
        setup ^ Printf.sprintf "%sfor (long long each_i%s = 0; each_i%s < each%s->length; each_i%s++) {" ind n n n n;
        Printf.sprintf "%s    %s" ind (assign ctx var (Printf.sprintf "each%s->data[each_i%s]" n n));
        body_code;
        ind ^ "}";
        ind ^ "}" ]
  | FunctionCallStmt (name, args) ->
      Printf.sprintf "%s%s;" ind (compile_call ctx name args)
  | FunctionCallWithAssign (var, func, args) when List.mem var ctx.ints && is_int (tenv ctx) (FunctionCall (func, args)) ->
      Printf.sprintf "%s%s = %s;" ind (var_c var) (compile_int ctx (FunctionCall (func, args)))
  | FunctionCallWithAssign (var, func, args) -> ind ^ assign ctx var (compile_call ctx func args)
  | Return e ->
      if not ctx.in_function then ind ^ "ferdek_fatal(\"I JA INFORMUJĘ ŻE WYCHODZĘ poza funkcją\");" else
      let ty, v = match e with
        | Some e when ctx.ret_int -> "long long", compile_int ctx e
        | None -> "FerdekValue", "make_null()"
        | Some e -> "FerdekValue", compile_expr ctx e in
      (* Wartość liczymy przed zdjęciem handlerów - może rzucić wyjątek *)
      Printf.sprintf "%s{ %s ret = %s; %s%sferdek_top = frame.prev; FERDEK_AT(frame.file, frame.line); return ret; }" ind ty v
        (run_finallies ctx (indent + 1) ~to_loop:false)
        (if ctx.fn_has_try then "ferdek_handler = entry_handler; " else "")
  | Try (try_stmts, var, catch_stmts, (_ :: _ as fin)) ->
      let h = fresh ctx "handler" and h2 = fresh ctx "handler" in
      let block ?(extra = 2) stmts = String.concat "\n" (List.map (compile_stmt ctx (indent + extra)) stmts) in
      let saved = ctx.unwind in
      ctx.unwind <- Fin (h, fin) :: saved;
      let try_code = block try_stmts and catch_code = block ~extra:3 catch_stmts in
      ctx.unwind <- saved;
      let i n = ind ^ String.make (4 * n) ' ' in
      String.concat "\n" [
        ind ^ "{";
        Printf.sprintf "%sHandler %s; %s.prev = ferdek_handler; %s.top = ferdek_top;" (i 1) h h h;
        Printf.sprintf "%sferdek_handler = &%s;" (i 1) h;
        Printf.sprintf "%sif (setjmp(%s.buf) == 0) {" (i 1) h;
        try_code;
        Printf.sprintf "%sferdek_handler = %s.prev;" (i 2) h;
        Printf.sprintf "%s} else {" (i 1);
        Printf.sprintf "%sferdek_handler = %s.prev; ferdek_top = %s.top;" (i 2) h h;
        Printf.sprintf "%s%s = ferdek_exception;" (i 2) (var_c var);
        (* błąd w catch: posprzątać i puścić go dalej - z tą samą pozycją *)
        Printf.sprintf "%sHandler %s; %s.prev = ferdek_handler; %s.top = ferdek_top;" (i 2) h2 h2 h2;
        Printf.sprintf "%sferdek_handler = &%s;" (i 2) h2;
        Printf.sprintf "%sif (setjmp(%s.buf) == 0) {" (i 2) h2;
        catch_code;
        Printf.sprintf "%sferdek_handler = %s.prev;" (i 3) h2;
        Printf.sprintf "%s} else {" (i 2);
        Printf.sprintf "%sferdek_handler = %s.prev; ferdek_top = %s.top;" (i 3) h2 h2;
        Printf.sprintf "%sbool pending_error = ferdek_exception_error; FerdekValue pending = ferdek_exception;" (i 3);
        Printf.sprintf "%sconst char* pending_file = ferdek_file; int pending_line = ferdek_line;" (i 3);
        block ~extra:3 fin;
        Printf.sprintf "%sFERDEK_AT(pending_file, pending_line); ferdek_rethrow(pending_error, pending);" (i 3);
        Printf.sprintf "%s}" (i 2);
        Printf.sprintf "%s}" (i 1);
        block ~extra:1 fin;
        ind ^ "}" ]
  | Try (try_stmts, var, catch_stmts, []) ->
      let h = fresh ctx "handler" in
      Printf.sprintf "%s{\n%s    Handler %s;\n%s    %s.prev = ferdek_handler; %s.top = ferdek_top;\n%s    ferdek_handler = &%s;\n%s    if (setjmp(%s.buf) == 0) {\n%s\n%s        ferdek_handler = %s.prev;\n%s    } else {\n%s        ferdek_handler = %s.prev; ferdek_top = %s.top;\n%s        %s = ferdek_exception;\n%s\n%s    }\n%s}"
        ind ind h ind h h ind h ind h
        (String.concat "\n" (List.map (compile_stmt ctx (indent + 2)) try_stmts))
        ind h ind ind h h ind (var_c var)
        (String.concat "\n" (List.map (compile_stmt ctx (indent + 2)) catch_stmts))
        ind ind
  | Throw e -> Printf.sprintf "%sferdek_throw(%s);" ind (compile_expr ctx e)
  | Located (file, line, s) ->
      cur_loc := (file, line);
      Printf.sprintf "%sFERDEK_AT(%s, %d);\n%s" ind (c_string_literal file) line (compile_stmt ctx indent s)
  | Break | Continue ->
      let kw = if stmt = Break then "break;" else "continue;" in
      let kw = if ctx.loop_handlers = [] then kw else run_finallies ctx indent ~to_loop:true ^ kw in
      (match ctx.loop_handlers with
       | [] ->   (* jak w interpreterze: błąd wykonania, nie wyskok z funkcji *)
           Printf.sprintf "%sferdek_fatal(\"%s poza pętlą\");" ind
             (if stmt = Break then "A POCAŁUJCIE MNIE WSZYSCY W DUPĘ" else "AKUKARACZA")
       | h :: _ when h <> "" -> Printf.sprintf "%sferdek_handler = %s; %s" ind h kw
       | _ -> ind ^ kw)

(* ============ FUNCTIONS ============ *)

(* setjmp: zmienne i parametry zmieniane w try muszą być volatile, inaczej po longjmp (catch)
   mogą mieć wartość sprzed try - trzymane w rejestrze, który longjmp przywraca *)
let volatile_if_try (f : function_decl) = if has_try f.body then "volatile " else ""

(* Funkcja wyspecjalizowana: parametry i wynik long long tam, gdzie infer_ints na to pozwolił *)
let fun_proto ctx (f : function_decl) =
  let ps, r = match Hashtbl.find_opt ctx.sigs f.name with
    | Some (ps, r) -> ps, r | None -> List.map (fun _ -> false) (all_params f), false in
  let params = List.map2 (fun p is_i -> volatile_if_try f ^ (if is_i then "long long " else "FerdekValue ") ^ var_c p)
      (all_params f) (ps @ List.init (List.length (all_params f) - List.length ps) (fun _ -> false)) in
  let params = if f.defaults = [] then params else "int argc" :: params in
  Printf.sprintf "%s %s(%s)" (if r then "long long" else "FerdekValue") (fun_c f.name)
    (if params = [] then "void" else String.concat ", " params)

(* Ciało funkcji albo metody. members <> [] = metoda: nazwy pól i metod obiektu (self) *)
let compile_body ?(own_ints = []) ?(own_floats = []) ?(ret_int = false) ?display ctx ~proto ~members (f : function_decl) =
  let decl, assigned = targets_block ([], []) f.body in
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
  (* long long: własne zmienne funkcji i globalne, których nic tu nie przesłania *)
  ctx.ints <- own_ints @ List.filter (fun n -> not (List.mem n ctx.locals || List.mem n members)) (global_ints ctx);
  ctx.floats <- own_floats @ List.filter (fun n -> not (List.mem n ctx.locals || List.mem n members)) (global_floats ctx);
  ctx.ret_int <- ret_int;
  let qual = volatile_if_try f in
  (* Bez try funkcja nie zmienia handlera (wołane funkcje przywracają swój) - nie trzeba go pilnować *)
  ctx.fn_has_try <- has_try f.body;
  let saved_unwind = ctx.unwind in
  ctx.unwind <- [];
  let decls = (if ctx.fn_has_try then "    Handler* entry_handler = ferdek_handler;" else "")
    :: Printf.sprintf "    Frame frame = { %s, ferdek_file, ferdek_line, ferdek_top }; ferdek_top = &frame;"
         (c_string_literal (Option.value display ~default:f.name))
    :: List.map (fun n ->
         if List.mem n own_ints then Printf.sprintf "    %slong long %s = 0;" qual (var_c n)
         else if List.mem n own_floats then Printf.sprintf "    %sdouble %s = 0.0;" qual (var_c n)
         else Printf.sprintf "    %sFerdekValue %s = make_null();" qual (var_c n)) locals in
  (* brakujące argumenty: wartości domyślne, liczone w funkcji - jak w interpreterze *)
  let fill = List.filter_map (fun (p, d) ->
    let i = let rec idx k = function x :: r -> if x = p then k else idx (k + 1) r | [] -> 0 in idx 0 f.params in
    Some (Printf.sprintf "    if (argc < %d) %s" (i + 1) (assign ctx p (compile_expr ctx d)))) f.defaults in
  let body = fill @ List.map (compile_stmt ctx 1) f.body in
  ctx.locals <- [];
  ctx.members <- [];
  ctx.in_function <- false;
  ctx.ints <- global_ints ctx;
  ctx.floats <- global_floats ctx;
  ctx.ret_int <- false;
  ctx.unwind <- saved_unwind;
  String.concat "\n" ([Printf.sprintf "%s {" proto] @ decls @ body
                      @ [(if ctx.fn_has_try then "    ferdek_handler = entry_handler;" else ""); "    ferdek_top = frame.prev;"; "    FERDEK_AT(frame.file, frame.line);";
                         if ret_int then "    return 0;" else "    return make_null();"; "}"])


let compile_function ctx (f : function_decl) =
  compile_body ctx ~proto:(fun_proto ctx f) ~members:[] f
    ~own_ints:(Option.value (Hashtbl.find_opt ctx.int_locals f.name) ~default:[])
    ~own_floats:(Option.value (Hashtbl.find_opt ctx.float_locals f.name) ~default:[])
    ~ret_int:(match Hashtbl.find_opt ctx.sigs f.name with Some (_, r) -> r | None -> false)

(* Lambda: ciało jak funkcja, której złapane zmienne są dodatkowymi parametrami (każde wywołanie
   dostaje świeże kopie z self), do tego wrapper (self, argc, argv) dla call_value *)
let () = compile_lambda := fun ctx name params caps body ->
  let f = { name; params = params @ caps; is_variadic = false; has_return = true; body; defaults = [] } in
  let proto = Printf.sprintf "static FerdekValue %s_body(%s)" name
      (if f.params = [] then "void"
       else String.concat ", " (List.map (fun p -> volatile_if_try f ^ "FerdekValue " ^ var_c p) f.params)) in
  let code = compile_body ~display:"anonimowa" ctx ~proto ~members:[] f in
  String.concat "\n" [
    code;
    Printf.sprintf "static FerdekValue %s(void* self, int argc, FerdekValue* argv) {" name;
    Printf.sprintf "    return %s_body(%s);" name
      (String.concat ", " (List.init (List.length params) (Printf.sprintf "argv[%d]")
                           @ List.init (List.length caps) (Printf.sprintf "((FerdekValue*)self)[%d]")));
    "}"]

(* Metoda: jak funkcja, z obiektem (self) jako pierwszym parametrem *)
let method_proto cls (m : function_decl) =
  let params = List.map (fun p -> volatile_if_try m ^ "FerdekValue " ^ var_c p) (all_params m) in
  let params = if m.defaults = [] then params else "int argc" :: params in
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
  if f.defaults <> [] then
    (* call_value sprawdził zakres; brakujące miejsca puste, funkcja wstawi wartości domyślne *)
    "argc" :: List.init n (fun i -> Printf.sprintf "(argc > %d ? argv[%d] : make_null())" i i)
  else
  List.init n (Printf.sprintf "argv[%d]")
  @ (if f.is_variadic then [Printf.sprintf "make_array(argv + %d, argc - %d)" n n] else [])

let wrap_proto (f : function_decl) =
  Printf.sprintf "static FerdekValue %s(void* self, int argc, FerdekValue* argv)" (wrap_c f.name)

let compile_wrapper ctx (f : function_decl) =
  let args, box = match Hashtbl.find_opt ctx.sigs f.name with
    | Some (ps, r) ->
        List.map2 (fun is_i a -> if is_i then Printf.sprintf "to_int(%s)" a else a) ps (wrap_args f),
        (fun c -> if r then Printf.sprintf "make_int(%s)" c else c)
    | None -> wrap_args f, Fun.id in
  String.concat "\n" [wrap_proto f ^ " {";
                      Printf.sprintf "    return %s;" (box (Printf.sprintf "%s(%s)" (fun_c f.name) (String.concat ", " args))); "}"]

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
    Printf.sprintf "    map_put(obj, %s, %s);" (c_string_literal m.name)
      (with_required m (Printf.sprintf "make_method(%s, %s, %d, %s, obj)"
        (method_wrap_c cls m.name) (c_string_literal m.name) (List.length m.params)
        (if m.is_variadic then "true" else "false")))) ms in
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
        (v + 1, ("    " ^ assign ctx name (Printf.sprintf "make_int(%dLL)" v)) :: acc)) (0, []) e.values in
      String.concat "\n" (List.rev lines)
  | Import _ | ImportAs _ -> ""  (* rozwinięte wcześniej przez expand_imports *)
  | ClassDecl _ | StructDecl _ | UnionDecl _ -> ""  (* konstruktory generuje compile_program *)

(* ============ RUNTIME LIBRARY ============ *)

(* Runtime programów C: src/compiler/runtime/*.c sklejone w runtime.c, wbudowane przez regułę w src/compiler/dune *)
let runtime_library = Runtime_source.code

(* Nakładki na graphics_x11.c (Graphics_source) - dołączane tylko do programów z grafiką *)
let graphics_runtime = Runtime_source.graphics

(* ============ PROGRAM ============ *)

(* Import = wklejenie deklaracji modułu w miejscu importu (jak wykonanie w interpreterze).
   Każdy moduł raz - ponowny import niczego nie zmienia. *)
let expand_imports load_module decls =
  let seen = Hashtbl.create 8 in
  let rec expand decls = List.concat_map (function
    | Import name -> load name (fun m -> m)
    | ImportAs (name, alias) -> load ~alias name (Qualify.qualify alias)
    | d -> [d]) decls
  and load ?(alias = "") name transform =
    let key = alias ^ " " ^ name in   (* ten sam moduł pod innym aliasem to osobna kopia *)
    if Hashtbl.mem seen key then [] else begin
      Hashtbl.add seen key ();
      match load_module name with
      | Some m -> expand (transform m).declarations
      | None -> error (Printf.sprintf "Nie ma takiego modułu: %s" name)
    end
  in
  expand decls

let compile_program ?(load_module = fun _ -> None) prog =
  cur_loc := ("", 0);
  let prog = { declarations = expand_imports load_module prog.declarations } in
  let ctx = { funcs = Hashtbl.create 16; globals = Hashtbl.create 64; locals = [];
              in_function = false; loop_handlers = []; counter = 0;
              classes = Hashtbl.create 8; records = Hashtbl.create 8; members = []; lambdas = [];
              ints = []; ret_int = false; sigs = Hashtbl.create 8; int_globals = Hashtbl.create 32;
              int_locals = Hashtbl.create 16; floats = []; float_globals = Hashtbl.create 16;
              float_locals = Hashtbl.create 16; fn_has_try = false; unwind = [] } in
  List.iter (function
    | FunctionDecl f -> Hashtbl.replace ctx.funcs f.name f
    | ClassDecl c -> Hashtbl.replace ctx.classes c.name c
    | StructDecl s -> Hashtbl.replace ctx.records s.name s.fields
    (* Unia: interpreter inicjuje tylko pierwsze pole *)
    | UnionDecl u -> Hashtbl.replace ctx.records u.name (match u.fields with f :: _ -> [f] | [] -> [])
    | EnumDecl e -> List.iter (fun (n, _) -> Hashtbl.replace ctx.globals n ()) e.values
    | Statement s ->
        let decl, assigned = targets_stmt ([], []) s in
        List.iter (fun n -> Hashtbl.replace ctx.globals n ()) (decl @ assigned)
    | _ -> ()) prog.declarations;
  Infer.infer_ints ~globals:ctx.globals ~classes:ctx.classes ~records:ctx.records
    ~is_builtin:(fun n -> find_builtin n <> None) ~sigs:ctx.sigs ~int_globals:ctx.int_globals
    ~int_locals:ctx.int_locals ~float_globals:ctx.float_globals ~float_locals:ctx.float_locals
    prog.declarations;
  ctx.ints <- global_ints ctx;
  ctx.floats <- global_floats ctx;

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
                |> List.map (fun n ->
                     if Hashtbl.mem ctx.int_globals n then Printf.sprintf "static long long %s = 0;" (var_c n)
                     else if Hashtbl.mem ctx.float_globals n then Printf.sprintf "static double %s = 0.0;" (var_c n)
                     else Printf.sprintf "static FerdekValue %s;" (var_c n)) in
  (* Teksty plików do pokazania linii z błędem - jak Source_texts.line w interpreterze *)
  let sources =
    let files = Source_texts.all () in
    List.mapi (fun i (_, lines) ->
      Printf.sprintf "static const char* ferdek_src_%d[] = {%s};" i
        (String.concat ", " (List.map c_string_literal (Array.to_list lines)))) files
    @ ["static const struct { const char* file; int n; const char** lines; } ferdek_sources[] = {";
       String.concat ",\n" (List.mapi (fun i (f, lines) ->
         Printf.sprintf "    {%s, %d, ferdek_src_%d}" (c_string_literal f) (Array.length lines) i) files
         @ ["    {NULL, 0, NULL}"]);
       "};";
       "static const char* source_line(const char* file, int line) {";
       "    for (int i = 0; ferdek_sources[i].file; i++)";
       "        if (strcmp(ferdek_sources[i].file, file) == 0)";
       "            return line >= 1 && line <= ferdek_sources[i].n ? ferdek_sources[i].lines[line - 1] : NULL;";
       "    return NULL;";
       "}"] in
  let protos = Hashtbl.fold (fun _ f acc -> (fun_proto ctx f ^ ";") :: (wrap_proto f ^ ";") :: acc) ctx.funcs [] |> dedup in
  let wrappers = Hashtbl.fold (fun _ f acc -> compile_wrapper ctx f :: acc) ctx.funcs [] |> dedup in

  let program_code = String.concat "\n" (functions @ method_code @ main_body @ constructors) in
  let graphics =
    if Str.string_match (Str.regexp ".*gfx_") (String.map (fun c -> if c = '\n' then ' ' else c) program_code) 0
    then [Graphics_source.code; graphics_runtime] else [] in  (* code ma własne deklaracje - bez nagłówka *)
  String.concat "\n" ([
    runtime_library;
  ] @ graphics @ sources @ globals @ [""] @ protos @ object_protos @ [""] @ List.rev ctx.lambdas @ [""] @ functions @ method_code @ [""] @ wrappers
    @ method_wrappers @ [""] @ constructors @ [
    "";
    "int main(int argc, char** argv) {";
    "#ifdef FERDEK_GC";
    "    GC_INIT();";
    "#endif";
    "    ferdek_argc = argc; ferdek_argv = argv;";
    "    clock_gettime(CLOCK_MONOTONIC, &program_start);";
  ] @ main_body @ [
    "    return 0;";
    "}";
    "";
  ])

let builtin_arities () = List.concat_map (fun (names, (_, arity)) -> List.map (fun n -> (n, arity)) names) builtins
