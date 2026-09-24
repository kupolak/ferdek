/* ---- SZAFKA (mapy; klucze to tekstowa postać argumentu, jak w interpreterze) ---- */

static FerdekMap* map_arg(FerdekValue v, const char* msg) {
    if (v.type != TYPE_MAP) ferdek_die("%s", msg);
    return v.value.map_val;
}

static FerdekValue b_szafka_wloz(int argc, FerdekValue* argv);
static FerdekValue b_szafka_otworz(int argc, FerdekValue* argv) {
    if (argc % 2 != 0) ferdek_die("OTWÓRZ SZAFKĘ: potrzebne pary klucz, wartość (parzysta liczba argumentów)");
    FerdekValue v;
    v.type = TYPE_MAP;
    v.value.map_val = fx_calloc(1, sizeof(FerdekMap));
    for (int i = 0; i < argc; i += 2) {
        FerdekValue kv[3] = { v, argv[i], argv[i + 1] };
        b_szafka_wloz(3, kv);
    }
    return v;
}

static FerdekValue b_szafka_wloz(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "WŁÓŻ DO SZAFKI: pierwszy argument musi być szafką (mapą)");
    char* key = to_str(argv[1]);
    int i = map_find(m, key);
    if (i >= 0) { m->vals[i] = argv[2]; fx_free(key); return make_null(); }
    map_append(m, key, argv[2]);
    return make_null();
}

static FerdekValue b_szafka_wyjmij(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "WYJMIJ Z SZAFKI: pierwszy argument musi być szafką (mapą)");
    char* key = to_str(argv[1]);
    int i = map_find(m, key);
    fx_free(key);
    return i >= 0 ? m->vals[i] : make_null();
}

static FerdekValue b_szafka_wyrzuc(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "WYRZUĆ ZE SZAFKI: pierwszy argument musi być szafką (mapą)");
    char* key = to_str(argv[1]);
    int i = map_find(m, key);
    fx_free(key);
    if (i >= 0) map_remove_at(m, i);   /* kolejność w środku bez znaczenia - wypisujemy posortowane */
    return make_null();
}

static FerdekValue b_szafka_czy_w(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "CZY W SZAFCE: pierwszy argument musi być szafką (mapą)");
    char* key = to_str(argv[1]);
    bool found = map_find(m, key) >= 0;
    fx_free(key);
    return make_bool(found);
}

static FerdekValue b_szafka_szufladki(int argc, FerdekValue* argv) {
    FerdekMap* m = map_arg(argv[0], "WSZYSTKIE SZUFLADKI: argument musi być szafką (mapą)");
    char** keys = map_sorted_keys(m);
    FerdekValue out = make_array(NULL, 0);
    out.value.array_val->data = fx_malloc(sizeof(FerdekValue) * (m->len > 0 ? m->len : 1));
    for (int i = 0; i < m->len; i++) out.value.array_val->data[i] = make_string(keys[i]);
    out.value.array_val->length = m->len;
    fx_free(keys);
    return out;
}

/* Kopia elementów dla pętli KRĘCI CEMENT BETONIARA x Z kolekcja - jak w interpreterze */
static FerdekArray* foreach_items(FerdekValue v) {
    if (v.type == TYPE_ARRAY) return make_array(v.value.array_val->data, v.value.array_val->length).value.array_val;
    if (v.type == TYPE_MAP) return b_szafka_szufladki(1, &v).value.array_val;
    if (v.type == TYPE_STRING) {
        long long* off;
        long long n = utf8_index(v.value.string_val, &off);
        FerdekValue out = make_array(NULL, 0);
        out.value.array_val->data = fx_malloc(sizeof(FerdekValue) * (n > 0 ? n : 1));
        for (long long i = 0; i < n; i++) {
            size_t len = off[i + 1] - off[i];
            char* c = fx_malloc(len + 1);
            memcpy(c, v.value.string_val + off[i], len);
            c[len] = '\0';
            out.value.array_val->data[i] = own_string(c);
        }
        out.value.array_val->length = n;
        fx_free(off);
        return out.value.array_val;
    }
    ferdek_die("KRĘCI CEMENT BETONIARA ... Z: po tym nie da się przejść (tablica, szafka albo tekst)");
    return NULL;
}

static FerdekValue b_szafka_ile(int argc, FerdekValue* argv) {
    return make_int(map_arg(argv[0], "ILE W SZAFCE: argument musi być szafką (mapą)")->len);
}

static FerdekValue b_pierwiastek(int argc, FerdekValue* argv) {
    double x = to_float(argv[0]);
    if (x < 0.0) ferdek_die("PIERWIASTEK ZE SKRZYNKI: pierwiastek z liczby ujemnej");
    return make_float(sqrt(x));
}
