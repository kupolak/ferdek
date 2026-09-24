/* ---- SŁOIK: JSON - te same zasady co Json w interpreterze ---- */
static void json_str(StrBuf* b, const char* s) {
    buf_add(b, "\"");
    char tmp[8];
    for (const unsigned char* p = (const unsigned char*)s; *p; p++) {
        switch (*p) {
            case '"': buf_add(b, "\\\""); break;
            case '\\': buf_add(b, "\\\\"); break;
            case '\n': buf_add(b, "\\n"); break;
            case '\r': buf_add(b, "\\r"); break;
            case '\t': buf_add(b, "\\t"); break;
            case '\b': buf_add(b, "\\b"); break;
            case '\f': buf_add(b, "\\f"); break;
            default:
                if (*p < 0x20) { snprintf(tmp, sizeof tmp, "\\u%04x", *p); buf_add(b, tmp); }
                else { tmp[0] = (char)*p; tmp[1] = 0; buf_add(b, tmp); }
        }
    }
    buf_add(b, "\"");
}
static void json_pack(StrBuf* b, FerdekValue v) {
    switch (v.type) {
        case TYPE_NULL: buf_add(b, "null"); return;
        case TYPE_BOOL: buf_add(b, v.value.bool_val ? "true" : "false"); return;
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED: case TYPE_FLOAT: {
            if (v.type == TYPE_FLOAT && (isnan(v.value.float_val) || isinf(v.value.float_val)))
                ferdek_die("ZAPAKUJ DO SŁOIKA: tego nie zapakujesz: liczba bez końca (nan/inf)");
            char* t = to_str(v); buf_add(b, t); fx_free(t); return;
        }
        case TYPE_STRING: json_str(b, v.value.string_val); return;
        case TYPE_ARRAY: {
            buf_add(b, "[");
            for (int i = 0; i < v.value.array_val->length; i++) {
                if (i > 0) buf_add(b, ",");
                json_pack(b, v.value.array_val->data[i]);
            }
            buf_add(b, "]");
            return;
        }
        case TYPE_MAP: {
            FerdekMap* m = v.value.map_val;
            char** keys = map_sorted_keys(m);
            buf_add(b, "{");
            for (int i = 0; i < m->len; i++) {
                if (i > 0) buf_add(b, ",");
                json_str(b, keys[i]);
                buf_add(b, ":");
                json_pack(b, m->vals[map_find(m, keys[i])]);
            }
            buf_add(b, "}");
            fx_free(keys);
            return;
        }
        default: ferdek_die("ZAPAKUJ DO SŁOIKA: tego nie zapakujesz: %s", value_kind(v));
    }
}
static FerdekValue b_zapakuj(int argc, FerdekValue* argv) {
    StrBuf b = {0};
    buf_add(&b, "");
    json_pack(&b, argv[0]);
    return own_string(b.s);
}

