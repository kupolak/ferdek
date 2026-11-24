/* ---- Obiekty (pola w FerdekMap) i wskaźniki ---- */

static void map_put(FerdekMap* m, const char* key, FerdekValue v) {
    int i = map_find(m, key);
    if (i >= 0) { m->vals[i] = v; return; }
    map_append(m, fx_strdup(key), v);
}

static FerdekValue make_object(void) {
    FerdekValue v;
    v.type = TYPE_OBJECT;
    v.value.map_val = fx_calloc(1, sizeof(FerdekMap));
    return v;
}

static FerdekValue make_def(const FerdekDef* d) {
    FerdekValue v;
    v.type = TYPE_DEF;
    v.value.def_val = d;
    return v;
}

/* DZIAD ZDZIADZIAŁY JEDEN k, gdy k to zmienna: musi w niej leżeć typ właściwego rodzaju (c/s/u) */
static FerdekValue new_from(FerdekValue v, char kind, const char* err) {
    if (v.type != TYPE_DEF || v.value.def_val->kind[0] != kind) ferdek_die("%s", err);
    return v.value.def_val->make();
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
    if (key.type == TYPE_INT) { snprintf(num, sizeof num, "%lld", key.value.int_val); return fx_strdup(num); }
    ferdek_die("Nazwa pola obiektu musi być tekstem, a jest: %s", to_str(key));
    return NULL;
}

static FerdekValue text_char(const char* text, long long i);   /* builtins.c */

/* t[i] (t[-1] to ostatni element), tekst[i], s["klucz"] i obj["pole"] - jak ArrayAccess w interpreterze */
static FerdekValue index_get(FerdekValue c, FerdekValue key) {
    if (c.type == TYPE_STRING) return text_char(c.value.string_val, to_int(key));
    if (c.type == TYPE_ARRAY) {
        long long i = to_int(key);
        if (i < 0) i += c.value.array_val->length;
        if (i < 0 || i >= c.value.array_val->length) ferdek_die("Indeks tablicy poza zakresem");
        return c.value.array_val->data[i];
    }
    if (c.type == TYPE_MAP) {   /* jak WYJMIJ Z SZAFKI: null, gdy klucza nie ma */
        char num[32], *owned;
        int i = map_find(c.value.map_val, str_view(key, num, sizeof num, &owned));
        fx_free(owned);
        return i >= 0 ? c.value.map_val->vals[i] : make_null();
    }
    if (c.type == TYPE_OBJECT) {
        char* k = field_key(key);
        int i = map_find(c.value.map_val, k);
        if (i < 0) ferdek_die("Obiekt nie ma pola: %s", k);
        return c.value.map_val->vals[i];
    }
    ferdek_die("To nie jest tablica, szafka, tekst ani obiekt");
    return make_null();
}

/* t[i] = v i obj["pole"] = v - jak ArrayAssign w interpreterze (indeks tablicy tylko DŁUGI) */
static void index_set(FerdekValue c, FerdekValue key, FerdekValue v) {
    if (c.type == TYPE_ARRAY && key.type == TYPE_INT) {
        long long i = key.value.int_val, j = i < 0 ? i + c.value.array_val->length : i;
        if (j < 0 || j >= c.value.array_val->length) ferdek_die("Indeks poza zakresem: %lld", i);
        c.value.array_val->data[j] = v;
    } else if (c.type == TYPE_MAP) {   /* jak WŁÓŻ DO SZAFKI */
        char num[32], *owned;
        map_put(c.value.map_val, str_view(key, num, sizeof num, &owned), v);
        fx_free(owned);
    } else if (c.type == TYPE_STRING) {
        ferdek_die("Tekstu nie da się zmienić w miejscu - tekst[i] jest tylko do odczytu");
    } else if (c.type == TYPE_OBJECT && (key.type == TYPE_STRING || key.type == TYPE_INT)) {
        map_put(c.value.map_val, field_key(key), v);
    } else if (key.type == TYPE_INT) {
        ferdek_die("To nie jest tablica, szafka ani obiekt");
    } else {
        ferdek_die("Indeks tablicy musi być liczbą całkowitą");
    }
}

