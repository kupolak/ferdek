#define _POSIX_C_SOURCE 200809L  /* strdup, nanosleep, clock_gettime przy -std=c99 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdarg.h>
#include <setjmp.h>
#include <time.h>
#include <ctype.h>
#include <math.h>
#include <errno.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>

/* Ferdek Runtime Library */

/* Pamięć: z -DFERDEK_GC (ferdek dodaje go, gdy znajdzie bdw-gc) zwalnia ją odśmiecacz Boehma;
   bez niego zwykły malloc i nic nie jest zwalniane - wystarcza krótkim programom */
#ifdef FERDEK_GC
#include <gc.h>
#define fx_malloc(n) GC_MALLOC(n)
#define fx_calloc(n, s) GC_MALLOC((n) * (s))   /* GC_MALLOC zeruje pamięć */
#define fx_realloc(p, n) GC_REALLOC(p, n)
#define fx_free(p) GC_FREE(p)
#define fx_strdup(s) GC_STRDUP(s)
#else
#define fx_malloc malloc
#define fx_calloc calloc
#define fx_realloc realloc
#define fx_free free
#define fx_strdup strdup
#endif
/* Nie każdy program używa każdej funkcji runtime'u */
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-variable"
/* ponytail: brak GC - pamięć stringów i tablic nie jest zwalniana (programy są krótkie) */

typedef enum {
    TYPE_NULL = 0,   /* zero-inicjalizowane zmienne globalne = null */
    TYPE_INT,
    TYPE_STRING,
    TYPE_BOOL,
    TYPE_ARRAY,
    TYPE_BYTE,       /* ZRÓB BAJCIK/KRÓTKI/UŁAMEK - liczby z własnym typem dla CO TO ZA TYP */
    TYPE_SHORT,
    TYPE_FIXED,
    TYPE_FUNCTION,
    TYPE_MAP,
    TYPE_FLOAT,
    TYPE_OBJECT,     /* obiekt klasy / struktury / unii: pola w FerdekMap */
    TYPE_POINTER,
    TYPE_FILE
} ValueType;

typedef struct FerdekValue FerdekValue;
typedef struct { FerdekValue* data; int length; } FerdekArray;
/* ponytail: mapa jako tablica par z wyszukiwaniem liniowym; hash, gdy mapy urosną do tysięcy kluczy */
typedef struct { char** keys; FerdekValue* vals; int len, cap; } FerdekMap;

struct FerdekValue {
    ValueType type;
    union {
        long long int_val;
        double float_val;
        char* string_val;
        bool bool_val;
        FerdekArray* array_val;   /* wskaźnik: kopia wartości współdzieli tablicę, jak w interpreterze */
        /* self: obiekt, z którym związana jest metoda (NULL dla zwykłej funkcji) */
        struct { FerdekValue (*call)(void*, int, FerdekValue*); const char* name; int arity; int required; bool variadic; void* self; } fn_val;
        FerdekValue* ptr_val;     /* wskaźnik: kopia wartości na stercie, jak ref w interpreterze */
        struct { FILE* f; bool input; } file_val;
        FerdekMap* map_val;       /* wskaźnik: kopia wartości współdzieli mapę, jak w interpreterze */
    } value;
};

/* Plik i linia wykonywanej instrukcji - jak w interpreterze */
static const char* ferdek_file = "";
static int ferdek_line = 0;
#define FERDEK_AT(f, l) (ferdek_file = (f), ferdek_line = (l))

static void print_loc(void) {
    if (ferdek_line == 0) return;
    if (ferdek_file[0]) fprintf(stderr, " (%s, linia %d)", ferdek_file, ferdek_line);
    else fprintf(stderr, " (linia %d)", ferdek_line);
}

/* Ścieżka wywołań: każda funkcja ma na stosie C ramkę (nazwa, miejsce wywołania, poprzednia).
   Ramka zastępuje też zapamiętanie pozycji wołającego - przy powrocie wracamy do frame.file/line. */
typedef struct Frame { const char* name; const char* file; int line; struct Frame* prev; } Frame;
static Frame* ferdek_top = NULL;