typedef struct { const char* s; size_t n, pos; } JsonIn;
static void json_fail(JsonIn* in) { ferdek_die("WYJMIJ ZE SŁOIKA: zły JSON (znak %d)", (int)in->pos + 1); }
static char json_peek(JsonIn* in) { return in->pos < in->n ? in->s[in->pos] : 0; }
static void json_ws(JsonIn* in) {
    while (in->pos < in->n && strchr(" \t\n\r", in->s[in->pos])) in->pos++;
}
static void json_expect(JsonIn* in, char c) { if (in->pos < in->n && json_peek(in) == c) in->pos++; else json_fail(in); }
static int json_hex4(JsonIn* in) {
    if (in->pos + 4 > in->n) json_fail(in);
    int v = 0;
    for (int i = 0; i < 4; i++) {
        char c = in->s[in->pos + i];
        int d = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
        if (d < 0) json_fail(in);
        v = v * 16 + d;
    }
    in->pos += 4;
    return v;
}
static void json_utf8(StrBuf* b, int cp) {
    char t[5] = {0};
    if (cp < 0x80) t[0] = (char)cp;
    else if (cp < 0x800) { t[0] = (char)(0xC0 | (cp >> 6)); t[1] = (char)(0x80 | (cp & 0x3F)); }
    else if (cp < 0x10000) { t[0] = (char)(0xE0 | (cp >> 12)); t[1] = (char)(0x80 | ((cp >> 6) & 0x3F)); t[2] = (char)(0x80 | (cp & 0x3F)); }
    else { t[0] = (char)(0xF0 | (cp >> 18)); t[1] = (char)(0x80 | ((cp >> 12) & 0x3F));
           t[2] = (char)(0x80 | ((cp >> 6) & 0x3F)); t[3] = (char)(0x80 | (cp & 0x3F)); }
    buf_add(b, t);
}
static char* json_string(JsonIn* in) {
    json_expect(in, '"');
    StrBuf b = {0};
    buf_add(&b, "");
    for (;;) {
        if (in->pos >= in->n) json_fail(in);
        char c = in->s[in->pos++];
        if (c == '"') break;
        if (c == '\\') {
            if (in->pos >= in->n) json_fail(in);
            char e = in->s[in->pos++];
            char one[2] = {0, 0};
            switch (e) {
                case '"': one[0] = '"'; break;
                case '\\': one[0] = '\\'; break;
                case '/': one[0] = '/'; break;
                case 'b': one[0] = '\b'; break;
                case 'f': one[0] = '\f'; break;
                case 'n': one[0] = '\n'; break;
                case 'r': one[0] = '\r'; break;
                case 't': one[0] = '\t'; break;
                case 'u': {
                    int cp = json_hex4(in);
                    if (cp >= 0xD800 && cp <= 0xDBFF) {
                        if (!(in->pos + 2 <= in->n && in->s[in->pos] == '\\' && in->s[in->pos + 1] == 'u')) json_fail(in);
                        in->pos += 2;
                        int lo = json_hex4(in);
                        if (lo < 0xDC00 || lo > 0xDFFF) json_fail(in);
                        json_utf8(&b, 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00));
                    } else if (cp >= 0xDC00 && cp <= 0xDFFF) json_fail(in);
                    else json_utf8(&b, cp);
                    continue;
                }
                default: in->pos--; json_fail(in);
            }
            buf_add(&b, one);
            continue;
        }
        if ((unsigned char)c < 0x20) { in->pos--; json_fail(in); }
        char one[2] = {c, 0};
        buf_add(&b, one);
    }
    return b.s;
}
static void json_digits(JsonIn* in) {
    size_t d = in->pos;
    while (in->pos < in->n && in->s[in->pos] >= '0' && in->s[in->pos] <= '9') in->pos++;
    if (in->pos == d) json_fail(in);
}
static FerdekValue json_number(JsonIn* in) {
    size_t start = in->pos;
    bool frac = false;
    if (json_peek(in) == '-') in->pos++;
    if (json_peek(in) == '0') in->pos++; else json_digits(in);
    if (json_peek(in) == '.') { in->pos++; json_digits(in); frac = true; }
    if (json_peek(in) == 'e' || json_peek(in) == 'E') {
        in->pos++;
        if (json_peek(in) == '+' || json_peek(in) == '-') in->pos++;
        json_digits(in);
        frac = true;
    }
    char* text = fx_malloc(in->pos - start + 1);
    memcpy(text, in->s + start, in->pos - start);
    text[in->pos - start] = 0;
    FerdekValue v = (!frac && is_decimal(text)) ? make_int(strtoll(text, NULL, 10)) : make_float(strtod(text, NULL));
    fx_free(text);
    return v;
}
static FerdekValue json_value(JsonIn* in) {
    json_ws(in);
    FerdekValue v;
    char c = json_peek(in);
    if (c == '{') {
        in->pos++; json_ws(in);
        v = b_szafka_otworz(0, NULL);
        if (json_peek(in) == '}') in->pos++;
        else for (;;) {
            json_ws(in);
            char* k = json_string(in);
            json_ws(in); json_expect(in, ':');
            FerdekValue item = json_value(in);
            FerdekValue kv[3] = { v, make_string(k), item };
            b_szafka_wloz(3, kv);
            json_ws(in);
            if (json_peek(in) == ',') { in->pos++; continue; }
            json_expect(in, '}');
            break;
        }
    } else if (c == '[') {
        in->pos++; json_ws(in);
        v = make_array(NULL, 0);
        if (json_peek(in) == ']') in->pos++;
        else for (;;) {
            FerdekValue item = json_value(in);
            FerdekArray* a = v.value.array_val;
            a->data = fx_realloc(a->data, sizeof(FerdekValue) * (a->length + 1));
            a->data[a->length++] = item;
            json_ws(in);
            if (json_peek(in) == ',') { in->pos++; continue; }
            json_expect(in, ']');
            break;
        }
    } else if (c == '"') v = own_string(json_string(in));
    else if (c == 't' && in->pos + 4 <= in->n && strncmp(in->s + in->pos, "true", 4) == 0) { in->pos += 4; v = make_bool(true); }
    else if (c == 'f' && in->pos + 5 <= in->n && strncmp(in->s + in->pos, "false", 5) == 0) { in->pos += 5; v = make_bool(false); }
    else if (c == 'n' && in->pos + 4 <= in->n && strncmp(in->s + in->pos, "null", 4) == 0) { in->pos += 4; v = make_null(); }
    else if (c == '-' || (c >= '0' && c <= '9')) v = json_number(in);
    else { json_fail(in); v = make_null(); }
    json_ws(in);
    return v;
}
static FerdekValue b_wyjmij_ze_sloika(int argc, FerdekValue* argv) {
    char* text = to_str(argv[0]);
    JsonIn in = { text, strlen(text), 0 };
    FerdekValue v = json_value(&in);
    if (in.pos < in.n) json_fail(&in);
    return v;
}

static FerdekValue b_sinus(int argc, FerdekValue* argv) { return make_float(sin(to_float(argv[0]))); }
static FerdekValue b_cosinus(int argc, FerdekValue* argv) { return make_float(cos(to_float(argv[0]))); }

/* Czas - jak w interpreterze */
static struct timespec program_start;

static double ms_since_start(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (now.tv_sec - program_start.tv_sec) * 1000.0 + (now.tv_nsec - program_start.tv_nsec) / 1e6;
}

static FerdekValue b_trzeba_spac(int argc, FerdekValue* argv) {
    double ms = to_float(argv[0]);
    if (ms < 0.0) ferdek_die("TRZEBA SPAĆ: czas nie może być ujemny");
    fflush(stdout);
    struct timespec t = { (time_t)(ms / 1000.0), (long)(fmod(ms, 1000.0) * 1e6) };
    nanosleep(&t, NULL);
    return make_null();
}

static FerdekValue b_jest_trzecia(int argc, FerdekValue* argv) { return make_int((long long)ms_since_start()); }

