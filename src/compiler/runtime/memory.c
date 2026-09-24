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
    zone = fx_realloc(zone, sizeof(ZoneBlock) * (zone_count + 1));
    ZoneBlock* b = &zone[zone_count];
    b->size = size;
    b->tag = int_to_tag(tag);
    b->data = fx_malloc(sizeof(FerdekValue) * size);
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
    screens = fx_realloc(screens, sizeof(FerdekScreen) * (screen_count + 1));
    screens[screen_count] = (FerdekScreen){ w, h, fx_calloc(w * h, sizeof(long long)), true };
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
    lookups = fx_realloc(lookups, sizeof(Lookup) * (lookup_count + 1));
    lookups[lookup_count] = (Lookup){ size, fx_calloc(size, sizeof(long long)) };
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

