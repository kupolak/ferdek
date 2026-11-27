/* ---- Biblioteka 2.0 - te same zasady i komunikaty co w interpreterze ---- */

static bool same_element(FerdekValue a, FerdekValue x) {   /* jak CZY LEŻY NA WERSALCE */
    if (a.type != x.type) return false;
    return (a.type == TYPE_INT && a.value.int_val == x.value.int_val) ||
           (a.type == TYPE_STRING && strcmp(a.value.string_val, x.value.string_val) == 0) ||
           (a.type == TYPE_BOOL && a.value.bool_val == x.value.bool_val);
}

static FerdekValue b_wytnij(int argc, FerdekValue* argv) {
    FerdekArray* a = list_arg(argv[0], "WYTNIJ Z WERSALKI: pierwszy argument musi być tablicą");
    long long od = to_int(argv[1]), d = to_int(argv[2]);
    if (od < 0 || d < od || d > a->length)
        ferdek_die("WYTNIJ Z WERSALKI: zły zakres %lld..%lld (tablica ma %d)", od, d, a->length);
    return make_array(a->data + od, (int)(d - od));
}

static FerdekValue b_gdzie_lezy(int argc, FerdekValue* argv) {
    FerdekArray* a = list_arg(argv[0], "GDZIE LEŻY NA WERSALCE: pierwszy argument musi być tablicą");
    for (int i = 0; i < a->length; i++) if (same_element(a->data[i], argv[1])) return make_int(i);
    return make_int(-1);
}

static FerdekValue b_zestaw(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_ARRAY || argv[1].type != TYPE_ARRAY) ferdek_die("ZESTAW WERSALKI: oba argumenty muszą być tablicami");
    FerdekArray *a = argv[0].value.array_val, *b = argv[1].value.array_val;
    FerdekValue out = make_array(NULL, 0);
    out.value.array_val->data = fx_malloc(sizeof(FerdekValue) * (a->length + b->length + 1));
    memcpy(out.value.array_val->data, a->data, sizeof(FerdekValue) * a->length);
    memcpy(out.value.array_val->data + a->length, b->data, sizeof(FerdekValue) * b->length);
    out.value.array_val->length = a->length + b->length;
    return out;
}

static FerdekValue b_zsumuj(int argc, FerdekValue* argv) {
    FerdekArray* a = list_arg(argv[0], "ZSUMUJ WERSALKĘ: argument musi być tablicą");
    if (a->length == 0) return make_int(0);
    FerdekValue acc = a->data[0];
    for (int i = 1; i < a->length; i++) acc = op_add(acc, a->data[i]);
    return acc;
}

static FerdekValue b_najmniejszy(int argc, FerdekValue* argv) {
    FerdekArray* a = list_arg(argv[0], "NAJMNIEJSZY NA WERSALCE: argument musi być tablicą");
    if (a->length == 0) ferdek_die("NAJMNIEJSZY NA WERSALCE: pusta tablica");
    FerdekValue best = a->data[0];
    for (int i = 0; i < a->length; i++) if (compare3(a->data[i], best, false) < 0) best = a->data[i];
    return best;
}

static FerdekValue b_najwiekszy(int argc, FerdekValue* argv) {
    FerdekArray* a = list_arg(argv[0], "NAJWIĘKSZY NA WERSALCE: argument musi być tablicą");
    if (a->length == 0) ferdek_die("NAJWIĘKSZY NA WERSALCE: pusta tablica");
    FerdekValue best = a->data[0];
    for (int i = 0; i < a->length; i++) if (compare3(a->data[i], best, false) > 0) best = a->data[i];
    return best;
}

static FerdekValue b_zwin(int argc, FerdekValue* argv) {
    FerdekArray* a = list_arg(argv[0], "ZWIŃ WERSALKĘ: pierwszy argument musi być tablicą");
    if (argv[2].type != TYPE_FUNCTION) ferdek_die("ZWIŃ WERSALKĘ: trzeci argument musi być funkcją");
    FerdekValue acc = argv[1];
    for (int i = 0; i < a->length; i++) {
        FerdekValue args[2] = { acc, a->data[i] };
        acc = call_value(argv[2], argv[2].value.fn_val.name, 2, args);
    }
    return acc;
}

