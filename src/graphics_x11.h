/*
 * graphics_x11.h - X11 Graphics bindings for Ferdek
 */

#ifndef FERDEK_GRAPHICS_X11_H
#define FERDEK_GRAPHICS_X11_H

typedef struct {
    int type;     /* 0=none, 1=keydown, 2=keyup, 3=mouse, 4=quit */
    int key;      /* keycode or mouse button */
    int x, y;     /* mouse position */
} ferdek_event_t;

/* Window management */
int ferdek_window_open(int width, int height, const char* title);
void ferdek_window_close(void);

/* Palette and drawing */
void ferdek_palette_set(const unsigned char* palette);
void ferdek_pixel_draw(int x, int y, unsigned char color);
void ferdek_screen_refresh(void);
void ferdek_screen_clear(unsigned char color);
unsigned char ferdek_framebuffer_get(int x, int y);

/* Event handling */
ferdek_event_t ferdek_event_poll(void);

#endif /* FERDEK_GRAPHICS_X11_H */