/* t[i] z indeksem, o którym kompilator wie, że jest liczbą całkowitą - bez pakowania indeksu */
static inline FerdekValue index_get_i(FerdekValue c, long long i) {
    if (c.type == TYPE_ARRAY) {
        if (i < 0) i += c.value.array_val->length;
        if (i < 0 || i >= c.value.array_val->length) ferdek_die("Indeks tablicy poza zakresem");
        return c.value.array_val->data[i];
    }
    return index_get(c, make_int(i));
}
static inline void index_set_i(FerdekValue c, long long i, FerdekValue v) {
    if (c.type == TYPE_ARRAY) {
        long long j = i < 0 ? i + c.value.array_val->length : i;
        if (j < 0 || j >= c.value.array_val->length) ferdek_die("Indeks poza zakresem: %lld", i);
        c.value.array_val->data[j] = v;
        return;
    }
    index_set(c, make_int(i), v);
}

static FerdekValue make_pointer(FerdekValue target) {
    FerdekValue v;
    v.type = TYPE_POINTER;
    v.value.ptr_val = fx_malloc(sizeof(FerdekValue));
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
    if (a.type == TYPE_INT && b.type == TYPE_INT)
        return make_int(dir > 0 ? iadd(a.value.int_val, b.value.int_val) : isub(a.value.int_val, b.value.int_val));
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

static void ferdek_throw(FerdekValue v) {
    if (ferdek_handler == NULL) {
        char* s = to_str(v);
        fflush(stdout);
        fprintf(stderr, "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: Nikt nie złapał wyjątku: %s", s);
        print_loc();
        fprintf(stderr, "\n");
        print_context();
        exit(1);
    }
    ferdek_exception = v;
    ferdek_exception_error = false;
    longjmp(ferdek_handler->buf, 1);
}

/* Typy: TO JE LICZBA SYNEK itd. - te same słowa co check_type w interpreterze */
static const char* type_phrase(int t) {
    switch (t) {
        case TYPE_INT: return "TO JE LICZBA SYNEK";
        case TYPE_FLOAT: return "TO JE LICZBA Z PRZECINKIEM";
        case TYPE_STRING: return "TO SĄ STRINGI";
        case TYPE_BOOL: return "TO JE TAK ALBO NIE";
        case TYPE_ARRAY: return "TO JE WERSALKA";
        case TYPE_MAP: return "TO JE SZAFKA";
        default: return "TO JE FUNKCJA";
    }
}
static const char* value_kind(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: return "liczba całkowita";
        case TYPE_FLOAT: return "liczba z przecinkiem";
        case TYPE_STRING: return "tekst";
        case TYPE_BOOL: return "prawda/fałsz";
        case TYPE_NULL: return "nic";
        case TYPE_ARRAY: return "tablica";
        case TYPE_MAP: return "szafka";
        case TYPE_FUNCTION: return "funkcja";
        case TYPE_BYTE: return "bajcik";
        case TYPE_SHORT: return "krótki";
        case TYPE_FIXED: return "ułamek";
        case TYPE_OBJECT: return "obiekt";
        case TYPE_POINTER: return "wskaźnik";
        case TYPE_DEF: return "definicja typu";
        default: return "kibel (plik)";
    }
}
static FerdekValue check_type(FerdekValue v, int t, const char* what) {
    if ((int)v.type != t) ferdek_die("%s: %s, a jest %s", what, type_phrase(t), value_kind(v));
    return v;
}

/* Po sprzątaniu (I TAK TRZEBA POSPRZĄTAĆ) ten sam błąd albo wyjątek leci dalej */
static void ferdek_rethrow(bool is_error, FerdekValue v) {
    if (is_error) ferdek_die("%s", v.value.string_val);
    ferdek_throw(v);
}

