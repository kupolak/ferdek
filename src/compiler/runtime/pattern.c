/* ---- Wzorce w tekstach (CZY KANAPA PASUJE, ZNAJDŹ NA KANAPIE, ...) - ten sam podzbiór i te same
   zasady co Pattern w interpreterze: znaki UTF-8, kotwice ^ $, klasy, \d \w \s, * + ?, nawroty ---- */

enum { PI_SINGLE, PI_RANGE, PI_DIGIT, PI_WORD, PI_SPACE };
typedef struct { int kind; int neg; long lo, hi; } PatItem;
enum { PA_ANY, PA_CHAR, PA_CLASS };
enum { PQ_ONE, PQ_STAR, PQ_PLUS, PQ_OPT };
typedef struct { int atom; long ch; int neg; PatItem* items; int nitems; int quant; } PatNode;
typedef struct { PatNode* nodes; int n; int start_anchor, end_anchor; } Pattern;

/* Długość znaku jak Text_utils.char_len; nieprawidłowy bajt - 1 */
static int pat_char_len(const char* s, int i, int n) {
    unsigned char c = (unsigned char)s[i];
    int len = c < 0x80 ? 1 : (c & 0xE0) == 0xC0 ? 2 : (c & 0xF0) == 0xE0 ? 3 : (c & 0xF8) == 0xF0 ? 4 : 1;
    return i + len > n ? 1 : len;
}

static long pat_code_at(const char* s, int i, int len) {
    const unsigned char* b = (const unsigned char*)s + i;
    switch (len) {
        case 2: return ((b[0] & 0x1F) << 6) | (b[1] & 0x3F);
        case 3: return ((b[0] & 0x0F) << 12) | ((b[1] & 0x3F) << 6) | (b[2] & 0x3F);
        case 4: return ((long)(b[0] & 0x07) << 18) | ((b[1] & 0x3F) << 12) | ((b[2] & 0x3F) << 6) | (b[3] & 0x3F);
        default: return b[0];
    }
}

/* Kody znaków i pozycje bajtów (offs ma n + 1 pozycji) */
static int pat_decode(const char* s, long** codes, int** offs) {
    int n = (int)strlen(s), k = 0;
    *codes = fx_malloc(sizeof(long) * (n + 1));
    *offs = fx_malloc(sizeof(int) * (n + 1));
    for (int i = 0; i < n; ) {
        int len = pat_char_len(s, i, n);
        (*codes)[k] = pat_code_at(s, i, len);
        (*offs)[k++] = i;
        i += len;
    }
    (*offs)[k] = n;
    return k;
}

static int pat_is_digit(long c) { return c >= 48 && c <= 57; }
static int pat_is_word(long c) { return pat_is_digit(c) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c >= 128; }
static int pat_is_space(long c) { return c == 32 || c == 9 || c == 10 || c == 13; }

static int pat_item_matches(long c, const PatItem* it) {
    switch (it->kind) {
        case PI_SINGLE: return c == it->lo;
        case PI_RANGE: return c >= it->lo && c <= it->hi;
        case PI_DIGIT: return pat_is_digit(c) != it->neg;
        case PI_WORD: return pat_is_word(c) != it->neg;
        default: return pat_is_space(c) != it->neg;
    }
}

static int pat_atom_matches(long c, const PatNode* nd) {
    if (nd->atom == PA_ANY) return 1;
    if (nd->atom == PA_CHAR) return c == nd->ch;
    int any = 0;
    for (int k = 0; k < nd->nitems && !any; k++) any = pat_item_matches(c, &nd->items[k]);
    return any != nd->neg;
}

static int pat_escape(long e, PatItem* it) {
    it->neg = (e == 'D' || e == 'W' || e == 'S');
    switch (e) {
        case 'd': case 'D': it->kind = PI_DIGIT; return 1;
        case 'w': case 'W': it->kind = PI_WORD; return 1;
        case 's': case 'S': it->kind = PI_SPACE; return 1;
        default: return 0;
    }
}

