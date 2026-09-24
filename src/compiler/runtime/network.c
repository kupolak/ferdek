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
        data = fx_malloc(len > 0 ? len : 1);
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
    char* buf = fx_malloc(size + 1);
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

static FerdekValue b_po_pierwsze_primo(int argc, FerdekValue* argv) {
    double x = to_float(argv[0]);
    long long n = to_int(argv[1]);
    if (n < 0 || n > 30) ferdek_die("PO PIERWSZE PRIMO: liczba miejsc musi być od 0 do 30");
    char buf[512];
    snprintf(buf, sizeof buf, "%.*f", (int)n, x);
    return make_string(buf);
}

static FerdekValue zeros(long long n) {
    FerdekValue v = make_array(NULL, 0);
    v.value.array_val->data = fx_malloc(sizeof(FerdekValue) * n);
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
    fx_free(s);
}

static void print_inline(FerdekValue v) {
    char* s = to_str(v);
    fputs(s, stdout);
    fx_free(s);
}

/* Linia wejścia dowolnej długości bez znaku nowej linii (jak read_line); NULL na końcu wejścia */
static char* read_line_raw(void) {
    char* line = NULL;
    size_t cap = 0;
    ssize_t n = getline(&line, &cap, stdin);
    if (n == -1) { free(line); return NULL; }
    if (n > 0 && line[n - 1] == '\n') line[n - 1] = 0;
    char* out = fx_strdup(line);
    free(line);   /* bufor z getline - systemowy malloc */
    return out;
}

static FerdekValue read_value(void) {
    char* line = read_line_raw();
    if (!line) return make_null();
    return is_decimal(line) ? make_int(strtoll(line, NULL, 10)) : own_string(line);
}

static FerdekValue b_nastepna_linijka(int argc, FerdekValue* argv) {
    char* line = read_line_raw();
    return line ? own_string(line) : make_null();
}

static FerdekValue b_cale_wejscie(int argc, FerdekValue* argv) {
    StrBuf b = {0};
    buf_add(&b, "");
    for (char* line; (line = read_line_raw()); fx_free(line)) { buf_add(&b, line); buf_add(&b, "\n"); }
    return own_string(b.s);
}