/* Linia z błędem (wbudowane źródła) i ścieżka wywołań - ten sam tekst co Source_texts.context */
static const char* source_line(const char* file, int line);
static void print_context(void) {
    const char* l = source_line(ferdek_file, ferdek_line);
    if (l) fprintf(stderr, "%5d | %s\n", ferdek_line, l);
    /* powtórzenia z rekurencji zwijamy: "(12 razy)" */
    int shown = 0, hidden = 0;
    for (Frame* f = ferdek_top; f; ) {
        int k = 1;
        Frame* g = f->prev;
        while (g && g->line == f->line && strcmp(g->name, f->name) == 0 && strcmp(g->file, f->file) == 0) { k++; g = g->prev; }
        if (shown < 8) {
            if (f->file[0] && strcmp(f->file, ferdek_file) != 0) fprintf(stderr, "  w funkcji %s, wywołanej w %s, linia %d", f->name, f->file, f->line);
            else fprintf(stderr, "  w funkcji %s, wywołanej w linii %d", f->name, f->line);
            if (k > 1) fprintf(stderr, " (%d razy)", k);
            fprintf(stderr, "\n");
            shown++;
        } else hidden += k;
        f = g;
    }
    if (hidden > 0) fprintf(stderr, "  ... i jeszcze %d\n", hidden);
}

/* Wyjątki: stos handlerów na setjmp/longjmp */
typedef struct Handler { jmp_buf buf; struct Handler* prev; Frame* top; } Handler;
static Handler* ferdek_handler = NULL;
static FerdekValue ferdek_exception;
static FerdekValue make_string(const char* s);
static bool ferdek_exception_error = false;   /* ferdek_exception pochodzi z błędu wykonania (ferdek_die) */

/* Błąd, którego HELENA MAM ZAWAŁ nie łapie (break/return poza pętlą/funkcją - jak w interpreterze) */
static void ferdek_fatal(const char* fmt, ...) {
    va_list ap;
    fflush(stdout);
    fprintf(stderr, "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: ");
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    print_loc();
    fprintf(stderr, "\n");
    print_context();
    exit(1);
}

/* Błąd wykonania: w bloku HELENA MUSZĘ CI COŚ POWIEDZIEĆ trafia do HELENA MAM ZAWAŁ jako tekst */
static void ferdek_die(const char* fmt, ...) {
    va_list ap;
    if (ferdek_handler != NULL) {
        char msg[1024];
        va_start(ap, fmt);
        vsnprintf(msg, sizeof msg, fmt, ap);
        va_end(ap);
        ferdek_exception = make_string(msg);
        ferdek_exception_error = true;
        longjmp(ferdek_handler->buf, 1);
    }
    fflush(stdout);
    fprintf(stderr, "Błąd Wykonania: 'W mordę jeża!'. Nie działa, bo: ");
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    print_loc();
    fprintf(stderr, "\n");
    print_context();
    exit(1);
}

static FerdekValue make_int(long long n) { FerdekValue v; v.type = TYPE_INT; v.value.int_val = n; return v; }
static FerdekValue make_float(double f) { FerdekValue v; v.type = TYPE_FLOAT; v.value.float_val = f; return v; }
static FerdekValue make_bool(bool b) { FerdekValue v; v.type = TYPE_BOOL; v.value.bool_val = b; return v; }
static FerdekValue make_null(void) { FerdekValue v; v.type = TYPE_NULL; return v; }

static FerdekValue make_string(const char* s) {
    FerdekValue v;
    v.type = TYPE_STRING;
    v.value.string_val = fx_strdup(s);
    return v;
}

/* Literał tekstowy bez kopiowania - teksty w runtime nigdy nie są zmieniane w miejscu */
static FerdekValue make_lit(const char* s) {
    FerdekValue v;
    v.type = TYPE_STRING;
    v.value.string_val = (char*)s;
    return v;
}

static FerdekValue make_array(FerdekValue* data, int length) {
    FerdekValue v;
    v.type = TYPE_ARRAY;
    v.value.array_val = fx_malloc(sizeof(FerdekArray));
    v.value.array_val->data = fx_malloc(sizeof(FerdekValue) * (length > 0 ? length : 1));
    if (length > 0) memcpy(v.value.array_val->data, data, sizeof(FerdekValue) * length);
    v.value.array_val->length = length;
    return v;
}

