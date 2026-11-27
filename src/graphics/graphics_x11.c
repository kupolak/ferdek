/*
 * graphics_x11.c - X11 Graphics for Ferdek
 * Real X11 implementation with XQuartz support
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

/* FERDEK_X11_DLOPEN (tak budowana jest komenda ferdek): libX11 jest szukana dopiero przy
   otwarciu okna, więc ferdek działa też tam, gdzie X11 nie ma. Skompilowane programy
   z grafiką linkują -lX11 zwyczajnie. Nowa funkcja X11 w tym pliku = dopisać ją do obu list. */
#ifdef FERDEK_X11_DLOPEN
#include <dlfcn.h>
#define FERDEK_X11_FUNCS(F) F(XOpenDisplay) F(XCloseDisplay) F(XCreateWindow) F(XDestroyWindow) F(XStoreName) F(XCreateGC) F(XFreeGC) F(XCreateImage) F(XMapWindow) F(XFlush) F(XSetForeground) F(XFillRectangle) F(XPending) F(XNextEvent) F(XLookupKeysym)
#define F(n) static __typeof__(n)* p_##n;
FERDEK_X11_FUNCS(F)
#undef F
static int ferdek_x11_load(void) {
    static int loaded = 0;
    if (loaded) return 1;
    const char* names[] = {"libX11.so.6", "libX11.6.dylib", "/opt/X11/lib/libX11.6.dylib",
                           "/opt/homebrew/lib/libX11.6.dylib", "/usr/local/lib/libX11.6.dylib", NULL};
    void* h = NULL;
    for (int i = 0; names[i] && !h; i++) h = dlopen(names[i], RTLD_NOW | RTLD_GLOBAL);
    if (!h) return 0;
#define F(n) if (!(p_##n = (__typeof__(n)*)dlsym(h, #n))) return 0;
    FERDEK_X11_FUNCS(F)
#undef F
    return loaded = 1;
}
#define XOpenDisplay p_XOpenDisplay
#define XCloseDisplay p_XCloseDisplay
#define XCreateWindow p_XCreateWindow
#define XDestroyWindow p_XDestroyWindow
#define XStoreName p_XStoreName
#define XCreateGC p_XCreateGC
#define XFreeGC p_XFreeGC
#define XCreateImage p_XCreateImage
#define XMapWindow p_XMapWindow
#define XFlush p_XFlush
#define XSetForeground p_XSetForeground
#define XFillRectangle p_XFillRectangle
#define XPending p_XPending
#define XNextEvent p_XNextEvent
#define XLookupKeysym p_XLookupKeysym
#endif

/* Key event structure */
typedef struct {
    int type;     /* 0=none, 1=keydown, 2=keyup, 3=mouse, 4=quit */
    int key;      /* keycode or mouse button */
    int x, y;     /* mouse position */
} ferdek_event_t;

/* Global X11 state */
static Display* display = NULL;
static Window window = 0;
static GC gc = 0;
static XImage* ximage = NULL;
static unsigned char* framebuffer = NULL;
static int fb_width = 0;
static int fb_height = 0;
static unsigned long palette[256];

/* Default DOOM-style palette (256 colors) */
static void init_default_palette(void) {
    /* Simple grayscale palette for now */
    for (int i = 0; i < 256; i++) {
        unsigned long r = i;
        unsigned long g = i;
        unsigned long b = i;
        palette[i] = (r << 16) | (g << 8) | b;
    }
}

/*
 * OKNO_OTWORZ - Open X11 window
 */
int ferdek_window_open(int width, int height, const char* title) {
#ifdef FERDEK_X11_DLOPEN
    if (!ferdek_x11_load()) {
        fprintf(stderr, "Nie ma biblioteki X11 (libX11). macOS: zainstaluj XQuartz, Linux: pakiet libx11-6\n");
        return 0;
    }
#endif
    /* Open display */
    display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "Nie można otworzyć X11 display! Czy XQuartz działa?\n");
        return 0;
    }

    int screen = DefaultScreen(display);
    Window root = RootWindow(display, screen);

    /* Create window */
    XSetWindowAttributes attrs;
    attrs.background_pixel = BlackPixel(display, screen);
    attrs.event_mask = ExposureMask | KeyPressMask | KeyReleaseMask |
                       ButtonPressMask | PointerMotionMask | StructureNotifyMask;

    window = XCreateWindow(
        display, root,
        0, 0, width * 4, height * 4,  /* Scale 4x for visibility */
        0,
        CopyFromParent,
        InputOutput,
        CopyFromParent,
        CWBackPixel | CWEventMask,
        &attrs
    );

    if (!window) {
        XCloseDisplay(display);
        return 0;
    }

    /* Set window title */
    XStoreName(display, window, title);

    /* Create graphics context */
    gc = XCreateGC(display, window, 0, NULL);

    /* Allocate framebuffer */
    fb_width = width;
    fb_height = height;
    framebuffer = (unsigned char*)calloc(width * height, 1);
    if (!framebuffer) {
        XFreeGC(display, gc);
        XDestroyWindow(display, window);
        XCloseDisplay(display);
        return 0;
    }

    /* Create XImage for framebuffer */
    int depth = DefaultDepth(display, screen);
    Visual* visual = DefaultVisual(display, screen);

    ximage = XCreateImage(
        display, visual, depth,
        ZPixmap, 0,
        (char*)malloc(width * height * 4),
        width, height,
        32, 0
    );

    if (!ximage) {
        free(framebuffer);
        XFreeGC(display, gc);
        XDestroyWindow(display, window);
        XCloseDisplay(display);
        return 0;
    }

    /* Initialize default palette */
    init_default_palette();

    /* Show window */
    XMapWindow(display, window);
    XFlush(display);

    printf("X11 window opened: %dx%d '%s'\n", width, height, title);
    return 1;
}