static Pattern pat_compile(const char* what, const char* pat) {
    long* p; int* offs;
    int n = pat_decode(pat, &p, &offs);
    Pattern re;
    re.start_anchor = n > 0 && p[0] == '^';
    re.end_anchor = n > (re.start_anchor ? 1 : 0) && p[n - 1] == '$' && !(n >= 2 && p[n - 2] == '\\');
    int last = re.end_anchor ? n - 1 : n;
    re.nodes = fx_malloc(sizeof(PatNode) * (n > 0 ? n : 1));
    re.n = 0;
    int i = re.start_anchor ? 1 : 0;
    while (i < last) {
        long c = p[i];
        PatNode nd = { PA_CHAR, c, 0, NULL, 0, PQ_ONE };
        if (c == '.') { nd.atom = PA_ANY; i++; }
        else if (c == '\\') {
            if (i + 1 >= last) ferdek_die("%s: zły wzór - \\ na końcu wzoru", what);
            long e = p[i + 1];
            i += 2;
            PatItem it;
            if (pat_escape(e, &it)) {
                nd.atom = PA_CLASS; nd.items = fx_malloc(sizeof(PatItem)); nd.items[0] = it; nd.nitems = 1;
            } else nd.ch = e;
        }
        else if (c == '[') {
            i++;
            nd.atom = PA_CLASS;
            nd.neg = i < last && p[i] == '^';
            if (nd.neg) i++;
            nd.items = fx_malloc(sizeof(PatItem) * (last - i + 1));
            int first = 1;
            while (i < last && (p[i] != ']' || first)) {
                first = 0;
                PatItem it = { PI_SINGLE, 0, 0, 0 };
                long lo;
                int esc = 0;
                if (p[i] == '\\') {
                    if (i + 1 >= last) ferdek_die("%s: zły wzór - niezamknięty [", what);
                    long e = p[i + 1];
                    i += 2;
                    if (pat_escape(e, &it)) esc = 1; else lo = e;
                } else lo = p[i++];
                if (esc) { nd.items[nd.nitems++] = it; continue; }
                if (i + 1 < last && p[i] == '-' && p[i + 1] != ']') {
                    i++;
                    long hi;
                    if (p[i] == '\\' && i + 1 < last) { i += 2; hi = p[i - 1]; } else { i++; hi = p[i - 1]; }
                    if (hi < lo) ferdek_die("%s: zły wzór - zły zakres w [ ]", what);
                    it.kind = PI_RANGE; it.lo = lo; it.hi = hi;
                } else { it.kind = PI_SINGLE; it.lo = lo; }
                nd.items[nd.nitems++] = it;
            }
            if (i >= last) ferdek_die("%s: zły wzór - niezamknięty [", what);
            i++;
        }
        else if (c == '*' || c == '+' || c == '?') ferdek_die("%s: zły wzór - * + ? bez niczego przed", what);
        else i++;
        if (i < last && p[i] == '*') { nd.quant = PQ_STAR; i++; }
        else if (i < last && p[i] == '+') { nd.quant = PQ_PLUS; i++; }
        else if (i < last && p[i] == '?') { nd.quant = PQ_OPT; i++; }
        re.nodes[re.n++] = nd;
    }
    return re;
}

/* Koniec dopasowania od znaku ti dla węzłów od ni; -1 - brak */
static int pat_go(const Pattern* re, const long* codes, int len, int ni, int ti) {
    if (ni == re->n) return (re->end_anchor && ti != len) ? -1 : ti;
    const PatNode* nd = &re->nodes[ni];
    switch (nd->quant) {
        case PQ_ONE:
            return (ti < len && pat_atom_matches(codes[ti], nd)) ? pat_go(re, codes, len, ni + 1, ti + 1) : -1;
        case PQ_OPT: {
            if (ti < len && pat_atom_matches(codes[ti], nd)) {
                int e = pat_go(re, codes, len, ni + 1, ti + 1);
                if (e >= 0) return e;
            }
            return pat_go(re, codes, len, ni + 1, ti);
        }
        default: {
            int m = ti;
            while (m < len && pat_atom_matches(codes[m], nd)) m++;
            int min = nd->quant == PQ_PLUS ? ti + 1 : ti;
            for (int k = m; k >= min; k--) {
                int e = pat_go(re, codes, len, ni + 1, k);
                if (e >= 0) return e;
            }
            return -1;
        }
    }
}