/* Liczby całkowite jak w interpreterze (OCaml): 63 bity, przepełnienie zawija. Wartość trzymamy
   w long long rozszerzoną znakiem z bitu 62; działania liczymy na unsigned (bez UB) i obcinamy. */
#define FERDEK_INT_MAX 4611686018427387903LL
#define FERDEK_INT_MIN (-FERDEK_INT_MAX - 1)
static inline long long w63(unsigned long long x) { return (long long)(x << 1) >> 1; }
/* Szybka ścieżka: wynik w zakresie (prawie zawsze) - zwykłe działanie; inaczej zawijamy */
#define FERDEK_FITS(r) ((r) >= FERDEK_INT_MIN && (r) <= FERDEK_INT_MAX)
/* (zmierzone: szybsze niż samo przycinanie przesunięciami i niż porównanie zakresu) */
static inline long long iadd(long long a, long long b) {
    long long r;
    if (__builtin_expect(!__builtin_add_overflow(a, b, &r) && FERDEK_FITS(r), 1)) return r;
    return w63((unsigned long long)a + (unsigned long long)b);
}
static inline long long isub(long long a, long long b) {
    long long r;
    if (__builtin_expect(!__builtin_sub_overflow(a, b, &r) && FERDEK_FITS(r), 1)) return r;
    return w63((unsigned long long)a - (unsigned long long)b);
}
static inline long long imul(long long a, long long b) {
    long long r;
    if (__builtin_expect(!__builtin_mul_overflow(a, b, &r) && FERDEK_FITS(r), 1)) return r;
    return w63((unsigned long long)a * (unsigned long long)b);
}
static inline long long int_div(long long a, long long b) {
    if (b == 0) ferdek_die("Dzielenie przez zero");
    if (b == -1) return isub(0, a);   /* min_int / -1: w OCamlu zawija, w C to awaria */
    return a / b;
}
static inline long long int_mod(long long a, long long b) {
    if (b == 0) ferdek_die("Reszta z dzielenia przez zero");
    if (b == -1) return 0;
    return a % b;
}
static inline void check_shift(long long n) {
    if (n < 0 || n > 62) ferdek_die("Przesunięcie o %lld bitów - można od 0 do 62", n);
}
static inline long long ishl(long long a, long long n) { check_shift(n); return w63((unsigned long long)a << n); }
/* lsr w OCamlu: przesunięcie logiczne 63-bitowej liczby */
static inline long long ishr(long long a, long long n) {
    check_shift(n);
    return w63(((unsigned long long)a & 0x7FFFFFFFFFFFFFFFULL) >> n);
}

/* Tekst jako liczba: tylko zapis dziesiętny w zakresie int OCamla - jak decimal_of_string */
static bool is_decimal(const char* s) {
    const char* p = s;
    if (*p == '-') p++;
    if (!*p) return false;
    for (const char* q = p; *q; q++) if (*q < '0' || *q > '9') return false;
    errno = 0;
    long long v = strtoll(s, NULL, 10);
    return errno == 0 && v >= FERDEK_INT_MIN && v <= FERDEK_INT_MAX;
}

static bool is_numeric(FerdekValue v) { return v.type != TYPE_STRING || is_decimal(v.value.string_val); }

static long long to_int(FerdekValue v);
static double to_float(FerdekValue v) { return v.type == TYPE_FLOAT ? v.value.float_val : (double)to_int(v); }

static long long to_int(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED: return v.value.int_val;
        case TYPE_BOOL: return v.value.bool_val ? 1 : 0;
        case TYPE_STRING:
            /* tylko zapis dziesiętny - jak decimal_of_string w interpreterze */
            if (!is_decimal(v.value.string_val)) ferdek_die("Tekst \"%s\" to nie liczba", v.value.string_val);
            return strtoll(v.value.string_val, NULL, 10);
        case TYPE_NULL: return 0;
        case TYPE_FLOAT: ferdek_die("Liczba z przecinkiem tam, gdzie trzeba całkowitej (użyj ZRÓB DŁUGI)"); return 0;
        default: ferdek_die("Tego nie da się zamienić na liczbę"); return 0;
    }
}

