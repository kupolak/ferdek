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

/* Linia z błędem (wbudowane źródła) i ścieżka wywołań - ten sam tekst co Sources.context */
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

/* ---- Obiekty (pola w FerdekMap) i wskaźniki ---- */

static void map_put(FerdekMap* m, const char* key, FerdekValue v) {
    int i = map_find(m, key);
    if (i >= 0) { m->vals[i] = v; return; }
    if (m->len == m->cap) {
        m->cap = m->cap ? m->cap * 2 : 8;
        m->keys = fx_realloc(m->keys, sizeof(char*) * m->cap);
        m->vals = fx_realloc(m->vals, sizeof(FerdekValue) * m->cap);
    }
    m->keys[m->len] = fx_strdup(key);
    m->vals[m->len++] = v;
}

static FerdekValue make_object(void) {
    FerdekValue v;
    v.type = TYPE_OBJECT;
    v.value.map_val = fx_calloc(1, sizeof(FerdekMap));
    return v;
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

/* t[i] i obj["pole"] - jak ArrayAccess w interpreterze */
static FerdekValue index_get(FerdekValue c, FerdekValue key) {
    if (c.type == TYPE_ARRAY) {
        long long i = to_int(key);
        if (i < 0 || i >= c.value.array_val->length) ferdek_die("Indeks tablicy poza zakresem");
        return c.value.array_val->data[i];
    }
    if (c.type == TYPE_OBJECT) {
        char* k = field_key(key);
        int i = map_find(c.value.map_val, k);
        if (i < 0) ferdek_die("Obiekt nie ma pola: %s", k);
        return c.value.map_val->vals[i];
    }
    ferdek_die("To nie jest tablica ani obiekt");
    return make_null();
}

/* t[i] = v i obj["pole"] = v - jak ArrayAssign w interpreterze (indeks tablicy tylko DŁUGI) */
static void index_set(FerdekValue c, FerdekValue key, FerdekValue v) {
    if (c.type == TYPE_ARRAY && key.type == TYPE_INT) {
        long long i = key.value.int_val;
        if (i < 0 || i >= c.value.array_val->length) ferdek_die("Indeks poza zakresem: %lld", i);
        c.value.array_val->data[i] = v;
    } else if (c.type == TYPE_OBJECT && (key.type == TYPE_STRING || key.type == TYPE_INT)) {
        map_put(c.value.map_val, field_key(key), v);
    } else if (key.type == TYPE_INT) {
        ferdek_die("To nie jest tablica ani obiekt");
    } else {
        ferdek_die("Indeks tablicy musi być liczbą całkowitą");
    }
}

/* t[i] z indeksem, o którym kompilator wie, że jest liczbą całkowitą - bez pakowania indeksu */
static inline FerdekValue index_get_i(FerdekValue c, long long i) {
    if (c.type == TYPE_ARRAY) {
        if (i < 0 || i >= c.value.array_val->length) ferdek_die("Indeks tablicy poza zakresem");
        return c.value.array_val->data[i];
    }
    return index_get(c, make_int(i));
}
static inline void index_set_i(FerdekValue c, long long i, FerdekValue v) {
    if (c.type == TYPE_ARRAY) {
        if (i < 0 || i >= c.value.array_val->length) ferdek_die("Indeks poza zakresem: %lld", i);
        c.value.array_val->data[i] = v;
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
    if (m->len == m->cap) {
        m->cap = m->cap ? m->cap * 2 : 8;
        m->keys = fx_realloc(m->keys, sizeof(char*) * m->cap);
        m->vals = fx_realloc(m->vals, sizeof(FerdekValue) * m->cap);
    }
    m->keys[m->len] = key;
    m->vals[m->len++] = argv[2];
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
    if (i >= 0) {
        fx_free(m->keys[i]);
        m->keys[i] = m->keys[m->len - 1];   /* kolejność w środku bez znaczenia - wypisujemy posortowane */
        m->vals[i] = m->vals[m->len - 1];
        m->len--;
    }
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

/* ---- KALENDARZ: dni od 1970-01-01, ten sam algorytm co w interpreterze ---- */
static long long days_from_civil(long long y, long long m, long long d) {
    y -= m <= 2;
    long long era = (y >= 0 ? y : y - 399) / 400;
    long long yoe = y - era * 400;
    long long doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1;
    long long doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + doe - 719468;
}
static void civil_from_days(long long z, long long* y, long long* m, long long* d) {
    z += 719468;
    long long era = (z >= 0 ? z : z - 146096) / 146097;
    long long doe = z - era * 146097;
    long long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    long long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    long long mp = (5 * doy + 2) / 153;
    *d = doy - (153 * mp + 2) / 5 + 1;
    *m = mp < 10 ? mp + 3 : mp - 9;
    *y = yoe + era * 400 + (*m <= 2);
}
static int days_in_month(long long y, long long m) {
    if (m == 2) return ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0) ? 29 : 28;
    return (m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31;
}
static long long parse_date(const char* what, FerdekValue v) {
    char* s = to_str(v);
    int ok = strlen(s) == 10 && s[4] == '-' && s[7] == '-';
    for (int i = 0; ok && i < 10; i++) if (i != 4 && i != 7 && (s[i] < '0' || s[i] > '9')) ok = 0;
    long long y = 0, m = 0, d = 0;
    if (ok) {
        y = (s[0] - '0') * 1000 + (s[1] - '0') * 100 + (s[2] - '0') * 10 + (s[3] - '0');
        m = (s[5] - '0') * 10 + (s[6] - '0');
        d = (s[8] - '0') * 10 + (s[9] - '0');
        ok = y >= 1 && m >= 1 && m <= 12 && d >= 1 && d <= days_in_month(y, m);
    }
    if (!ok) ferdek_die("%s: zła data \"%s\" (ma być RRRR-MM-DD)", what, s);
    fx_free(s);
    return days_from_civil(y, m, d);
}
static FerdekValue format_date(const char* what, long long z) {
    long long y, m, d;
    civil_from_days(z, &y, &m, &d);
    if (y < 1 || y > 9999) ferdek_die("%s: wynik poza latami 1-9999", what);
    char buf[16];
    snprintf(buf, sizeof buf, "%04lld-%02lld-%02lld", y, m, d);
    return make_string(buf);
}
static FerdekValue b_dzis(int argc, FerdekValue* argv) {
    time_t now = time(NULL); struct tm t; localtime_r(&now, &t);
    char buf[16]; snprintf(buf, sizeof buf, "%04d-%02d-%02d", t.tm_year + 1900, t.tm_mon + 1, t.tm_mday);
    return make_string(buf);
}
static FerdekValue b_godzina(int argc, FerdekValue* argv) {
    time_t now = time(NULL); struct tm t; localtime_r(&now, &t);
    char buf[16]; snprintf(buf, sizeof buf, "%02d:%02d:%02d", t.tm_hour, t.tm_min, t.tm_sec);
    return make_string(buf);
}
static FerdekValue b_dzien_tygodnia(int argc, FerdekValue* argv) {
    static const char* names[] = { "poniedziałek", "wtorek", "środa", "czwartek", "piątek", "sobota", "niedziela" };
    long long z = parse_date("DZIEŃ TYGODNIA", argv[0]);
    return make_lit(names[((z % 7) + 7 + 3) % 7]);
}
static FerdekValue b_dodaj_dni(int argc, FerdekValue* argv) {
    return format_date("DODAJ DNI", iadd(parse_date("DODAJ DNI", argv[0]), to_int(argv[1])));
}
static FerdekValue b_ile_dni(int argc, FerdekValue* argv) {
    return make_int(parse_date("ILE DNI MIĘDZY", argv[1]) - parse_date("ILE DNI MIĘDZY", argv[0]));
}

/* ---- SŁOIK: JSON - te same zasady co Sloik w interpreterze ---- */
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

/* ---- Alokator strefowy (DAJ MI HAJS): bloki wartości, wskaźnik = wskaźnik na numer bloku ---- */

typedef struct { long long size; int tag; FerdekValue* data; bool alive; } ZoneBlock;
static ZoneBlock* zone = NULL;
static long long zone_count = 0, zone_allocated = 0, zone_freed = 0;

static int int_to_tag(long long n) { return n <= 1 ? 1 : (n <= 50 ? 50 : 100); }

/* Blok spod wskaźnika; komunikaty zależą od funkcji, jak w interpreterze */
static ZoneBlock* block_arg(FerdekValue p, const char* not_ptr, const char* bad_ptr, const char* no_block) {
    if (p.type != TYPE_POINTER) ferdek_die("%s", not_ptr);
    if (p.value.ptr_val->type != TYPE_INT) ferdek_die("%s", bad_ptr);
    long long id = p.value.ptr_val->value.int_val;
    if (id < 0 || id >= zone_count || !zone[id].alive) ferdek_die("%s", no_block);
    return &zone[id];
}

static FerdekValue b_daj_hajs(int argc, FerdekValue* argv) {
    long long size = to_int(argv[0]), tag = to_int(argv[1]);
    if (size <= 0) ferdek_die("DAJ MI HAJS: rozmiar musi być dodatni");
    zone = fx_realloc(zone, sizeof(ZoneBlock) * (zone_count + 1));
    ZoneBlock* b = &zone[zone_count];
    b->size = size;
    b->tag = int_to_tag(tag);
    b->data = fx_malloc(sizeof(FerdekValue) * size);
    for (long long i = 0; i < size; i++) b->data[i] = make_null();
    b->alive = true;
    zone_allocated += size;
    return make_pointer(make_int(zone_count++));
}

static FerdekValue b_oddaj_wszystko(int argc, FerdekValue* argv) {
    ZoneBlock* b = block_arg(argv[0], "ODDAJ WSZYSTKO: argument musi być wskaźnikiem",
                             "ODDAJ WSZYSTKO: nieprawidłowy wskaźnik", "ODDAJ WSZYSTKO: blok nie istnieje");
    zone_freed += b->size;
    b->alive = false;
    return make_null();
}

static FerdekValue b_komornik(int argc, FerdekValue* argv) {
    long long lo = to_int(argv[0]), hi = to_int(argv[1]), freed = 0;
    for (long long i = 0; i < zone_count; i++)
        if (zone[i].alive && zone[i].tag >= lo && zone[i].tag <= hi) {
            zone_freed += zone[i].size;
            zone[i].alive = false;
            freed++;
        }
    return make_int(freed);
}

static FerdekValue b_zapisz_blok(int argc, FerdekValue* argv) {
    long long i = to_int(argv[1]);
    ZoneBlock* b = block_arg(argv[0], "ZAPISZ DO BLOKU: pierwszy argument musi być wskaźnikiem",
                             "ZAPISZ DO BLOKU: nieprawidłowy wskaźnik", "ZAPISZ DO BLOKU: blok nie istnieje");
    if (i < 0 || i >= b->size) ferdek_die("ZAPISZ DO BLOKU: indeks %lld poza zakresem (rozmiar: %lld)", i, b->size);
    b->data[i] = argv[2];
    return make_null();
}

static FerdekValue b_czytaj_blok(int argc, FerdekValue* argv) {
    long long i = to_int(argv[1]);
    ZoneBlock* b = block_arg(argv[0], "CZYTAJ Z BLOKU: pierwszy argument musi być wskaźnikiem",
                             "CZYTAJ Z BLOKU: nieprawidłowy wskaźnik", "CZYTAJ Z BLOKU: blok nie istnieje");
    if (i < 0 || i >= b->size) ferdek_die("CZYTAJ Z BLOKU: indeks %lld poza zakresem (rozmiar: %lld)", i, b->size);
    return b->data[i];
}

static FerdekValue b_rozmiar_bloku(int argc, FerdekValue* argv) {
    return make_int(block_arg(argv[0], "ROZMIAR BLOKU: argument musi być wskaźnikiem",
                              "ROZMIAR BLOKU: nieprawidłowy wskaźnik", "ROZMIAR BLOKU: blok nie istnieje")->size);
}

static FerdekValue b_ile_kasy(int argc, FerdekValue* argv) {
    long long blocks = 0;
    for (long long i = 0; i < zone_count; i++) blocks += zone[i].alive;
    FerdekValue m = b_szafka_otworz(0, NULL);
    map_put(m.value.map_val, "allocated", make_int(zone_allocated));
    map_put(m.value.map_val, "freed", make_int(zone_freed));
    map_put(m.value.map_val, "current", make_int(zone_allocated - zone_freed));
    map_put(m.value.map_val, "blocks", make_int(blocks));
    return m;
}

static FerdekValue b_tag_trwale(int argc, FerdekValue* argv) { return make_int(1); }
static FerdekValue b_tag_poziom(int argc, FerdekValue* argv) { return make_int(50); }
static FerdekValue b_tag_smieciowe(int argc, FerdekValue* argv) { return make_int(100); }

static FerdekValue b_pisz_bajt(int argc, FerdekValue* argv) {
    long long off = to_int(argv[1]), val = to_int(argv[2]);
    ZoneBlock* b = block_arg(argv[0], "PISZ BAJT: pierwszy argument musi być wskaźnikiem",
                             "PISZ BAJT: pierwszy argument musi być wskaźnikiem", "PISZ BAJT: nieprawidłowy blok pamięci");
    if (off < 0 || off >= b->size) ferdek_die("PISZ BAJT: przesunięcie poza zakresem");
    b->data[off] = make_int(val);
    return make_null();
}

static FerdekValue b_czytaj_bajt(int argc, FerdekValue* argv) {
    long long off = to_int(argv[1]);
    ZoneBlock* b = block_arg(argv[0], "CZYTAJ BAJT: pierwszy argument musi być wskaźnikiem",
                             "CZYTAJ BAJT: pierwszy argument musi być wskaźnikiem", "CZYTAJ BAJT: nieprawidłowy blok pamięci");
    if (off < 0 || off >= b->size) ferdek_die("CZYTAJ BAJT: przesunięcie poza zakresem");
    return b->data[off];
}

static FerdekValue b_kopiuj_pamiec(int argc, FerdekValue* argv) {
    long long size = to_int(argv[2]);
    if (argv[0].type != TYPE_POINTER || argv[1].type != TYPE_POINTER ||
        argv[0].value.ptr_val->type != TYPE_INT || argv[1].value.ptr_val->type != TYPE_INT)
        ferdek_die("KOPIUJ PAMIĘĆ: argumenty muszą być wskaźnikami");
    long long s = argv[0].value.ptr_val->value.int_val, d = argv[1].value.ptr_val->value.int_val;
    if (s < 0 || s >= zone_count || !zone[s].alive || d < 0 || d >= zone_count || !zone[d].alive)
        ferdek_die("KOPIUJ PAMIĘĆ: nieprawidłowe bloki pamięci");
    if (size > zone[s].size || size > zone[d].size) ferdek_die("KOPIUJ PAMIĘĆ: rozmiar większy niż blok");
    memmove(zone[d].data, zone[s].data, sizeof(FerdekValue) * size);
    return make_null();
}

/* ---- TELEWIZOR (framebuffer w pamięci) i tablice wyszukiwania ---- */

typedef struct { long long w, h; long long* px; bool alive; } FerdekScreen;
static FerdekScreen* screens = NULL;
static long long screen_count = 0;

static FerdekScreen* screen_arg(FerdekValue p, const char* not_ptr, const char* bad) {
    if (p.type != TYPE_POINTER || p.value.ptr_val->type != TYPE_INT) ferdek_die("%s", not_ptr);
    long long id = p.value.ptr_val->value.int_val;
    if (id < 0 || id >= screen_count || !screens[id].alive) ferdek_die("%s", bad);
    return &screens[id];
}

static FerdekValue b_wlacz_tv(int argc, FerdekValue* argv) {
    long long w = to_int(argv[0]), h = to_int(argv[1]);
    if (w <= 0 || h <= 0) ferdek_die("WŁĄCZ TELEWIZOR: szerokość i wysokość muszą być dodatnie");
    screens = fx_realloc(screens, sizeof(FerdekScreen) * (screen_count + 1));
    screens[screen_count] = (FerdekScreen){ w, h, fx_calloc(w * h, sizeof(long long)), true };
    return make_pointer(make_int(screen_count++));
}

static FerdekValue b_wylacz_tv(int argc, FerdekValue* argv) {
    screen_arg(argv[0], "WYŁĄCZ TELEWIZOR: argument musi być wskaźnikiem na ekran",
               "WYŁĄCZ TELEWIZOR: nieprawidłowy ekran")->alive = false;
    return make_null();
}

static FerdekValue b_zmien_kanal(int argc, FerdekValue* argv) {
    long long x = to_int(argv[1]), y = to_int(argv[2]), c = to_int(argv[3]);
    FerdekScreen* s = screen_arg(argv[0], "ZMIEŃ KANAŁ: pierwszy argument musi być wskaźnikiem na ekran",
                           "ZMIEŃ KANAŁ: nieprawidłowy ekran");
    if (x < 0 || x >= s->w || y < 0 || y >= s->h) ferdek_die("ZMIEŃ KANAŁ: piksel poza ekranem");
    s->px[y * s->w + x] = c;
    return make_null();
}

static FerdekValue b_co_leci(int argc, FerdekValue* argv) {
    long long x = to_int(argv[1]), y = to_int(argv[2]);
    FerdekScreen* s = screen_arg(argv[0], "CO LECI W TELEWIZORZE: pierwszy argument musi być wskaźnikiem na ekran",
                           "CO LECI W TELEWIZORZE: nieprawidłowy ekran");
    if (x < 0 || x >= s->w || y < 0 || y >= s->h) ferdek_die("CO LECI W TELEWIZORZE: piksel poza ekranem");
    return make_int(s->px[y * s->w + x]);
}

typedef struct { long long size; long long* data; } Lookup;
static Lookup* lookups = NULL;
static long long lookup_count = 0;

static Lookup* lookup_arg(FerdekValue p, const char* not_ptr, const char* bad) {
    if (p.type != TYPE_POINTER || p.value.ptr_val->type != TYPE_INT) ferdek_die("%s", not_ptr);
    long long id = p.value.ptr_val->value.int_val;
    if (id < 0 || id >= lookup_count) ferdek_die("%s", bad);
    return &lookups[id];
}

static FerdekValue b_stworz_tabele(int argc, FerdekValue* argv) {
    long long size = to_int(argv[0]);
    if (size <= 0) ferdek_die("STWÓRZ TABELĘ: rozmiar musi być dodatni");
    lookups = fx_realloc(lookups, sizeof(Lookup) * (lookup_count + 1));
    lookups[lookup_count] = (Lookup){ size, fx_calloc(size, sizeof(long long)) };
    return make_pointer(make_int(lookup_count++));
}

static FerdekValue b_wpisz_tabela(int argc, FerdekValue* argv) {
    long long i = to_int(argv[1]), v = to_int(argv[2]);
    Lookup* t = lookup_arg(argv[0], "WPISZ DO TABELI: pierwszy argument musi być wskaźnikiem na tabelę",
                           "WPISZ DO TABELI: nieprawidłowa tabela");
    if (i < 0 || i >= t->size) ferdek_die("WPISZ DO TABELI: indeks poza zakresem");
    t->data[i] = v;
    return make_null();
}

static FerdekValue b_sprawdz_tabela(int argc, FerdekValue* argv) {
    long long i = to_int(argv[1]);
    Lookup* t = lookup_arg(argv[0], "SPRAWDŹ W TABELI: pierwszy argument musi być wskaźnikiem na tabelę",
                           "SPRAWDŹ W TABELI: nieprawidłowa tabela");
    if (i < 0 || i >= t->size) ferdek_die("SPRAWDŹ W TABELI: indeks poza zakresem");
    return make_int(t->data[i]);
}

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

static FerdekValue read_value(void) {
    char buffer[1024];
    if (fgets(buffer, sizeof(buffer), stdin) == NULL) return make_null();
    buffer[strcspn(buffer, "\n")] = 0;
    return is_decimal(buffer) ? make_int(strtoll(buffer, NULL, 10)) : make_string(buffer);
}
