/*
 * graphics_stubs.c - OCaml bindings for X11 graphics
 */

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>
#include "graphics_x11.h"

/* OKNO_OTWORZ */
CAMLprim value caml_ferdek_window_open(value width, value height, value title) {
    CAMLparam3(width, height, title);
    int result = ferdek_window_open(Int_val(width), Int_val(height), String_val(title));
    CAMLreturn(Val_int(result));
}

/* OKNO_ZAMKNIJ */
CAMLprim value caml_ferdek_window_close(value unit) {
    CAMLparam1(unit);
    ferdek_window_close();
    CAMLreturn(Val_unit);
}

/* PALETA_USTAW */
CAMLprim value caml_ferdek_palette_set(value palette) {
    CAMLparam1(palette);
    /* palette should be a byte array of length 768 */
    ferdek_palette_set((unsigned char*)String_val(palette));
    CAMLreturn(Val_unit);
}

/* PIKSEL_MALUJ */
CAMLprim value caml_ferdek_pixel_draw(value x, value y, value color) {
    CAMLparam3(x, y, color);
    ferdek_pixel_draw(Int_val(x), Int_val(y), Int_val(color));
    CAMLreturn(Val_unit);
}

/* EKRAN_ODŚWIEŻ */
CAMLprim value caml_ferdek_screen_refresh(value unit) {
    CAMLparam1(unit);
    ferdek_screen_refresh();
    CAMLreturn(Val_unit);
}

/* EKRAN_CZYŚĆ */
CAMLprim value caml_ferdek_screen_clear(value color) {
    CAMLparam1(color);
    ferdek_screen_clear(Int_val(color));
    CAMLreturn(Val_unit);
}

/* BUFOR_RAMKI_POBIERZ */
CAMLprim value caml_ferdek_framebuffer_get(value x, value y) {
    CAMLparam2(x, y);
    unsigned char pixel = ferdek_framebuffer_get(Int_val(x), Int_val(y));
    CAMLreturn(Val_int(pixel));
}

/* ZDARZENIE_CZEKAJ */
CAMLprim value caml_ferdek_event_poll(value unit) {
    CAMLparam1(unit);
    CAMLlocal1(result);

    ferdek_event_t ev = ferdek_event_poll();

    /* Return tuple: (type, key, x, y) */
    result = caml_alloc_tuple(4);
    Store_field(result, 0, Val_int(ev.type));
    Store_field(result, 1, Val_int(ev.key));
    Store_field(result, 2, Val_int(ev.x));
    Store_field(result, 3, Val_int(ev.y));

    CAMLreturn(result);
}