static bool to_bool(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED: return v.value.int_val != 0;
        case TYPE_BOOL: return v.value.bool_val;
        case TYPE_STRING: return v.value.string_val[0] != '\0';
        case TYPE_FLOAT: return v.value.float_val != 0.0;
        case TYPE_NULL: return false;
        default: return true;
    }
}

/* Prosty bufor do sklejania stringów */
typedef struct { char* s; size_t len, cap; } StrBuf;

static void buf_add(StrBuf* b, const char* t) {
    size_t n = strlen(t);
    if (b->len + n + 1 > b->cap) {
        b->cap = (b->len + n + 1) * 2;
        b->s = fx_realloc(b->s, b->cap);
    }
    memcpy(b->s + b->len, t, n + 1);
    b->len += n;
}

static int map_find(FerdekMap* m, const char* key) {
    for (int i = 0; i < m->len; i++) if (strcmp(m->keys[i], key) == 0) return i;
    return -1;
}

static int cmp_key_ptr(const void* a, const void* b) { return strcmp(*(char* const*)a, *(char* const*)b); }

/* Klucze posortowane - jak w interpreterze; zwraca nową tablicę wskaźników */
static char** map_sorted_keys(FerdekMap* m) {
    char** keys = fx_malloc(sizeof(char*) * (m->len > 0 ? m->len : 1));
    memcpy(keys, m->keys, sizeof(char*) * m->len);
    qsort(keys, m->len, sizeof(char*), cmp_key_ptr);
    return keys;
}

/* Tekstowa postać wartości - identyczna jak string_of_value w interpreterze */
static char* to_str(FerdekValue v) {
    char num[32];
    switch (v.type) {
        case TYPE_INT: case TYPE_BYTE: case TYPE_SHORT: case TYPE_FIXED:
            snprintf(num, sizeof num, "%lld", v.value.int_val);
            return fx_strdup(num);
        case TYPE_STRING: return fx_strdup(v.value.string_val);
        case TYPE_FLOAT:
            /* jak string_of_float_ferdek: %.15g i ".0" dla całych */
            snprintf(num, sizeof num - 2, "%.15g", v.value.float_val);
            if (!strpbrk(num, ".en")) strcat(num, ".0");
            return fx_strdup(num);
        case TYPE_BOOL: return fx_strdup(v.value.bool_val ? "true" : "false");
        case TYPE_NULL: return fx_strdup("null");
        case TYPE_MAP: {
            FerdekMap* m = v.value.map_val;
            char** keys = map_sorted_keys(m);
            StrBuf b = {0};
            buf_add(&b, "{");
            for (int i = 0; i < m->len; i++) {
                char* item = to_str(m->vals[map_find(m, keys[i])]);
                if (i > 0) buf_add(&b, ", ");
                buf_add(&b, keys[i]);
                buf_add(&b, ": ");
                buf_add(&b, item);
                fx_free(item);
            }
            buf_add(&b, "}");
            fx_free(keys);
            return b.s;
        }
        case TYPE_OBJECT: return fx_strdup("<object>");
        case TYPE_FILE: return fx_strdup("<file handle>");
        case TYPE_POINTER: {
            StrBuf b = {0};
            char* inner = to_str(*v.value.ptr_val);
            buf_add(&b, "<pointer to ");
            buf_add(&b, inner);
            buf_add(&b, ">");
            fx_free(inner);
            return b.s;
        }
        case TYPE_FUNCTION: {
            StrBuf b = {0};
            buf_add(&b, "<function ");
            buf_add(&b, v.value.fn_val.name);
            buf_add(&b, ">");
            return b.s;
        }
        case TYPE_ARRAY: {
            StrBuf b = {0};
            buf_add(&b, "[");
            for (int i = 0; i < v.value.array_val->length; i++) {
                char* item = to_str(v.value.array_val->data[i]);
                if (i > 0) buf_add(&b, ", ");
                buf_add(&b, item);
                fx_free(item);
            }
            buf_add(&b, "]");
            return b.s;
        }
    }
    return fx_strdup("?");
}

/* Tekstowa postać bez alokacji dla tekstu i liczb całkowitych; inne typy przez to_str (*owned do zwolnienia) */
static const char* str_view(FerdekValue v, char* num, size_t n, char** owned) {
    *owned = NULL;
    if (v.type == TYPE_STRING) return v.value.string_val;
    if (v.type == TYPE_INT || v.type == TYPE_BYTE || v.type == TYPE_SHORT || v.type == TYPE_FIXED) {
        snprintf(num, n, "%lld", v.value.int_val);
        return num;
    }
    return *owned = to_str(v);
}