static FerdekValue b_bez_powtorek(int argc, FerdekValue* argv) {
    FerdekArray* a = list_arg(argv[0], "BEZ POWTÓREK: argument musi być tablicą");
    FerdekValue out = make_array(NULL, 0);
    FerdekArray* o = out.value.array_val;
    o->data = fx_malloc(sizeof(FerdekValue) * (a->length + 1));
    for (int i = 0; i < a->length; i++) {
        bool seen = false;
        for (int j = 0; j < o->length && !seen; j++) seen = same_element(a->data[i], o->data[j]);
        if (!seen) o->data[o->length++] = a->data[i];
    }
    return out;
}

static FerdekValue b_kolejka(int argc, FerdekValue* argv) {
    long long od = to_int(argv[0]), d = to_int(argv[1]);
    if (d >= od && d - od >= 10000000) ferdek_die("ZRÓB KOLEJKĘ: za długa (najwyżej 10000000 liczb)");
    if (d < od) return make_array(NULL, 0);
    FerdekValue out = make_array(NULL, 0);
    out.value.array_val->data = fx_malloc(sizeof(FerdekValue) * (d - od + 1));
    for (long long i = 0; i <= d - od; i++) out.value.array_val->data[i] = make_int(od + i);
    out.value.array_val->length = (int)(d - od + 1);
    return out;
}

static long long rng_next(void) {   /* jak rng_next w interpreterze */
    if (ferdek_rng < 0) ferdek_rng = ((long long)time(NULL) * 1000 + clock()) & 0x7FFFFFFF;
    ferdek_rng = (ferdek_rng * 1103515245 + 12345) & 0x7FFFFFFF;
    return ferdek_rng;
}

static FerdekValue b_wylosuj(int argc, FerdekValue* argv) {
    FerdekArray* a = list_arg(argv[0], "WYLOSUJ Z WERSALKI: argument musi być tablicą");
    if (a->length == 0) ferdek_die("WYLOSUJ Z WERSALKI: pusta tablica");
    return a->data[rng_next() % a->length];
}

static FerdekValue b_powtorz(int argc, FerdekValue* argv) {
    long long n = to_int(argv[1]);
    if (n < 0) ferdek_die("POWTÓRZ NA KANAPIE: ujemna liczba powtórzeń");
    char* t = to_str(argv[0]);
    size_t len = strlen(t);
    if ((double)len * n > 100000000.0) ferdek_die("POWTÓRZ NA KANAPIE: za długi tekst");
    char* s = fx_malloc(len * n + 1);
    for (long long i = 0; i < n; i++) memcpy(s + i * len, t, len);
    s[len * n] = '\0';
    fx_free(t);
    return own_string(s);
}

/* Pozycja fragmentu w znakach albo -1 - jak kanapa_gdzie */
static long long kanapa_gdzie(FerdekValue tv, FerdekValue fv) {
    char* t = to_str(tv); char* f = to_str(fv);
    char* hit = strstr(t, f);
    long long r = -1;
    if (hit) { *hit = '\0'; r = utf8_index(t, NULL); }
    fx_free(t); fx_free(f);
    return r;
}
static FerdekValue b_czy_siedzi(int argc, FerdekValue* argv) { return make_bool(kanapa_gdzie(argv[0], argv[1]) >= 0); }
static FerdekValue b_gdzie_siedzi(int argc, FerdekValue* argv) { return make_int(kanapa_gdzie(argv[0], argv[1])); }