/*
 * PALETA_USTAW - Set color palette
 */
void ferdek_palette_set(const unsigned char* pal) {
    if (!pal) return;

    /* Convert RGB triplets to X11 colors */
    for (int i = 0; i < 256; i++) {
        unsigned long r = pal[i * 3 + 0];
        unsigned long g = pal[i * 3 + 1];
        unsigned long b = pal[i * 3 + 2];
        palette[i] = (r << 16) | (g << 8) | b;
    }
}

/*
 * PIKSEL_MALUJ - Draw pixel to framebuffer
 */
void ferdek_pixel_draw(int x, int y, unsigned char color) {
    if (!framebuffer || x < 0 || x >= fb_width || y < 0 || y >= fb_height) {
        return;
    }
    framebuffer[y * fb_width + x] = color;
}

/*
 * EKRAN_ODSWIEZ - Refresh screen (blit framebuffer to X11)
 */
void ferdek_screen_refresh(void) {
    if (!display || !window || !framebuffer || !ximage) return;

    /* Convert 8-bit framebuffer to 32-bit X11 image */
    unsigned int* img_data = (unsigned int*)ximage->data;
    for (int i = 0; i < fb_width * fb_height; i++) {
        img_data[i] = palette[framebuffer[i]];
    }

    /* Draw scaled image (4x scale for visibility) */
    for (int sy = 0; sy < fb_height; sy++) {
        for (int sx = 0; sx < fb_width; sx++) {
            unsigned long color = palette[framebuffer[sy * fb_width + sx]];
            XSetForeground(display, gc, color);
            XFillRectangle(display, window, gc, sx * 4, sy * 4, 4, 4);
        }
    }

    XFlush(display);
}

/*
 * ZDARZENIE_CZEKAJ - Poll for X11 events
 */
ferdek_event_t ferdek_event_poll(void) {
    ferdek_event_t ev = {0, 0, 0, 0};

    if (!display) return ev;

    while (XPending(display)) {
        XEvent xev;
        XNextEvent(display, &xev);

        switch (xev.type) {
            case KeyPress:
                ev.type = 1;
                ev.key = XLookupKeysym(&xev.xkey, 0);
                return ev;

            case KeyRelease:
                ev.type = 2;
                ev.key = XLookupKeysym(&xev.xkey, 0);
                return ev;

            case ButtonPress:
                ev.type = 3;
                ev.key = xev.xbutton.button;
                ev.x = xev.xbutton.x / 4;  /* Unscale */
                ev.y = xev.xbutton.y / 4;
                return ev;

            case ClientMessage:
                ev.type = 4;  /* Quit */
                return ev;
        }
    }

    return ev;
}

/*
 * OKNO_ZAMKNIJ - Close X11 window
 */
void ferdek_window_close(void) {
    if (ximage) {
        if (ximage->data) {
            free(ximage->data);
            ximage->data = NULL;
        }
        XDestroyImage(ximage);
        ximage = NULL;
    }

    if (framebuffer) {
        free(framebuffer);
        framebuffer = NULL;
    }

    if (gc) {
        XFreeGC(display, gc);
        gc = 0;
    }

    if (window) {
        XDestroyWindow(display, window);
        window = 0;
    }

    if (display) {
        XCloseDisplay(display);
        display = NULL;
    }

    printf("X11 window closed\n");
}

/*
 * BUFOR_RAMKI_POBIERZ - Get pixel from framebuffer
 */
unsigned char ferdek_framebuffer_get(int x, int y) {
    if (!framebuffer || x < 0 || x >= fb_width || y < 0 || y >= fb_height) {
        return 0;
    }
    return framebuffer[y * fb_width + x];
}

/*
 * EKRAN_CZYSC - Clear screen to color
 */
void ferdek_screen_clear(unsigned char color) {
    if (!framebuffer) return;
    memset(framebuffer, color, fb_width * fb_height);
}
