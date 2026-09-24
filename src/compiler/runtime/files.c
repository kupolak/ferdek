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
        arr->data = fx_realloc(arr->data, sizeof(FerdekValue) * (arr->length + 1));
        arr->data[arr->length++] = make_string(line);
    }
    free(line);   /* bufor z getline - systemowy malloc */
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
        arr->data = fx_realloc(arr->data, sizeof(FerdekValue) * (arr->length + 1));
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
                char* full = fx_malloc(strlen(path) + strlen(e->d_name) + 2);
                sprintf(full, "%s/%s", path, e->d_name);
                wykop(full);
                fx_free(full);
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

/* Argumenty programu (main je ustawia), zmienne środowiska, kod wyjścia - jak w interpreterze */
static int ferdek_argc = 0;
static char** ferdek_argv = NULL;

static FerdekValue b_co_pan_przyniosl(int argc, FerdekValue* argv) {
    int n = ferdek_argc > 1 ? ferdek_argc - 1 : 0;
    FerdekValue* items = fx_malloc(sizeof(FerdekValue) * (n > 0 ? n : 1));
    for (int i = 0; i < n; i++) items[i] = make_string(ferdek_argv[i + 1]);
    return make_array(items, n);
}

static FerdekValue b_co_mowi_sasiad(int argc, FerdekValue* argv) {
    const char* v = getenv(to_str(argv[0]));
    return v ? make_string(v) : make_null();
}

static FerdekValue b_zamykam_interes(int argc, FerdekValue* argv) {
    long long code = to_int(argv[0]);
    if (code < 0 || code > 255) ferdek_die("ZAMYKAM INTERES: kod wyjścia musi być od 0 do 255");
    fflush(stdout); fflush(stderr);
    exit((int)code);
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

