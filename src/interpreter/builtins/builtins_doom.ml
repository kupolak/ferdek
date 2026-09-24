(* Wbudowane funkcje "jak w DOOM-ie": strefy pamięci, framebuffery, tablice przejść,
   bezpośredni dostęp do pamięci, okno X11 i UDP. Rejestruje je Interpreter przy starcie. *)

open Value
open Eval

(* ============ EXTERNAL BINDINGS FOR GRAPHICS (X11) ============ *)

external ferdek_window_open : int -> int -> string -> int = "caml_ferdek_window_open"
external ferdek_window_close : unit -> unit = "caml_ferdek_window_close"
external ferdek_palette_set : bytes -> unit = "caml_ferdek_palette_set"
external ferdek_pixel_draw : int -> int -> int -> unit = "caml_ferdek_pixel_draw"
external ferdek_screen_refresh : unit -> unit = "caml_ferdek_screen_refresh"
external ferdek_screen_clear : int -> unit = "caml_ferdek_screen_clear"
external ferdek_framebuffer_get : int -> int -> int = "caml_ferdek_framebuffer_get"
external ferdek_event_poll : unit -> (int * int * int * int) = "caml_ferdek_event_poll"

(* ============ ZONE ALLOCATOR (DOOM-style Memory Management) ============ *)