/* + z tekstem po którejkolwiek stronie skleja - jak w interpreterze */
static FerdekValue op_add(FerdekValue a, FerdekValue b) {
    /* Szybka ścieżka: dwie liczby całkowite - ten sam wynik co ogólna, bez rozgałęzień */
    if (a.type == TYPE_INT && b.type == TYPE_INT) return make_int(iadd(a.value.int_val, b.value.int_val));
    if (a.type == TYPE_STRING || b.type == TYPE_STRING) {
        char na[32], nb[32];
        char *oa, *ob;
        const char* x = str_view(a, na, sizeof na, &oa);
        const char* y = str_view(b, nb, sizeof nb, &ob);
        size_t lx = strlen(x), ly = strlen(y);
        char* s = fx_malloc(lx + ly + 1);
        memcpy(s, x, lx);
        memcpy(s + lx, y, ly + 1);
        fx_free(oa);
        fx_free(ob);
        FerdekValue v;
        v.type = TYPE_STRING;
        v.value.string_val = s;
        return v;
    }
    if (a.type == TYPE_FLOAT || b.type == TYPE_FLOAT) return make_float(to_float(a) + to_float(b));
    return make_int(iadd(to_int(a), to_int(b)));
}
#define ANY_FLOAT(a, b) ((a).type == TYPE_FLOAT || (b).type == TYPE_FLOAT)

static FerdekValue op_sub(FerdekValue a, FerdekValue b) {
    if (a.type == TYPE_INT && b.type == TYPE_INT) return make_int(isub(a.value.int_val, b.value.int_val));
    return ANY_FLOAT(a, b) ? make_float(to_float(a) - to_float(b)) : make_int(isub(to_int(a), to_int(b)));
}

static FerdekValue op_mul(FerdekValue a, FerdekValue b) {
    if (a.type == TYPE_INT && b.type == TYPE_INT) return make_int(imul(a.value.int_val, b.value.int_val));
    return ANY_FLOAT(a, b) ? make_float(to_float(a) * to_float(b)) : make_int(imul(to_int(a), to_int(b)));
}

static FerdekValue op_div(FerdekValue a, FerdekValue b) {
    if (ANY_FLOAT(a, b)) {
        double d = to_float(b);
        if (d == 0.0) ferdek_die("Dzielenie przez zero");
        return make_float(to_float(a) / d);
    }
    return make_int(int_div(to_int(a), to_int(b)));
}

/* Dzielenie liczb całkowitych bez opakowania - te same komunikaty co op_div/op_mod */

static inline double float_div(double a, double b) {
    if (b == 0.0) ferdek_die("Dzielenie przez zero");
    return a / b;
}
static inline double float_mod(double a, double b) {
    if (b == 0.0) ferdek_die("Reszta z dzielenia przez zero");
    return fmod(a, b);
}
static inline int fcmp(double x, double y) { return (x > y) - (x < y); }

static FerdekValue op_mod(FerdekValue a, FerdekValue b) {
    if (ANY_FLOAT(a, b)) {
        double d = to_float(b);
        if (d == 0.0) ferdek_die("Reszta z dzielenia przez zero");
        return make_float(fmod(to_float(a), d));
    }
    return make_int(int_mod(to_int(a), to_int(b)));
}

/* Jak w interpreterze: tekst z tekstem porównujemy jako tekst; tekst z liczbą
   przy ==/!= jest różny, przy >/< to błąd (chyba że tekst jest liczbą) */
enum { CMP_EQ, CMP_NE, CMP_GT, CMP_LT, CMP_GE };

/* Trójwartościowe porównanie - jak compare_values w interpreterze */
static int compare3(FerdekValue a, FerdekValue b, bool equality) {
    if (a.type == TYPE_STRING && b.type == TYPE_STRING) {
        int c = strcmp(a.value.string_val, b.value.string_val);
        return (c > 0) - (c < 0);
    }
    if (is_numeric(a) && is_numeric(b) && ANY_FLOAT(a, b)) {
        double x = to_float(a), y = to_float(b);
        return (x > y) - (x < y);
    }
    if (is_numeric(a) && is_numeric(b)) {
        long long x = to_int(a), y = to_int(b);
        return (x > y) - (x < y);
    }
    if (equality) return 1;
    ferdek_die("Nie można porównać tekstu z liczbą");
    return 0;
}

