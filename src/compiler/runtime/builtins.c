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
        fx_free(s);
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
    long long* off = offsets ? fx_malloc(sizeof(long long) * cap) : NULL;
    const char* p = s;
    while (*p) {
        if (off) { if (n + 1 >= cap) { cap *= 2; off = fx_realloc(off, sizeof(long long) * cap); } off[n] = p - s; }
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
    s = fx_realloc(s, len + (target - chars) + 1);
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
        arr->data = fx_realloc(arr->data, sizeof(FerdekValue) * (arr->length + 1));
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
        fx_free(item);
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
    char num[32];
    char* owned;
    FerdekValue n = make_int(utf8_index(str_view(argv[0], num, sizeof num, &owned), NULL));
    fx_free(owned);
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
    FerdekValue out = make_array(arr->data, arr->length);
    FerdekArray* o = out.value.array_val;
    o->data = fx_realloc(o->data, sizeof(FerdekValue) * (arr->length + 1));
    o->data[o->length++] = argv[1];
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
    FerdekValue* tmp = fx_malloc(sizeof(FerdekValue) * (arr->length > 0 ? arr->length : 1));
    merge_sort(out.value.array_val->data, tmp, arr->length);
    fx_free(tmp);
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
    out.value.array_val->data = fx_malloc(sizeof(FerdekValue) * (arr->length > 0 ? arr->length : 1));
    for (int i = 0; i < arr->length; i++)
        if (to_bool(call_value(f, f.value.fn_val.name, 1, &arr->data[i])))
            out.value.array_val->data[out.value.array_val->length++] = arr->data[i];
    return out;
}

static FerdekValue b_zrob_bajcik(int argc, FerdekValue* argv) { return make_typed(TYPE_BYTE, to_int(argv[0]) & 0xFF); }
/* Jawne obcięcie liczby z przecinkiem - jak int_of_float */
/* Jak float_to_int w interpreterze: poza zakresem int OCamla (±2^62) i NaN to błąd */
static long long float_to_int(const char* what, double f) {
    if (isnan(f) || f >= 4611686018427387904.0 || f < -4611686018427387904.0)
        ferdek_die("%s: liczba za duża, żeby zrobić z niej całkowitą", what);
    return (long long)f;
}

/* Matematyka ZE SKRZYNKI - te same zasady co w interpreterze */
static FerdekValue b_tangens(int argc, FerdekValue* argv) { return make_float(tan(to_float(argv[0]))); }

static FerdekValue b_potega(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_FLOAT && argv[1].type != TYPE_FLOAT && to_int(argv[1]) >= 0) {
        long long acc = 1, x = to_int(argv[0]), n = to_int(argv[1]);
        while (n != 0) { if (n & 1) acc = imul(acc, x); x = imul(x, x); n >>= 1; }
        return make_int(acc);
    }
    return make_float(pow(to_float(argv[0]), to_float(argv[1])));
}

static FerdekValue b_logarytm(int argc, FerdekValue* argv) {
    double x = to_float(argv[0]);
    if (!(x > 0.0)) ferdek_die("LOGARYTM ZE SKRZYNKI: liczba musi być większa od zera");
    return make_float(log(x));
}

static FerdekValue b_podloga(int argc, FerdekValue* argv) {
    return argv[0].type == TYPE_FLOAT ? make_int(float_to_int("PODŁOGA ZE SKRZYNKI", floor(argv[0].value.float_val))) : make_int(to_int(argv[0]));
}

static FerdekValue b_sufit(int argc, FerdekValue* argv) {
    return argv[0].type == TYPE_FLOAT ? make_int(float_to_int("SUFIT ZE SKRZYNKI", ceil(argv[0].value.float_val))) : make_int(to_int(argv[0]));
}

static FerdekValue b_modul(int argc, FerdekValue* argv) {
    if (argv[0].type == TYPE_FLOAT) return make_float(fabs(argv[0].value.float_val));
    long long n = to_int(argv[0]);
    return make_int(n < 0 ? isub(0, n) : n);
}

static FerdekValue b_zrob_dlugi(int argc, FerdekValue* argv) {
    return argv[0].type == TYPE_FLOAT ? make_int(float_to_int("ZRÓB DŁUGI", argv[0].value.float_val)) : make_int(to_int(argv[0]));
}

static FerdekValue to_fixed(FerdekValue v) {
    return v.type == TYPE_FLOAT ? make_int(float_to_int("ZAMIEŃ NA FIXED", v.value.float_val * 65536.0)) : make_int(ishl(to_int(v), 16));
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