(* Memory tags (like DOOM's PU_* tags) *)
type memory_tag =
  | TAG_TRWALE      (* PU_STATIC = 1 - never freed *)
  | TAG_POZIOM      (* PU_LEVEL = 50 - level data *)
  | TAG_SMIECIOWE   (* PU_CACHE = 100 - can be freed anytime *)

let tag_to_int = function
  | TAG_TRWALE -> 1
  | TAG_POZIOM -> 50
  | TAG_SMIECIOWE -> 100

let int_to_tag n =
  if n <= 1 then TAG_TRWALE
  else if n <= 50 then TAG_POZIOM
  else TAG_SMIECIOWE

(* Memory block structure *)
type memory_block = {
  mutable size: int;
  mutable tag: memory_tag;
  mutable data: value array;
  mutable id: int;
}

(* Global zone allocator state *)
let zone_blocks : (int, memory_block) Hashtbl.t = Hashtbl.create 128
let next_block_id = ref 0
let total_allocated = ref 0
let total_freed = ref 0

(* ============ FRAMEBUFFER & DIRECT MEMORY ACCESS ============ *)

(* Framebuffer structure (like DOOM's screens[]) *)
type framebuffer = {
  mutable width: int;
  mutable height: int;
  mutable pixels: int array;  (* Pixel data - array of color values *)
  mutable id: int;
}

(* Lookup table structure (like DOOM's ylookup[], columnofs[]) *)
type lookup_table = {
  mutable data: int array;
  mutable size: int;
  mutable id: int;
}

(* Global framebuffer and lookup table state *)
let framebuffers : (int, framebuffer) Hashtbl.t = Hashtbl.create 16
let lookup_tables : (int, lookup_table) Hashtbl.t = Hashtbl.create 16
let next_fb_id = ref 0
let next_table_id = ref 0

let register () =
  List.iter (fun (names, arity, impl) ->
    List.iter (fun n -> Vars.replace builtins n (arity, impl)) names) [

  (* ============ MEMORY MANAGEMENT (DOOM-style Zone Allocator) ============ *)
  (* DAJ MI HAJS - Z_Malloc(size, tag) - Allocate memory block *)
  ["DAJ MI HAJS"], Some 2, (fun env args ->
      (match args with
       | [size_arg; tag_arg] ->
           let size = to_int (eval_expr env size_arg) in
           let tag_val = to_int (eval_expr env tag_arg) in
           if size <= 0 then
             raise (RuntimeError "DAJ MI HAJS: rozmiar musi być dodatni")
           else begin
             let tag = int_to_tag tag_val in
             let id = !next_block_id in
             next_block_id := !next_block_id + 1;
             let block = {
               size = size;
               tag = tag;
               data = Array.make size VNull;
               id = id;
             } in
             Hashtbl.add zone_blocks id block;
             total_allocated := !total_allocated + size;
             (* Return pointer to block ID *)
             VPointer (ref (VInt id))
           end
       | _ -> raise (RuntimeError "DAJ MI HAJS oczekuje 2 argumentów (size, tag)")));

  (* ODDAJ_WSZYSTKO - Z_Free(ptr) - Free memory block *)
  ["ODDAJ WSZYSTKO"], Some 1, (fun env args ->
      (match args with
       | [ptr_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       total_freed := !total_freed + block.size;
                       Hashtbl.remove zone_blocks block_id;
                       VNull
                     end else
                       raise (RuntimeError "ODDAJ WSZYSTKO: blok nie istnieje")
                 | _ -> raise (RuntimeError "ODDAJ WSZYSTKO: nieprawidłowy wskaźnik"))
            | _ -> raise (RuntimeError "ODDAJ WSZYSTKO: argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "ODDAJ WSZYSTKO oczekuje 1 argumentu (pointer)")));

  (* KOMORNICZY_WINDYKACJA - Z_FreeTags(lowtag, hightag) - Free blocks by tag range *)
  ["KOMORNICZY WINDYKACJA"], Some 2, (fun env args ->
      (match args with
       | [lowtag_arg; hightag_arg] ->
           let lowtag = to_int (eval_expr env lowtag_arg) in
           let hightag = to_int (eval_expr env hightag_arg) in
           let freed_count = ref 0 in
           let to_remove = ref [] in
           Hashtbl.iter (fun id block ->
             let tag_val = tag_to_int block.tag in
             if tag_val >= lowtag && tag_val <= hightag then begin
               total_freed := !total_freed + block.size;
               to_remove := id :: !to_remove;
               freed_count := !freed_count + 1
             end
           ) zone_blocks;
           List.iter (Hashtbl.remove zone_blocks) !to_remove;
           VInt !freed_count
       | _ -> raise (RuntimeError "KOMORNICZY WINDYKACJA oczekuje 2 argumentów (lowtag, hightag)")));

  (* ZAPISZ_DO_BLOKU - Write to memory block *)
  ["ZAPISZ DO BLOKU"], Some 3, (fun env args ->
      (match args with
       | [ptr_arg; index_arg; value_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           let index = to_int (eval_expr env index_arg) in
           let value = eval_expr env value_arg in
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       if index >= 0 && index < block.size then begin
                         block.data.(index) <- value;
                         VNull
                       end else
                         raise (RuntimeError (Printf.sprintf "ZAPISZ DO BLOKU: indeks %d poza zakresem (rozmiar: %d)" index block.size))
                     end else
                       raise (RuntimeError "ZAPISZ DO BLOKU: blok nie istnieje")
                 | _ -> raise (RuntimeError "ZAPISZ DO BLOKU: nieprawidłowy wskaźnik"))
            | _ -> raise (RuntimeError "ZAPISZ DO BLOKU: pierwszy argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "ZAPISZ DO BLOKU oczekuje 3 argumentów (ptr, index, value)")));

  (* CZYTAJ_Z_BLOKU - Read from memory block *)
  ["CZYTAJ Z BLOKU"], Some 2, (fun env args ->
      (match args with
       | [ptr_arg; index_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           let index = to_int (eval_expr env index_arg) in
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       if index >= 0 && index < block.size then
                         block.data.(index)
                       else
                         raise (RuntimeError (Printf.sprintf "CZYTAJ Z BLOKU: indeks %d poza zakresem (rozmiar: %d)" index block.size))
                     end else
                       raise (RuntimeError "CZYTAJ Z BLOKU: blok nie istnieje")
                 | _ -> raise (RuntimeError "CZYTAJ Z BLOKU: nieprawidłowy wskaźnik"))
            | _ -> raise (RuntimeError "CZYTAJ Z BLOKU: pierwszy argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "CZYTAJ Z BLOKU oczekuje 2 argumentów (ptr, index)")));

  (* ROZMIAR_BLOKU - Get memory block size *)
  ["ROZMIAR BLOKU"], Some 1, (fun env args ->
      (match args with
       | [ptr_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       VInt block.size
                     end else
                       raise (RuntimeError "ROZMIAR BLOKU: blok nie istnieje")
                 | _ -> raise (RuntimeError "ROZMIAR BLOKU: nieprawidłowy wskaźnik"))
            | _ -> raise (RuntimeError "ROZMIAR BLOKU: argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "ROZMIAR BLOKU oczekuje 1 argumentu (pointer)")));

  (* ILE_KASY_LECI - Get memory statistics *)
  ["ILE KASY LECI"], Some 0, (fun env args ->
      (match args with
       | [] ->
           let allocated = !total_allocated in
           let freed = !total_freed in
           let current = allocated - freed in
           let block_count = Hashtbl.length zone_blocks in
           (* Return hash map with stats *)
           let stats = Hashtbl.create 4 in
           Hashtbl.add stats "allocated" (VInt allocated);
           Hashtbl.add stats "freed" (VInt freed);
           Hashtbl.add stats "current" (VInt current);
           Hashtbl.add stats "blocks" (VInt block_count);
           VHashMap stats
       | _ -> raise (RuntimeError "ILE KASY LECI nie przyjmuje argumentów")));

  (* TAG_TRWALE - Memory tag constant (PU_STATIC) *)
  ["TAG_TRWALE"], Some 0, (fun env args ->
      (match args with
       | [] -> VInt 1
       | _ -> raise (RuntimeError "TAG_TRWALE to stała, nie przyjmuje argumentów")));

  (* TAG_POZIOM - Memory tag constant (PU_LEVEL) *)
  ["TAG_POZIOM"], Some 0, (fun env args ->
      (match args with
       | [] -> VInt 50
       | _ -> raise (RuntimeError "TAG_POZIOM to stała, nie przyjmuje argumentów")));

  (* TAG_SMIECIOWE - Memory tag constant (PU_CACHE) *)
  ["TAG_SMIECIOWE"], Some 0, (fun env args ->
      (match args with
       | [] -> VInt 100
       | _ -> raise (RuntimeError "TAG_SMIECIOWE to stała, nie przyjmuje argumentów")));

  (* ============ FRAMEBUFFER FUNCTIONS (TELEWIZOR) ============ *)
  (* WŁĄCZ TELEWIZOR(width, height) - Create framebuffer *)
  ["WŁĄCZ TELEWIZOR"; "WLACZ TELEWIZOR"], Some 2, (fun env args ->
      (match args with
       | [width_arg; height_arg] ->
           let width = to_int (eval_expr env width_arg) in
           let height = to_int (eval_expr env height_arg) in
           if width <= 0 || height <= 0 then
             raise (RuntimeError "WŁĄCZ TELEWIZOR: szerokość i wysokość muszą być dodatnie")
           else begin
             let id = !next_fb_id in
             next_fb_id := !next_fb_id + 1;
             let total_pixels = width * height in
             let fb = {
               width = width;
               height = height;
               pixels = Array.make total_pixels 0;  (* Initialize to black *)
               id = id;
             } in
             Hashtbl.add framebuffers id fb;
             (* Return pointer to framebuffer ID *)
             VPointer (ref (VInt id))
           end
       | _ -> raise (RuntimeError "WŁĄCZ TELEWIZOR oczekuje 2 argumentów (width, height)")));

  (* WYŁĄCZ TELEWIZOR(fb_ptr) - Destroy framebuffer *)
  ["WYŁĄCZ TELEWIZOR"; "WYLACZ TELEWIZOR"], Some 1, (fun env args ->
      (match args with
       | [fb_arg] ->
           let fb_val = eval_expr env fb_arg in
           (match fb_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt fb_id ->
                     if Hashtbl.mem framebuffers fb_id then begin
                       Hashtbl.remove framebuffers fb_id;
                       VNull
                     end else
                       raise (RuntimeError "WYŁĄCZ TELEWIZOR: nieprawidłowy ekran")
                 | _ -> raise (RuntimeError "WYŁĄCZ TELEWIZOR: argument musi być wskaźnikiem na ekran"))
            | _ -> raise (RuntimeError "WYŁĄCZ TELEWIZOR: argument musi być wskaźnikiem na ekran"))
       | _ -> raise (RuntimeError "WYŁĄCZ TELEWIZOR oczekuje 1 argumentu (framebuffer)")));

  (* ZMIEŃ KANAŁ(fb_ptr, x, y, color) - Write pixel to framebuffer *)
  ["ZMIEŃ KANAŁ"; "ZMIEN KANAL"], Some 4, (fun env args ->
      (match args with
       | [fb_arg; x_arg; y_arg; color_arg] ->
           let fb_val = eval_expr env fb_arg in
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           let color = to_int (eval_expr env color_arg) in
           (match fb_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt fb_id ->
                     if Hashtbl.mem framebuffers fb_id then begin
                       let fb = Hashtbl.find framebuffers fb_id in
                       if x < 0 || x >= fb.width || y < 0 || y >= fb.height then
                         raise (RuntimeError "ZMIEŃ KANAŁ: piksel poza ekranem")
                       else begin
                         let offset = y * fb.width + x in
                         fb.pixels.(offset) <- color;
                         VNull
                       end
                     end else
                       raise (RuntimeError "ZMIEŃ KANAŁ: nieprawidłowy ekran")
                 | _ -> raise (RuntimeError "ZMIEŃ KANAŁ: pierwszy argument musi być wskaźnikiem na ekran"))
            | _ -> raise (RuntimeError "ZMIEŃ KANAŁ: pierwszy argument musi być wskaźnikiem na ekran"))
       | _ -> raise (RuntimeError "ZMIEŃ KANAŁ oczekuje 4 argumentów (framebuffer, x, y, color)")));

  (* CO LECI W TELEWIZORZE(fb_ptr, x, y) - Read pixel from framebuffer *)
  ["CO LECI W TELEWIZORZE"], Some 3, (fun env args ->
      (match args with
       | [fb_arg; x_arg; y_arg] ->
           let fb_val = eval_expr env fb_arg in
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           (match fb_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt fb_id ->
                     if Hashtbl.mem framebuffers fb_id then begin
                       let fb = Hashtbl.find framebuffers fb_id in
                       if x < 0 || x >= fb.width || y < 0 || y >= fb.height then
                         raise (RuntimeError "CO LECI W TELEWIZORZE: piksel poza ekranem")
                       else begin
                         let offset = y * fb.width + x in
                         VInt fb.pixels.(offset)
                       end
                     end else
                       raise (RuntimeError "CO LECI W TELEWIZORZE: nieprawidłowy ekran")
                 | _ -> raise (RuntimeError "CO LECI W TELEWIZORZE: pierwszy argument musi być wskaźnikiem na ekran"))
            | _ -> raise (RuntimeError "CO LECI W TELEWIZORZE: pierwszy argument musi być wskaźnikiem na ekran"))
       | _ -> raise (RuntimeError "CO LECI W TELEWIZORZE oczekuje 3 argumentów (framebuffer, x, y)")));

  (* ============ LOOKUP TABLE FUNCTIONS ============ *)
  (* STWÓRZ TABELĘ(size) - Create lookup table *)
  ["STWÓRZ TABELĘ"; "STWORZ TABELE"], Some 1, (fun env args ->
      (match args with
       | [size_arg] ->
           let size = to_int (eval_expr env size_arg) in
           if size <= 0 then
             raise (RuntimeError "STWÓRZ TABELĘ: rozmiar musi być dodatni")
           else begin
             let id = !next_table_id in
             next_table_id := !next_table_id + 1;
             let table = {
               data = Array.make size 0;
               size = size;
               id = id;
             } in
             Hashtbl.add lookup_tables id table;
             VPointer (ref (VInt id))
           end
       | _ -> raise (RuntimeError "STWÓRZ TABELĘ oczekuje 1 argumentu (size)")));

  (* WPISZ DO TABELI(table_ptr, index, value) - Write to lookup table *)
  ["WPISZ DO TABELI"], Some 3, (fun env args ->
      (match args with
       | [table_arg; index_arg; value_arg] ->
           let table_val = eval_expr env table_arg in
           let index = to_int (eval_expr env index_arg) in
           let value = to_int (eval_expr env value_arg) in
           (match table_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt table_id ->
                     if Hashtbl.mem lookup_tables table_id then begin
                       let table = Hashtbl.find lookup_tables table_id in
                       if index < 0 || index >= table.size then
                         raise (RuntimeError "WPISZ DO TABELI: indeks poza zakresem")
                       else begin
                         table.data.(index) <- value;
                         VNull
                       end
                     end else
                       raise (RuntimeError "WPISZ DO TABELI: nieprawidłowa tabela")
                 | _ -> raise (RuntimeError "WPISZ DO TABELI: pierwszy argument musi być wskaźnikiem na tabelę"))
            | _ -> raise (RuntimeError "WPISZ DO TABELI: pierwszy argument musi być wskaźnikiem na tabelę"))
       | _ -> raise (RuntimeError "WPISZ DO TABELI oczekuje 3 argumentów (table, index, value)")));

  (* SPRAWDŹ W TABELI(table_ptr, index) - Read from lookup table *)
  ["SPRAWDŹ W TABELI"; "SPRAWDZ W TABELI"], Some 2, (fun env args ->
      (match args with
       | [table_arg; index_arg] ->
           let table_val = eval_expr env table_arg in
           let index = to_int (eval_expr env index_arg) in
           (match table_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt table_id ->
                     if Hashtbl.mem lookup_tables table_id then begin
                       let table = Hashtbl.find lookup_tables table_id in
                       if index < 0 || index >= table.size then
                         raise (RuntimeError "SPRAWDŹ W TABELI: indeks poza zakresem")
                       else
                         VInt table.data.(index)
                     end else
                       raise (RuntimeError "SPRAWDŹ W TABELI: nieprawidłowa tabela")
                 | _ -> raise (RuntimeError "SPRAWDŹ W TABELI: pierwszy argument musi być wskaźnikiem na tabelę"))
            | _ -> raise (RuntimeError "SPRAWDŹ W TABELI: pierwszy argument musi być wskaźnikiem na tabelę"))
       | _ -> raise (RuntimeError "SPRAWDŹ W TABELI oczekuje 2 argumentów (table, index)")));

  (* ============ DIRECT MEMORY ACCESS ============ *)
  (* PISZ BAJT(ptr, offset, value) - Write byte directly to memory block *)
  ["PISZ BAJT"], Some 3, (fun env args ->
      (match args with
       | [ptr_arg; offset_arg; value_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           let offset = to_int (eval_expr env offset_arg) in
           let value = to_int (eval_expr env value_arg) in
           (* Same as ZAPISZ DO BLOKU but emphasizes byte-level access *)
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       if offset < 0 || offset >= block.size then
                         raise (RuntimeError "PISZ BAJT: przesunięcie poza zakresem")
                       else begin
                         block.data.(offset) <- VInt value;
                         VNull
                       end
                     end else
                       raise (RuntimeError "PISZ BAJT: nieprawidłowy blok pamięci")
                 | _ -> raise (RuntimeError "PISZ BAJT: pierwszy argument musi być wskaźnikiem"))
            | _ -> raise (RuntimeError "PISZ BAJT: pierwszy argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "PISZ BAJT oczekuje 3 argumentów (ptr, offset, value)")));

  (* CZYTAJ BAJT(ptr, offset) - Read byte directly from memory block *)
  ["CZYTAJ BAJT"], Some 2, (fun env args ->
      (match args with
       | [ptr_arg; offset_arg] ->
           let ptr_val = eval_expr env ptr_arg in
           let offset = to_int (eval_expr env offset_arg) in
           (* Same as CZYTAJ Z BLOKU but emphasizes byte-level access *)
           (match ptr_val with
            | VPointer ptr ->
                (match !ptr with
                 | VInt block_id ->
                     if Hashtbl.mem zone_blocks block_id then begin
                       let block = Hashtbl.find zone_blocks block_id in
                       if offset < 0 || offset >= block.size then
                         raise (RuntimeError "CZYTAJ BAJT: przesunięcie poza zakresem")
                       else
                         block.data.(offset)
                     end else
                       raise (RuntimeError "CZYTAJ BAJT: nieprawidłowy blok pamięci")
                 | _ -> raise (RuntimeError "CZYTAJ BAJT: pierwszy argument musi być wskaźnikiem"))
            | _ -> raise (RuntimeError "CZYTAJ BAJT: pierwszy argument musi być wskaźnikiem"))
       | _ -> raise (RuntimeError "CZYTAJ BAJT oczekuje 2 argumentów (ptr, offset)")));

  (* KOPIUJ PAMIĘĆ(src_ptr, dst_ptr, size) - Memory copy (like memcpy) *)
  ["KOPIUJ PAMIĘĆ"; "KOPIUJ PAMIEC"], Some 3, (fun env args ->
      (match args with
       | [src_arg; dst_arg; size_arg] ->
           let src_val = eval_expr env src_arg in
           let dst_val = eval_expr env dst_arg in
           let size = to_int (eval_expr env size_arg) in
           (match src_val, dst_val with
            | VPointer src_ptr, VPointer dst_ptr ->
                (match !src_ptr, !dst_ptr with
                 | VInt src_id, VInt dst_id ->
                     if Hashtbl.mem zone_blocks src_id && Hashtbl.mem zone_blocks dst_id then begin
                       let src_block = Hashtbl.find zone_blocks src_id in
                       let dst_block = Hashtbl.find zone_blocks dst_id in
                       if size > src_block.size || size > dst_block.size then
                         raise (RuntimeError "KOPIUJ PAMIĘĆ: rozmiar większy niż blok")
                       else begin
                         Array.blit src_block.data 0 dst_block.data 0 size;
                         VNull
                       end
                     end else
                       raise (RuntimeError "KOPIUJ PAMIĘĆ: nieprawidłowe bloki pamięci")
                 | _ -> raise (RuntimeError "KOPIUJ PAMIĘĆ: argumenty muszą być wskaźnikami"))
            | _ -> raise (RuntimeError "KOPIUJ PAMIĘĆ: argumenty muszą być wskaźnikami"))
       | _ -> raise (RuntimeError "KOPIUJ PAMIĘĆ oczekuje 3 argumentów (src, dst, size)")));


  (* ============ GRAPHICS (X11 - DOOM style) ============ *)
  (* OKNO_OTWORZ(width, height, title) - Initialize graphics window *)
  ["OKNO_OTWORZ"; "OKNO OTWORZ"], Some 3, (fun env args ->
      (match args with
       | [width_arg; height_arg; title_arg] ->
           let width = to_int (eval_expr env width_arg) in
           let height = to_int (eval_expr env height_arg) in
           let title = to_string (eval_expr env title_arg) in
           let result = ferdek_window_open width height title in
           if result = 0 then
             raise (RuntimeError "OKNO_OTWORZ: nie udało się otworzyć okna")
           else
             VInt result
       | _ -> raise (RuntimeError "OKNO_OTWORZ oczekuje 3 argumentów (width, height, title)")));

  (* OKNO_ZAMKNIJ() - Close graphics window *)
  ["OKNO_ZAMKNIJ"; "OKNO ZAMKNIJ"], Some 0, (fun env args ->
      (match args with
       | [] ->
           ferdek_window_close ();
           VNull
       | _ -> raise (RuntimeError "OKNO_ZAMKNIJ oczekuje 0 argumentów")));

  (* PALETA_USTAW(palette_array) - Set 256-color palette *)
  ["PALETA_USTAW"; "PALETA USTAW"], Some 1, (fun env args ->
      (match args with
       | [palette_arg] ->
           let palette_val = eval_expr env palette_arg in
           (match palette_val with
            | VArray arr ->
                (* Palette should be 768 bytes (256 colors * 3 RGB) *)
                if Array.length arr <> 768 then
                  raise (RuntimeError "PALETA_USTAW: paleta musi mieć 768 bajtów (256 kolorów * RGB)")
                else begin
                  (* Convert array of VByte to bytes *)
                  let palette_bytes = Bytes.create 768 in
                  Array.iteri (fun i v ->
                    let byte_val = to_int v land 0xFF in
                    Bytes.set palette_bytes i (Char.chr byte_val)
                  ) arr;
                  ferdek_palette_set palette_bytes;
                  VNull
                end
            | _ -> raise (RuntimeError "PALETA_USTAW: argument musi być tablicą"))
       | _ -> raise (RuntimeError "PALETA_USTAW oczekuje 1 argumentu (palette_array)")));

  (* PIKSEL_MALUJ(x, y, color) - Draw pixel *)
  ["PIKSEL_MALUJ"; "PIKSEL MALUJ"], Some 3, (fun env args ->
      (match args with
       | [x_arg; y_arg; color_arg] ->
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           let color = to_int (eval_expr env color_arg) land 0xFF in
           ferdek_pixel_draw x y color;
           VNull
       | _ -> raise (RuntimeError "PIKSEL_MALUJ oczekuje 3 argumentów (x, y, color)")));

  (* EKRAN_ODŚWIEŻ() - Refresh screen (blit framebuffer) *)
  ["EKRAN_ODŚWIEŹ"; "EKRAN_ODŚWIEŻ"; "EKRAN ODŚWIEŹ"; "EKRAN ODŚWIEŻ"; "EKRAN_ODSWIEZ"; "EKRAN ODSWIEZ"], Some 0, (fun env args ->
      (match args with
       | [] ->
           ferdek_screen_refresh ();
           VNull
       | _ -> raise (RuntimeError "EKRAN_ODŚWIEŻ oczekuje 0 argumentów")));

  (* EKRAN_CZYŚĆ(color) - Clear screen to color *)
  ["EKRAN_CZYŚĆ"; "EKRAN CZYŚĆ"; "EKRAN_CZYSĆ"; "EKRAN CZYSĆ"; "EKRAN_CZYSC"; "EKRAN CZYSC"], Some 1, (fun env args ->
      (match args with
       | [color_arg] ->
           let color = to_int (eval_expr env color_arg) land 0xFF in
           ferdek_screen_clear color;
           VNull
       | _ -> raise (RuntimeError "EKRAN_CZYŚĆ oczekuje 1 argumentu (color)")));

  (* BUFOR_RAMKI_POBIERZ(x, y) - Get pixel from framebuffer *)
  ["BUFOR_RAMKI_POBIERZ"; "BUFOR RAMKI POBIERZ"], Some 2, (fun env args ->
      (match args with
       | [x_arg; y_arg] ->
           let x = to_int (eval_expr env x_arg) in
           let y = to_int (eval_expr env y_arg) in
           let pixel = ferdek_framebuffer_get x y in
           VInt pixel
       | _ -> raise (RuntimeError "BUFOR_RAMKI_POBIERZ oczekuje 2 argumentów (x, y)")));

  (* ZDARZENIE_CZEKAJ() - Poll for event (non-blocking) *)
  ["ZDARZENIE_CZEKAJ"; "ZDARZENIE CZEKAJ"], Some 0, (fun env args ->
      (match args with
       | [] ->
           let (ev_type, key, x, y) = ferdek_event_poll () in
           (* Return array [type, key, x, y] *)
           VArray [| VInt ev_type; VInt key; VInt x; VInt y |]
       | _ -> raise (RuntimeError "ZDARZENIE_CZEKAJ oczekuje 0 argumentów")));

  (* ============ NETWORKING (UDP - DOOM multiplayer style) ============ *)
  (* GNIAZDKO_OTWORZ(port) - Create UDP socket and bind to port *)
  ["GNIAZDKO_OTWORZ"; "GNIAZDKO OTWORZ"], Some 1, (fun env args ->
      (match args with
       | [port_arg] ->
           let port = to_int (eval_expr env port_arg) in
           (try
              let sockfd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
              (* Set non-blocking *)
              Unix.set_nonblock sockfd;
              (* Allow address reuse *)
              Unix.setsockopt sockfd Unix.SO_REUSEADDR true;
              (* Bind to port *)
              let addr = Unix.ADDR_INET (Unix.inet_addr_any, port) in
              Unix.bind sockfd addr;
              Printf.printf "Gniazdko UDP otwarte na porcie %d\n%!" port;
              VInt (Obj.magic sockfd : int)  (* Convert Unix.file_descr to int *)
            with Unix.Unix_error (err, fn, _) ->
              raise (RuntimeError (Printf.sprintf "GNIAZDKO_OTWORZ: %s: %s" fn (Unix.error_message err))))
       | _ -> raise (RuntimeError "GNIAZDKO_OTWORZ oczekuje 1 argumentu (port)")));

  (* GNIAZDKO_WYSLIJ(sockfd, host, port, data) - Send UDP packet *)
  ["GNIAZDKO_WYSLIJ"; "GNIAZDKO WYSLIJ"], Some 4, (fun env args ->
      (match args with
       | [sockfd_arg; host_arg; port_arg; data_arg] ->
           let sockfd = (Obj.magic (to_int (eval_expr env sockfd_arg)) : Unix.file_descr) in
           let host = to_string (eval_expr env host_arg) in
           let port = to_int (eval_expr env port_arg) in
           let data_val = eval_expr env data_arg in
           (match data_val with
            | VString s ->
                (try
                   let addr = Unix.ADDR_INET (Unix.inet_addr_of_string host, port) in
                   let sent = Unix.sendto sockfd (Bytes.of_string s) 0 (String.length s) [] addr in
                   VInt sent
                 with Unix.Unix_error (err, fn, _) ->
                   raise (RuntimeError (Printf.sprintf "GNIAZDKO_WYSLIJ: %s: %s" fn (Unix.error_message err))))
            | VArray arr ->
                (* Convert byte array to string *)
                let bytes = Bytes.create (Array.length arr) in
                Array.iteri (fun i v ->
                  let byte_val = to_int v land 0xFF in
                  Bytes.set bytes i (Char.chr byte_val)
                ) arr;
                (try
                   let addr = Unix.ADDR_INET (Unix.inet_addr_of_string host, port) in
                   let sent = Unix.sendto sockfd bytes 0 (Bytes.length bytes) [] addr in
                   VInt sent
                 with Unix.Unix_error (err, fn, _) ->
                   raise (RuntimeError (Printf.sprintf "GNIAZDKO_WYSLIJ: %s: %s" fn (Unix.error_message err))))
            | _ -> raise (RuntimeError "GNIAZDKO_WYSLIJ: dane muszą być tekstem albo tablicą bajtów"))
       | _ -> raise (RuntimeError "GNIAZDKO_WYSLIJ oczekuje 4 argumentów (sockfd, host, port, data)")));

  (* GNIAZDKO_ODBIERZ(sockfd, bufsize) - Receive UDP packet (non-blocking) *)
  ["GNIAZDKO_ODBIERZ"; "GNIAZDKO ODBIERZ"], Some 2, (fun env args ->
      (match args with
       | [sockfd_arg; bufsize_arg] ->
           let sockfd = (Obj.magic (to_int (eval_expr env sockfd_arg)) : Unix.file_descr) in
           let bufsize = to_int (eval_expr env bufsize_arg) in
           let buffer = Bytes.create bufsize in
           (try
              let (received, from_addr) = Unix.recvfrom sockfd buffer 0 bufsize [] in
              if received = 0 then
                VInt 0  (* No data *)
              else begin
                (* Extract sender info *)
                let (host, port) = match from_addr with
                  | Unix.ADDR_INET (addr, p) -> (Unix.string_of_inet_addr addr, p)
                  | _ -> ("unknown", 0)
                in
                (* Return tuple [data, host, port] *)
                let data_str = Bytes.sub_string buffer 0 received in
                VArray [| VString data_str; VString host; VInt port |]
              end
            with
            | Unix.Unix_error (Unix.EAGAIN, _, _)
            | Unix.Unix_error (Unix.EWOULDBLOCK, _, _) ->
                VInt 0  (* No data available *)
            | Unix.Unix_error (err, fn, _) ->
                raise (RuntimeError (Printf.sprintf "GNIAZDKO_ODBIERZ: %s: %s" fn (Unix.error_message err))))
       | _ -> raise (RuntimeError "GNIAZDKO_ODBIERZ oczekuje 2 argumentów (sockfd, bufsize)")));

  (* GNIAZDKO_ZAMKNIJ(sockfd) - Close UDP socket *)
  ["GNIAZDKO_ZAMKNIJ"; "GNIAZDKO ZAMKNIJ"], Some 1, (fun env args ->
      (match args with
       | [sockfd_arg] ->
           let sockfd = (Obj.magic (to_int (eval_expr env sockfd_arg)) : Unix.file_descr) in
           (try
              Unix.close sockfd;
              Printf.printf "Gniazdko UDP zamknięte\n%!";
              VNull
            with Unix.Unix_error (err, fn, _) ->
              raise (RuntimeError (Printf.sprintf "GNIAZDKO_ZAMKNIJ: %s: %s" fn (Unix.error_message err))))
       | _ -> raise (RuntimeError "GNIAZDKO_ZAMKNIJ oczekuje 1 argumentu (sockfd)")));

  ]