/* Pierwsze dopasowanie od znaku from: 1 i *s, *e albo 0 */
static int pat_search(const Pattern* re, const long* codes, int len, int from, int* s, int* e) {
    for (int st = from; st <= len && !(re->start_anchor && st > 0); st++) {
        int end = pat_go(re, codes, len, 0, st);
        if (end >= 0) { *s = st; *e = end; return 1; }
    }
    return 0;
}

static FerdekValue pat_slice(const char* text, const int* offs, int a, int b) {
    int n = offs[b] - offs[a];
    char* out = fx_malloc(n + 1);
    memcpy(out, text + offs[a], n);
    out[n] = '\0';
    return own_string(out);
}

static FerdekValue b_czy_kanapa_pasuje(int argc, FerdekValue* argv) {
    char* text = to_str(argv[0]);
    Pattern re = pat_compile("CZY KANAPA PASUJE", to_str(argv[1]));
    long* codes; int* offs;
    int len = pat_decode(text, &codes, &offs), s, e;
    return make_bool(pat_search(&re, codes, len, 0, &s, &e));
}

static FerdekValue b_znajdz_na_kanapie(int argc, FerdekValue* argv) {
    char* text = to_str(argv[0]);
    Pattern re = pat_compile("ZNAJDŹ NA KANAPIE", to_str(argv[1]));
    long* codes; int* offs;
    int len = pat_decode(text, &codes, &offs), s, e;
    return pat_search(&re, codes, len, 0, &s, &e) ? pat_slice(text, offs, s, e) : make_null();
}

static FerdekValue b_znajdz_wszystko_na_kanapie(int argc, FerdekValue* argv) {
    char* text = to_str(argv[0]);
    Pattern re = pat_compile("ZNAJDŹ WSZYSTKO NA KANAPIE", to_str(argv[1]));
    long* codes; int* offs;
    int len = pat_decode(text, &codes, &offs), s, e, count = 0;
    FerdekValue* items = fx_malloc(sizeof(FerdekValue) * (len + 2));
    for (int from = 0; from <= len && pat_search(&re, codes, len, from, &s, &e); from = (e == s ? s + 1 : e))
        items[count++] = pat_slice(text, offs, s, e);
    return make_array(items, count);
}

static FerdekValue b_podmien_na_kanapie(int argc, FerdekValue* argv) {
    char* text = to_str(argv[0]);
    Pattern re = pat_compile("PODMIEŃ NA KANAPIE", to_str(argv[1]));
    char* by = to_str(argv[2]);
    long* codes; int* offs;
    int len = pat_decode(text, &codes, &offs), s, e, pos = 0;
    StrBuf b = {0};
    buf_add(&b, "");
    for (int from = 0; from <= len && pat_search(&re, codes, len, from, &s, &e); from = (e == s ? s + 1 : e)) {
        buf_add(&b, pat_slice(text, offs, pos, s).value.string_val);
        buf_add(&b, by);
        if (e == s) {
            /* puste dopasowanie: znak za nim przepisujemy i idziemy dalej */
            if (s < len) buf_add(&b, pat_slice(text, offs, s, s + 1).value.string_val);
            pos = s + 1;
        } else pos = e;
    }
    if (pos < len) buf_add(&b, pat_slice(text, offs, pos, len).value.string_val);
    return own_string(b.s);
}
