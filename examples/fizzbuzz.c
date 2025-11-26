#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>


/* Ferdek Runtime Library */

typedef enum {
    TYPE_INT,
    TYPE_STRING,
    TYPE_BOOL,
    TYPE_NULL,
    TYPE_ARRAY
} ValueType;

typedef struct FerdekValue FerdekValue;

struct FerdekValue {
    ValueType type;
    union {
        int int_val;
        char* string_val;
        bool bool_val;
        struct {
            FerdekValue* data;
            int length;
        } array_val;
    } value;
};

/* Constructor functions */
FerdekValue make_int(int n) {
    FerdekValue v;
    v.type = TYPE_INT;
    v.value.int_val = n;
    return v;
}

FerdekValue make_string(const char* s) {
    FerdekValue v;
    v.type = TYPE_STRING;
    v.value.string_val = strdup(s);
    return v;
}

FerdekValue make_bool(bool b) {
    FerdekValue v;
    v.type = TYPE_BOOL;
    v.value.bool_val = b;
    return v;
}

FerdekValue make_null() {
    FerdekValue v;
    v.type = TYPE_NULL;
    return v;
}

FerdekValue make_array(FerdekValue* data, int length) {
    FerdekValue v;
    v.type = TYPE_ARRAY;
    v.value.array_val.data = malloc(sizeof(FerdekValue) * length);
    memcpy(v.value.array_val.data, data, sizeof(FerdekValue) * length);
    v.value.array_val.length = length;
    return v;
}

/* Type conversion functions */
int to_int(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: return v.value.int_val;
        case TYPE_BOOL: return v.value.bool_val ? 1 : 0;
        case TYPE_STRING: return atoi(v.value.string_val);
        default: return 0;
    }
}

bool to_bool(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT: return v.value.int_val != 0;
        case TYPE_BOOL: return v.value.bool_val;
        case TYPE_STRING: return strlen(v.value.string_val) > 0;
        case TYPE_NULL: return false;
        default: return true;
    }
}

/* Array operations */
FerdekValue array_get(FerdekValue arr, int index) {
    if (arr.type != TYPE_ARRAY) {
        fprintf(stderr, "Error: Not an array\n");
        exit(1);
    }
    if (index < 0 || index >= arr.value.array_val.length) {
        fprintf(stderr, "Error: Array index out of bounds\n");
        exit(1);
    }
    return arr.value.array_val.data[index];
}

/* I/O functions */
void print_value(FerdekValue v) {
    switch (v.type) {
        case TYPE_INT:
            printf("%d\n", v.value.int_val);
            break;
        case TYPE_STRING:
            printf("%s\n", v.value.string_val);
            break;
        case TYPE_BOOL:
            printf("%s\n", v.value.bool_val ? "true" : "false");
            break;
        case TYPE_NULL:
            printf("null\n");
            break;
        case TYPE_ARRAY:
            printf("[array]\n");
            break;
    }
}

FerdekValue read_value() {
    char buffer[1024];
    if (fgets(buffer, sizeof(buffer), stdin) != NULL) {
        buffer[strcspn(buffer, "\n")] = 0;
        int n;
        if (sscanf(buffer, "%d", &n) == 1) {
            return make_int(n);
        }
        return make_string(buffer);
    }
    return make_null();
}






int main() {
    print_value(make_string("=== FizzBuzz ==="));
    FerdekValue i = make_int(1);
    while (to_bool(make_bool(to_int(i) < to_int(make_int(16))))) {
        FerdekValue mod15 = make_int(0);
        mod15 = make_int(to_int(i) % to_int(make_int(15)));
        if (to_bool(make_bool(to_int(mod15) == to_int(make_int(0))))) {
            print_value(make_string("FizzBuzz"));
        } else {
            FerdekValue mod3 = make_int(0);
            mod3 = make_int(to_int(i) % to_int(make_int(3)));
            if (to_bool(make_bool(to_int(mod3) == to_int(make_int(0))))) {
                print_value(make_string("Fizz"));
            } else {
                FerdekValue mod5 = make_int(0);
                mod5 = make_int(to_int(i) % to_int(make_int(5)));
                if (to_bool(make_bool(to_int(mod5) == to_int(make_int(0))))) {
                    print_value(make_string("Buzz"));
                } else {
                    print_value(i);
                }
            }
        }
        i = make_int(to_int(i) + to_int(make_int(1)));
    }
    return 0;
}
