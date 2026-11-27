/* Grafika bez serwera X: funkcje Xlib podmienione na atrapy, sprawdzamy to, co okno
   wysłałoby na ekran (skalowanie 4x, paleta) i przeliczanie pozycji myszy. make test-graphics */
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#define XLIB_ILLEGAL_ACCESS   /* pełna definicja Display, żeby atrapa mogła podać ekran */
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

static Display fake_dpy;
static Screen fake_screen;
static Visual fake_visual;
static XImage* sent = NULL;          /* ostatni obraz z XPutImage */
static int sent_w, sent_h, puts_count, pending;
static XEvent next_event;

static int fake_destroy(XImage* im) { free(im); return 1; }
static Display* f_open(const char* n) {
    (void)n;
    fake_screen.root_depth = 24; fake_screen.root_visual = &fake_visual; fake_screen.root = 1;
    fake_dpy.nscreens = 1; fake_dpy.screens = &fake_screen;
    return &fake_dpy;
}
static XImage* f_image(int w, int h, char* data) {
    XImage* im = calloc(1, sizeof(XImage));
    im->width = w; im->height = h; im->data = data; im->f.destroy_image = fake_destroy;
    return im;
}
static int f_put(XImage* im, unsigned w, unsigned h) { sent = im; sent_w = (int)w; sent_h = (int)h; puts_count++; return 0; }
static int f_next(XEvent* e) { *e = next_event; pending = 0; return 0; }

#define XOpenDisplay(n) f_open(n)
#define XCloseDisplay(d) 0
#define XCreateWindow(d, r, x, y, w, h, b, dp, c, v, m, a) ((Window)7)
#define XDestroyWindow(d, w) 0
#define XStoreName(d, w, t) 0
#define XCreateGC(d, w, m, v) ((GC)&fake_dpy)
#define XFreeGC(d, g) 0
#define XCreateImage(d, v, dp, f, o, data, w, h, pad, bpl) f_image(w, h, data)
#define XMapWindow(d, w) 0
#define XFlush(d) 0
#define XPutImage(d, w, g, im, sx, sy, dx, dy, iw, ih) f_put(im, iw, ih)
#define XPending(d) pending
#define XNextEvent(d, e) f_next(e)
#define XLookupKeysym(e, i) ((KeySym)XK_Left)

#include "../src/graphics/graphics_x11.c"

int main(void) {
    assert(ferdek_window_open(3, 2, "t"));
    unsigned char pal[768] = {0};
    pal[5 * 3] = 0x12; pal[5 * 3 + 1] = 0x34; pal[5 * 3 + 2] = 0x56;   /* kolor 5 */
    pal[9 * 3 + 2] = 0xff;                                             /* kolor 9: niebieski */
    ferdek_palette_set(pal);
    ferdek_screen_clear(0);
    ferdek_pixel_draw(2, 1, 5);
    ferdek_pixel_draw(0, 0, 9);
    ferdek_pixel_draw(3, 0, 9);   /* poza ekranem: nic */
    ferdek_screen_refresh();

    assert(puts_count == 1 && sent_w == 12 && sent_h == 8 && sent->width == 12 && sent->height == 8);
    unsigned int* img = (unsigned int*)sent->data;
    for (int y = 0; y < 8; y++)
        for (int x = 0; x < 12; x++) {
            unsigned int want = (x / 4 == 2 && y / 4 == 1) ? 0x123456u : (x / 4 == 0 && y / 4 == 0) ? 0x0000ffu : 0;
            if (img[y * 12 + x] != want) { printf("piksel %d,%d: %06x zamiast %06x\n", x, y, img[y * 12 + x], want); return 1; }
        }

    /* klik w ekranowy (9, 5) to piksel programu (2, 1) */
    next_event.type = ButtonPress; next_event.xbutton.button = 1; next_event.xbutton.x = 9; next_event.xbutton.y = 5; pending = 1;
    ferdek_event_t ev = ferdek_event_poll();
    assert(ev.type == 3 && ev.key == 1 && ev.x == 2 && ev.y == 1);
    next_event.type = KeyPress; pending = 1;
    ev = ferdek_event_poll();
    assert(ev.type == 1 && ev.key == XK_Left);
    assert(ferdek_event_poll().type == 0);

    ferdek_window_close();
    return 0;
}
