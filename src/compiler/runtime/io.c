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
        unsigned char* buf = fx_malloc(size > 0 ? size : 1);
        size_t n = fread(buf, 1, size, argv[0].value.file_val.f);
        FerdekValue out = make_array(NULL, 0);
        out.value.array_val->data = fx_malloc(sizeof(FerdekValue) * (n > 0 ? n : 1));
        for (size_t i = 0; i < n; i++) out.value.array_val->data[i] = make_typed(TYPE_BYTE, buf[i]);
        out.value.array_val->length = (int)n;
        fx_free(buf);
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
            if (spec == 's' && next < argc) { char* s = to_str(argv[next++]); buf_add(&b, s); fx_free(s); p += 2; continue; }
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

