static FerdekValue gfx_okno_otworz(int argc, FerdekValue* argv) {
    int r = ferdek_window_open((int)to_int(argv[0]), (int)to_int(argv[1]), to_str(argv[2]));
    if (r == 0) ferdek_die("OKNO_OTWORZ: nie udało się otworzyć okna");
    return make_int(r);
}
static FerdekValue gfx_okno_zamknij(int argc, FerdekValue* argv) { ferdek_window_close(); return make_null(); }
static FerdekValue gfx_paleta_ustaw(int argc, FerdekValue* argv) {
    if (argv[0].type != TYPE_ARRAY) ferdek_die("PALETA_USTAW: argument musi być tablicą");
    FerdekArray* a = argv[0].value.array_val;
    if (a->length != 768) ferdek_die("PALETA_USTAW: paleta musi mieć 768 bajtów (256 kolorów * RGB)");
    unsigned char pal[768];
    for (int i = 0; i < 768; i++) pal[i] = (unsigned char)(to_int(a->data[i]) & 0xFF);
    ferdek_palette_set(pal);
    return make_null();
}
static FerdekValue gfx_piksel_maluj(int argc, FerdekValue* argv) {
    ferdek_pixel_draw((int)to_int(argv[0]), (int)to_int(argv[1]), (unsigned char)(to_int(argv[2]) & 0xFF));
    return make_null();
}
static FerdekValue gfx_ekran_odswiez(int argc, FerdekValue* argv) { ferdek_screen_refresh(); return make_null(); }
static FerdekValue gfx_ekran_czysc(int argc, FerdekValue* argv) {
    ferdek_screen_clear((unsigned char)(to_int(argv[0]) & 0xFF));
    return make_null();
}
static FerdekValue gfx_bufor_pobierz(int argc, FerdekValue* argv) {
    return make_int(ferdek_framebuffer_get((int)to_int(argv[0]), (int)to_int(argv[1])));
}
static FerdekValue gfx_zdarzenie(int argc, FerdekValue* argv) {
    ferdek_event_t e = ferdek_event_poll();
    return make_array((FerdekValue[]){ make_int(e.type), make_int(e.key), make_int(e.x), make_int(e.y) }, 4);
}