static FerdekValue b_zaczyna(int argc, FerdekValue* argv) {
    char* t = to_str(argv[0]); char* p = to_str(argv[1]);
    bool r = strncmp(t, p, strlen(p)) == 0;
    fx_free(t); fx_free(p);
    return make_bool(r);
}
static FerdekValue b_konczy(int argc, FerdekValue* argv) {
    char* t = to_str(argv[0]); char* k = to_str(argv[1]);
    size_t lt = strlen(t), lk = strlen(k);
    bool r = lk <= lt && strcmp(t + lt - lk, k) == 0;
    fx_free(t); fx_free(k);
    return make_bool(r);
}

/* Bajty <-> tekst; tekst kończy się na pierwszym bajcie 0 (jak w interpreterze) */
static FerdekValue b_kanapa_z_bajtow(int argc, FerdekValue* argv) {
    FerdekArray* a = list_arg(argv[0], "KANAPA Z BAJTÓW: argument musi być tablicą");
    char* s = fx_malloc(a->length + 1);
    int w = 0;
    for (int i = 0; i < a->length; i++) {
        long long n = to_int(a->data[i]);
        if (n < 0 || n > 255) ferdek_die("KANAPA Z BAJTÓW: bajt musi być od 0 do 255");
        if (n == 0) break;
        s[w++] = (char)n;
    }
    s[w] = 0;
    FerdekValue r = make_string(s);
    fx_free(s);
    return r;
}

static FerdekValue b_bajty_z_kanapy(int argc, FerdekValue* argv) {
    char* t = to_str(argv[0]);
    size_t n = strlen(t);
    FerdekValue out = make_array(NULL, 0);
    out.value.array_val->data = fx_malloc(sizeof(FerdekValue) * (n > 0 ? n : 1));
    for (size_t i = 0; i < n; i++) out.value.array_val->data[i] = make_typed(TYPE_BYTE, (unsigned char)t[i]);
    out.value.array_val->length = (int)n;
    fx_free(t);
    return out;
}

static FerdekValue b_odwroc_kanape(int argc, FerdekValue* argv) {
    char* t = to_str(argv[0]);
    long long* off;
    long long n = utf8_index(t, &off);
    size_t len = strlen(t);
    char* s = fx_malloc(len + 1);
    size_t w = 0;
    for (long long i = n - 1; i >= 0; i--) {
        size_t cl = off[i + 1] - off[i];
        memcpy(s + w, t + off[i], cl);
        w += cl;
    }
    s[w] = '\0';
    fx_free(off); fx_free(t);
    return own_string(s);
}

static FerdekValue b_rozciagnij_lewo(int argc, FerdekValue* argv) {
    char* t = to_str(argv[0]);
    long long target = to_int(argv[1]);
    long long chars = utf8_index(t, NULL);
    if (chars >= target) return own_string(t);
    size_t len = strlen(t), pad = (size_t)(target - chars);
    char* s = fx_malloc(len + pad + 1);
    memset(s, ' ', pad);
    memcpy(s + pad, t, len + 1);
    fx_free(t);
    return own_string(s);
}

static FerdekValue b_wszystkie_rzeczy(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "WSZYSTKIE RZECZY: argument musi być szafką (mapą)");
    char** keys = map_sorted_keys(m);
    FerdekValue out = make_array(NULL, 0);
    out.value.array_val->data = fx_malloc(sizeof(FerdekValue) * (m->len + 1));
    for (int i = 0; i < m->len; i++) out.value.array_val->data[i] = m->vals[map_find(m, keys[i])];
    out.value.array_val->length = m->len;
    fx_free(keys);
    return out;
}

static FerdekValue b_doloz_szafke(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_MAP || argv[1].type != TYPE_MAP) ferdek_die("DOŁÓŻ SZAFKĘ: oba argumenty muszą być szafkami (mapami)");
    FerdekValue out = b_szafka_otworz(0, NULL);
    FerdekMap* src[2] = { argv[0].value.map_val, argv[1].value.map_val };
    for (int k = 0; k < 2; k++)
        for (int i = 0; i < src[k]->len; i++) {
            FerdekValue kv[3] = { out, make_string(src[k]->keys[i]), src[k]->vals[i] };
            b_szafka_wloz(3, kv);
        }
    return out;
}