/* Porównanie od razu jako bool - w warunkach if/while bez make_bool/to_bool */
static inline bool compare_bool(FerdekValue a, FerdekValue b, int op) {
    int c;
    if (a.type == TYPE_INT && b.type == TYPE_INT) {
        long long x = a.value.int_val, y = b.value.int_val;
        c = (x > y) - (x < y);
    } else {
        c = compare3(a, b, op == CMP_EQ || op == CMP_NE);
    }
    switch (op) {
        case CMP_EQ: return c == 0;
        case CMP_NE: return c != 0;
        case CMP_GT: return c > 0;
        case CMP_LT: return c < 0;
        default: return c >= 0;
    }
}

static FerdekValue compare_op(FerdekValue a, FerdekValue b, int op) { return make_bool(compare_bool(a, b, op)); }

/* Interpreter liczy obie strony (bez short-circuit) - funkcja robi to samo */
static FerdekValue logic_and(FerdekValue a, FerdekValue b) { return make_bool(to_bool(a) && to_bool(b)); }
static FerdekValue logic_or(FerdekValue a, FerdekValue b) { return make_bool(to_bool(a) || to_bool(b)); }

/* "1 argumentu", "2 argumentów" - jak Errors.argumentow */
#define ARGUMENTOW(n) ((n) == 1 ? "argumentu" : "argumentów")

static FerdekValue make_method(FerdekValue (*call)(void*, int, FerdekValue*), const char* name, int arity, bool variadic, void* self) {
    FerdekValue v;
    v.type = TYPE_FUNCTION;
    v.value.fn_val.call = call;
    v.value.fn_val.name = name;
    v.value.fn_val.arity = arity;
    v.value.fn_val.required = arity;
    v.value.fn_val.variadic = variadic;
    v.value.fn_val.self = self;
    return v;
}

/* Kopia złapanych wartości dla lambdy (self) */
static void* copy_values(int n, FerdekValue* v) {
    FerdekValue* copy = fx_malloc(sizeof(FerdekValue) * n);
    memcpy(copy, v, sizeof(FerdekValue) * n);
    return copy;
}

/* Funkcja z wartościami domyślnymi: można ją wołać z mniejszą liczbą argumentów */
static FerdekValue with_required(FerdekValue f, int required) { f.value.fn_val.required = required; return f; }

static FerdekValue make_function(FerdekValue (*call)(void*, int, FerdekValue*), const char* name, int arity, bool variadic) {
    return make_method(call, name, arity, variadic, NULL);
}

/* name = nazwa użyta w wywołaniu (jak w komunikatach interpretera) */
static FerdekValue call_value(FerdekValue f, const char* name, int argc, FerdekValue* argv) {
    if (f.type != TYPE_FUNCTION) ferdek_die("%s to nie funkcja", name);
    if (f.value.fn_val.variadic && argc < f.value.fn_val.arity)
        ferdek_die("Funkcja %s oczekuje co najmniej %d %s, podano %d", name, f.value.fn_val.arity, ARGUMENTOW(f.value.fn_val.arity), argc);
    if (!f.value.fn_val.variadic && f.value.fn_val.required != f.value.fn_val.arity
        && (argc < f.value.fn_val.required || argc > f.value.fn_val.arity))
        ferdek_die("Funkcja %s oczekuje od %d do %d %s, podano %d", name, f.value.fn_val.required,
                   f.value.fn_val.arity, ARGUMENTOW(f.value.fn_val.arity), argc);
    if (!f.value.fn_val.variadic && f.value.fn_val.required == f.value.fn_val.arity && argc != f.value.fn_val.arity)
        ferdek_die("Funkcja %s oczekuje %d %s, podano %d", name, f.value.fn_val.arity, ARGUMENTOW(f.value.fn_val.arity), argc);
    return f.value.fn_val.call(f.value.fn_val.self, argc, argv);
}

